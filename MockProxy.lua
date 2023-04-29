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

function Proxy:new( name, target )
    if type(name)~="string" then error("name expected as arg 1",2) end
    if not target then error("target expected as arg 2",2) end
    local obj = {
        target = target,
        records = {
            totalCalls = 0,
            call = {},
            index = {},
            assign = {}
        },
        debugName = name,
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
        __call=function(t,...)
            return obj:_createMockCall({...})
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
            table.insert(obj.records.call, {...})
            return obj:_match({...})
        end,
        __pairs=function(t)
            return function(t,k) 
                local nextKey = next(t,k)
                if not nextKey then return end
                local nextVal = obj.proxy[nextKey]
                return nextKey, nextVal
            end, obj.target, nil 
        end,
        __ipairs=function(t)
            return function(t,k)
                k = (k==nil) and 1 or (k+1)
                if not obj.target[k] then return end
                local v = obj.proxy[k]
                return k,v
            end, obj.target, nil
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
            self.mockCall.always = {
                type = "always",
                returns = returns,
                hits = 0,
                id = id
            }
            return self.mockCall.always
        end,
        exactCompute = function(computeFunc)
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

function Proxy:_match(args)
    local nArgs = #args
    local f
    for i, option in ipairs(self.mockCall) do
        local N = (option.exact or option.pattern).n or #(option.exact or option.pattern)
        local isVarargs = (option.exact or option.pattern).varargs
        local matches = true
        
        if nArgs == N or 
            (isVarargs and nArgs > N) then
            for j = 1, nArgs do
                matcher = ( option.pattern or option.exact )[j]
                if option.exact then
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
        if self.mockCall.always then
            f = self.mockCall.always
        end
    end

    self.records.totalCalls = self.records.totalCalls + 1
    if f then
        f.hits = f.hits + 1
    else
        if self.realDefault then
            return self.target(table.unpack(args)) --real function
        else
            local argsStr = {}
            for _,arg in ipairs(args) do
                table.insert(argsStr, fVar(arg))
            end
            argsStr = table.concat(argsStr)
            error("Missing stubbing for call to `"..self.debugName.."` with args ["..argsStr.."]. Add stubbing or use `.realDefault=true`", 3)
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
    local usageReport = {"Proxy<",self.debugName,">:\n"}
    local all = true
    for i, mock in ipairs(self.mockCall) do
        if mock.hits == 0 then
            all = false
        end
        table.insert(usageReport, ("\tid: %2d | hits: %5d | type: %s\n"):format(
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