local Proxy = {
    static = {}
}

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
    local obj = {
        target = target,
        records = {
            call = {},
            index = {},
            assign = {}
        },
        mockCall = {},
        mockIndex = {},
        built = false
    }
    setmetatable(obj, {
        __index=function(t, k)
            if obj.built then
                obj.records.index[k] = (obj.records.index[k] or 0) + 1
                return target[k]
            end
            return obj[k]
        end,
        __newindex=function(t,k,v)
            if obj.built then
                obj.target[k] = obj.target[v]
                obj.records.assign[k] = obj.records.assign[k] or {}
                table.insert(obj.records.assign[k], v)
                return
            end
            if obj.mockIndex[k] then error("overwrite of mocked index value", 2) end
            obj.mockIndex[k] = v
        end,
        __call=function(t,f,...)
            if obj.built then 
                obj.records.call[f] = obj.records.call[f] or {}
                table.insert(obj.records.call[f], {...})
                --TODO get mock return
                return
            end
            return obj:_createMockCall(f)
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
function Proxy:_createMockCall(name,pattern)
    local r = {
        exact = function(...)
            local returns = {...}
            table.insert(self.mockCall[name], {
                exact = pattern,
                returns = returns,
                hits = 0
            })
        end,
        matched = function(...)
            local returns = {...}
            table.insert(self.mockCall[name], {
                pattern = pattern,
                returns = returns,
                hits = 0
            })
        end,
        always = function(...)
            local returns = {...}
            self.mockCall[name].always = {
                returns = returns,
                hits = 0
            }
        end,
        exactCompute = function(computeFunc)
            table.insert(self.mockCall[name], {
                exact = pattern,
                compute = computeFunc,
                hits = 0
            })
        end,
        matchedCompute = function(computeFunc)
            table.insert(self.mockCall[name], {
                pattern = pattern,
                compute = computeFunc,
                hits = 0
            })
        end,
        alwaysCompute = function(computeFunc)
            self.mockCall[name].always = {
                compute = computeFunc,
                hits = 0
            }
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

    f.hits = f.hits + 1
    
    if not f then
        return self.target(table.unpack(args)) --real function
    end
    if f.returns then
        return table.unpack(f.returns)
    end
    if f.compute then
        return f.compute(table.unpack(args))
    end
    error("missing case")
end

function Proxy:build()
    self.built = true
end

return Proxy