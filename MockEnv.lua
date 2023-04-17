local Proxy = require"MockProxy"
local MockEnv = {}

if not setfenv then
    function setfenv(fn, env)
        local i = 1
        while true do
          local name, value = debug.getupvalue(fn, i)
          if not name then
            break
          elseif name == "_ENV" then
            debug.upvaluejoin(fn, i, (function()
              return env
            end), 1)
            break
          end
          i = i + 1
        end
        return fn
    end
    
end

function MockEnv:new()
    local obj = {
        sandbox = {}, --during test
        proxyList = {}, --to build
        envValues = {}, --holds proxies and values
        globals = _G,
        unbuild = {}
    }
    setmetatable(obj, {__index=self})
    obj:reset()
    
    obj.envValues["type"] = function(x)
        if type(x)=="table" and getmetatable(x) and getmetatable(x).__type then
            return getmetatable(x).__type
        end
        return type(x)
    end

    return obj
end

function MockEnv:disableGlobals()
    self.globals = {}
end

function MockEnv:proxy( name, object )
    if not name then error("name expected",2) end
    if not object then error("object expected",2) end
    local proxy = Proxy:new( object )
    self.envValues[name] = proxy.proxy
    table.insert(self.proxyList, proxy)
    return proxy
end

function MockEnv:put( name, object )
    self.envValues[name] = object
end

function MockEnv:reset()
    self.sandbox = {}
    setmetatable(self.sandbox,{
        __index=function(t, k)
            return self.sandbox[k] or self.env[k] or self.globals[k]
        end,
    })
    return self
end

function MockEnv:apply( func )
    setfenv( func, self.sandbox )
end

function MockEnv:getProxies()
    return self.proxyList
end

return MockEnv