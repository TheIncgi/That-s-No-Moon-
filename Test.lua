local MockEnv = require"MockEnv"
local Test = {}


function Test:new( name, env, action )
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
    local results = {pcall(self.action)}
    local ok = results[1]
    self.actionResults = {table.unpack(results,2)}
    if ok and self.expects.error then
        self.passed = false
        self.reason = "Expected error, but none thrown"
        return
    end
    if not ok and not self.expects.error then
        self.passed = false
        self.reason = "No errro was expected, but one was thrown. Error: "..tostring(results[2])
        return
    end
    if not ok and self.expects.error then
        if self.expects.errorMessage == nil or
           self.expects.errorMessage == results[2] then
            self.passed = true
            self.reason = false
            return
        end
        self.passed = false
        self.reason = 'Expected error with message "'..tostring(self.expects.errorMessage)..'", got a different error: '..tostring(results[2])
    end

    for i, check in ipairs( self.expects ) do
        local passed, reason = check()
        if not passed then
            self.passed = false
            self.reason = reason
            return
        end
    end
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
    table.insert( self.expects, {
        expression = expression
    } )
    return self
end
function Test:eq( var, expected )
    return self:expect(function()
        local v, msg = self:_eval(var, "expected "..fVar(expected)..", got $1")
        return v == expected, msg
    end)
end

function Test:neq( var, expected )
    return self:expect(function()
        local v, msg = self:_eval(var, "unexpected "..fVar(expected)..", got $1")
        return v ~= expected, msg
    end)
end
function Test:gt( var, expected )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 > "..fVar(expected).." is not true")
        return v > expected, msg
    end)
end
function Test:lt( var, expected )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 < "..fVar(expected).." is not true")
        return v < expected, msg
    end)
end
function Test:gte( var, expected )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 >= "..fVar(expected).." is not true")
        return v >= expected, msg
    end)
end
function Test:lte( var, expected )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 <= "..fVar(expected).." is not true")
        return v <= expected, msg
    end)
end
function Test:isTrue( var )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 is not true")
        return v == true, msg
    end)
end
function Test:isFalse( var )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 is not false")
        return v == false, msg
    end)
end
function Test:isTruthy( var )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 is not truthy")
        return not not v, msg
    end)
end
function Test:isFalsy( var )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 is not falsy")
        return not v, msg
    end)
end
function Test:isNil( var )
    return self:expect(function()
        local v, msg = self:_eval(var, "$1 > is not nil")
        return v == nil, msg
    end)
end

