local MockEnv = require"MockEnv"
local Test = {}


function Test:new( name, env, action )
    if type(action)~="function" then
        error("arg 3 must be function",2)
    end
    local obj = {}
    setmetatable(obj,{__index=self})

    obj.name = name
    obj.env = env or MockEnv:new()
    obj.action = action
    obj.actionResults = {}
    obj.expects = {}

    obj.passed = false
    obj.reason = false

    return obj
end

function Test:run()
    self.env:apply()
    local results = {pcall(self.action)}
    self.env:unapply()
    local ok = results[1]
    self.actionResults = {table.unpack(results,2)}
    if ok and self.expects.error then
        self.passed = false
        self.reason = "Expected error, but none thrown"
        return self.passed, self.reason
    end
    if not ok and not self.expects.error then
        self.passed = false
        self.reason = "No error was expected, but one was thrown. Error: "..tostring(results[2])
        return self.passed, self.reason
    end
    if not ok and self.expects.error then
        if self.expects.errorMessage == nil or
           self.expects.errorMessage == results[2] then
            self.passed = true
            self.reason = false
            return self.passed, self.reason
        end
        self.passed = false
        self.reason = 'Expected error with message "'..tostring(self.expects.errorMessage)..'", got a different error: '..tostring(results[2])
    end

    for i, check in ipairs( self.expects ) do
        local passed, reason = check()
        if not passed then
            self.passed = false
            self.reason = reason
            return self.passed, self.reason
        end
    end

    for i, proxy in ipairs(self.env:getProxies()) do
        local allHit, usage = proxy:allHit()
        if not allHit then
            self.passed = false
            self.reason = ("All expectations met, but you have one or more stubbing issues on your proxy of `%s`. Here are the stubs and usage:\n\t%s")
                :format(
                    proxy.debugName,
                    usage
                )
            return self.passed, self.reason --failed
        end
    end

    self.passed = true
    self.reason = false
    return self.passed, self.reason
end

function Test:expectError(withMessage)
    self.expects.error = true
    self.expects.errorMessage = withMessage
    return self
end

local function fVar( v )
    if type(v)=="string" then
        return '"'..v..'"'
    end
    return tostring(v)
end

function Test:_eval (var, errorMsg)
    if type(var)=="string" then
        return self.env.sandbox[var], errorMsg:gsub("$1", fVar(self.env.sandbox[var]))
    elseif type(var)=="number" then --return value of action
        return self.actionResults[var], errorMsg:gsub("$1", fVar(self.actionResults[var]))
    end
    return var(), errorMsg:gsub("$1", fVar(var()))
end
function Test:expect( expression )
    table.insert( self.expects, expression)
    return self
end

function Test:var_eq( var, expected, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("expected "..fVar(expected)..", got $1"))
        return v == expected, msg
    end)
end
function Test:var_neq( var, expected, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("unexpected "..fVar(expected)..", got $1"))
        return v ~= expected, msg
    end)
end
function Test:var_gt( var, expected, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 > "..fVar(expected).." is not true"))
        return v > expected, msg
    end)
end
function Test:var_lt( var, expected, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 < "..fVar(expected).." is not true"))
        return v < expected, msg
    end)
end
function Test:var_gte( var, expected, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 >= "..fVar(expected).." is not true"))
        return v >= expected, msg
    end)
end
function Test:var_lte( var, expected, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 <= "..fVar(expected).." is not true"))
        return v <= expected, msg
    end)
end
function Test:var_isTrue( var, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 is not true"))
        return v == true, msg
    end)
end
function Test:var_isFalse( var, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 is not false"))
        return v == false, msg
    end)
end
function Test:var_isTruthy( var, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 is not truthy"))
        return not not v, msg
    end)
end
function Test:var_isFalsy( var, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 is not falsy"))
        return not v, msg
    end)
end
function Test:var_isNil( var, errorMsg )
    return self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 is not nil"))
        return v == nil, msg
    end)
end
function Test:var_hasEntry( var, key, expected, errorMsg )
    self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 is not a table with entry ["..fVar(key).."] and expected value "..fVar(expected)))
        return type(v)=="table" and v[key] == expected, msg
    end)
end
function Test:var_hasKey( var, key, errorMsg )
    self:expect(function()
        local v, msg = self:_eval(var, errorMsg or ("$1 > is not a table with entry ["..fVar(key).."]"))
        return type(v)=="table" and v[key] == expected, msg
    end)
end


function Test:eq( actual, expected, errorMsg )
    return self:expect(function()
        local msg = errorMsg or ("expected "..fVar(expected)..", got "..fVar(actual))
        return actual == expected, msg
    end)
end
function Test:neq( actual, expected, errorMsg )
    return self:expect(function()
        local msg = errorMsg or ("unexpected "..fVar(expected)..", got "..fVar(actual))
        return actual ~= expected, msg
    end)
end
function Test:gt( actual, expected, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." > "..fVar(expected).." is not true")
        return actual > expected, msg
    end)
end
function Test:lt( actual, expected, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." < "..fVar(expected).." is not true")
        return actual < expected, msg
    end)
end
function Test:gte( actual, expected, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." >= "..fVar(expected).." is not true")
        return actual >= expected, msg
    end)
end
function Test:lte( actual, expected, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." <= "..fVar(expected).." is not true")
        return actual <= expected, msg
    end)
end
function Test:isTrue( actual, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." is not true")
        return actual == true, msg
    end)
end
function Test:isFalse( actual, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." is not false")
        return v == false, msg
    end)
end
function Test:isTruthy( actual, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." is not truthy")
        return not not actual, msg
    end)
end
function Test:isFalsy( actual, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." is not falsy")
        return not actual, msg
    end)
end
function Test:isNil( actual, errorMsg )
    return self:expect(function()
        local msg = errorMsg or (fVar(actual).." is not nil")
        return actual == nil, msg
    end)
end
function Test:hasEntry( actual, key, expected, errorMsg )
    self:expect(function()
        local msg = errorMsg or (fVar(actual).." is not a table with entry ["..fVar(key).."] and expected value "..fVar(expected))
        return type(actual)=="table" and actual[key] == expected, msg
    end)
end
function Test:hasKey( actual, key, errorMsg )
    self:expect(function()
        local msg = errorMsg or (fVar(actual).." > is not a table with entry ["..fVar(key).."]")
        return type(actual)=="table" and actual[key] == expected, msg
    end)
end

return Test
