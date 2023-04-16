local Proxy = require"MockProxy"
local MockEnv = {}

if not setfenv then
    function setfenv(fn, env)
    local i = 1
    while true do
      local name = debug.getupvalue(fn, i)
      if name == "_ENV" then
        debug.upvaluejoin(fn, i, (function()
          return env
        end), 1)
        break
      elseif not name then
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
    }
    setmetatable(obj, {__index=self})
    obj:reset()

    return obj
end

function MockEnv:disableGlobals()
    self.globals = {}
end

function MockEnv:proxy( name, object )
    self.envValues[name] = Proxy:new( object )
    table.insert(self.proxyList, self.env[name])
    return self
end

function MockEnv:put( name, object )
    self.envValues[name] = object
    return self
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
    for i,p in ipairs(self.proxyList) do
        p:build()
    end
    setfenv( func, self.sandbox )
end

return MockEnv