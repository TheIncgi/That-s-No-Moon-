local Proxy = {
    static = {}
}

local function fVar( v )
    if type(v)=="string" then
        return '"'..v..'"'
    end
    return tostring(v)
end


function Proxy.static.inRange(low, high)
    return function(x)
        return type(x)=="number" and low <= x and x <= high
    end
end

function Proxy.static.containsKey(key)
    return function(x)
        if type(x)~="table" then return false end
        for k,v in pairs(x) do
            if k==key then
                return true
            end
        end
        return false
    end
end

function Proxy.static.any()
    return function() return true end
end

function Proxy.static.eq(x)
    return function(y) return x==y end
end

function Proxy.static.neq(x)
    return function(y) return x==y end
end

function Proxy.static.NOT( matcher )
    return function(...) return not matcher(...) end
end

function Proxy.static.containsValue(value)
    return function(x)
        if type(x)~="table" then return false end
        for k,v in pairs(x) do
            if v==value then
                return true
            end
        end
        return false
    end
end

local VARARGS_PATTERN = function() end
function Proxy.static.varargs()
    return VARARGS_PATTERN
end

function Proxy:new( target )
    if not target then error("target expected",2) end
    local obj = {
        target = target,
        records = {
            call = {},
            index = {},
            assign = {}
        },
        realDefault = false, --if false, calling throws an error about missing stubbing, only used on calls
        mockCall = {},
        mockIndex = {},
        _nextMockID = 1
    }

    obj.proxy = {}

    setmetatable(obj, {
        __index=function(t, k)
            return rawget(obj,k) or Proxy[k]
        end,
        __newindex=function(t,k,v)
            if obj.mockIndex[k] then error("overwrite of mocked index value", 2) end
            obj.mockIndex[k] = v
        end,
        __call=function(t,f,...)
            return obj:_createMockCall(f)
        end
    })
    setmetatable(obj.proxy, {
        __index=function(t, k)
            obj.records.index[k] = (obj.records.index[k] or 0) + 1
            return obj.target[k] or obj.mockIndex[k]
        end,
        __newindex=function(t,k,v)
            obj.target[k] = obj.target[v]
            obj.records.assign[k] = obj.records.assign[k] or {}
            table.insert(obj.records.assign[k], v)
            return            
        end,
        __call=function(t,...)
            obj.records.call[f] = obj.records.call[f] or {}
            table.insert(obj.records.call[f], {...})
            return self:_match( f, {...})
        end,
        __type=type(target)
    })
    return obj
end

--myProxy()                                     .always("bar")
--myProxy{"foo"}                                .exact("bar")
--myProxy{eq("foo")}                            .matched("bar")
--myProxy{n=2, "foo", nil}                      .exact("bar")
--myProxy{n=2, varargs=true eq("foo"), NIL()}   .matched("bar")
--myProxy{n=2, varargs=matcher eq("foo"), NIL}  .matched("bar")
function Proxy:_createMockCall(pattern)
    local id = self._nextMockID
    self._nextMockID = self._nextMockID + 1
    local r = {
        exact = function(...)
            local returns = {...}
            self.mockCall = self.mockCall or {}
            local mock = {
                type = "exact",
                exact = pattern,
                returns = returns,
                hits = 0,
                id = id
            }
            table.insert(self.mockCall, mock)
            return mock
        end,
        matched = function(...)
            local returns = {...}
            self.mockCall = self.mockCall or {}
            local mock = {
                type = "matched",
                pattern = pattern,
                returns = returns,
                hits = 0,
                id = id
            }
            table.insert(self.mockCall, mock)
            return mock
        end,
        always = function(...)
            local returns = {...}
            self.mockCall = self.mockCall or {}
            self.mockCall.always = {
                type = "always",
                returns = returns,
                hits = 0,
                id = id
            }
            return self.mockCall.always
        end,
        exactCompute = function(computeFunc)
            self.mockCall = self.mockCall or {}
            local mock = {
                type = "exactCompute",
                exact = pattern,
                compute = computeFunc,
                hits = 0,
                id = id
            }
            table.insert(self.mockCall, mock)
            return mock
        end,
        matchedCompute = function(computeFunc)
            self.mockCall = self.mockCall or {}
            local mock = {
                type = "matchedCompute",
                pattern = pattern,
                compute = computeFunc,
                hits = 0,
                id = id
            }
            table.insert(self.mockCall, mock)
            return mock
        end,
        alwaysCompute = function(computeFunc)
            self.mockCall = self.mockCall or {}
            self.mockCall.always = {
                type = "alwaysCompute",
                compute = computeFunc,
                hits = 0,
                id = id
            }
            return self.mockCall.always
        end
    }
    r.default = r.always
    r.defaultCompute = r.alwaysCompute
    return r
end

function Proxy:_match(name, args)
    local nArgs = #args
    local f
    for i, option in ipairs(self.mockCall[name]) do
        local N = (option.pattern or option.exact).n
        local isVarargs = (option.pattern.varargs or option.exact.varargs)
        local matches = true
        local isExact = not not option.exact
        if nArgs == N or 
            (isVarargs and nArgs > N) then
            for j,matcher in ipairs( option.pattern or option.exact ) do
                if isExact then
                    if matcher ~= args[j] then
                        matches = false
                        break
                    end
                else
                    if not matcher( args[j]) then
                        matches = false
                        break
                    end
                end
            end
            if matches then
                if type(isVarargs) == "function" then
                    if not isVarargs(table.unpack(args, N+1)) then
                        matches = false
                    end
                elseif isVarargs == false and nArgs > N then
                    matches = false
                end
            end
        else
            matches = false --not enough args
        end
        if matches then
            f = option
            break
        end
    end

    if not f then --default/always backup
        if self.mockCall[name].always then
            f = self.mockCall[name]
        end
    end

    f.hits = f.hits + 1
    
    if not f then
        if self.realDefault then
            return self.target(table.unpack(args)) --real function
        else
            local argsStr = {}
            for _,arg in ipairs(args) do
                table.insert(argsStr, fVar(arg))
            end
            argsStr = table.concat(argsStr)
            error("Missing stubbing for call to `"..name.."` with args ["..argsStr.."]. Add stubbing or use `realDefault=true`", 3)
        end
    end
    if f.returns then
        return table.unpack(f.returns)
    end
    if f.compute then
        return f.compute(table.unpack(args))
    end
    error("missing case")
end

--return true if all mock call results have atleast 1 hit
function Proxy:allHit()
    local usageReport = {"Proxy<",tostring(self.target),">:\n"}
    local all = true
    for i, mock in ipairs(self.mockCall) do
        if mock.hits == 0 then
            all = false
        end
        table.insert(usageReport, ("\tid: %2d | hits: %5d | type: %s"):format(
            mock.id, mock.hits, mock.type
        ))
    end
    if self.mockCall.always then
        local mock = self.mockCall.always
        if mock.hits == 0 then
            all = false
        end
        table.insert(usageReport, ("\tid: %2d | hits: %5d | type: %s"):format(
            mock.id, mock.hits, mock.type
        ))
    end
    return all, table.concat(usageReport)
end

return Proxy