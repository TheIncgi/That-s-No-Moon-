local Proxy = require"MockProxy"
local MockEnv = {}

function MockEnv:new()
    local obj = {
        sandbox = {}, --during test
        proxyList = {}, --to build
        envValues = {}, --holds proxies and values
        globals = {}, --doubles as temp storage
        unbuild = {}
    }
    setmetatable(obj, {__index=self})
    obj:reset()
    
    obj.envValues["type"] = function(x)
        if (obj.globals.type or type)(x)=="table" and getmetatable(x) and getmetatable(x).__type then
            return getmetatable(x).__type
        end
        return (obj.globals.type or type)(x)
    end

    return obj
end

function MockEnv:disableGlobals()
    self.globals = {}
end

function MockEnv:proxy( name, object )
    if not name then error("name expected",2) end
    if not object then error("object expected",2) end
    local proxy = Proxy:new( name, object )
    self.envValues[name] = proxy.proxy
    table.insert(self.proxyList, proxy)
    return proxy
end

function MockEnv:globalProxy( name, object )
    local proxy = self:proxy( name, object )
    self.envValues[name] = proxy.proxy
    return proxy
end

function MockEnv:put( name, object )
    self.envValues[name] = object
end

function MockEnv:reset()
    self.sandbox = {}
    setmetatable(self.sandbox,{
        __index=function(t, k)
            return self.envValues[k] or self.globals[k]
        end,
    })
    return self
end

function MockEnv:apply()
    --TODO allow for setmetatable on sandbox from test
    self.globals = {}
    for a,b in pairs(_G) do
        self.globals[a] = b
    end
    for a in pairs(self.globals) do
        if a~="_G" then
            _G[a] = nil
        end
    end
    if self.globals.getmetatable(_G) then
        self.globals.setmetatable(self.globals, self.globals.getmetatable(_G))
    end
    self.globals.setmetatable(_G, {__index=self.sandbox, __newindex=function(t,k,v) self.sandbox[k]=v end})
end
function MockEnv:unapply()
    setmetatable(_G, getmetatable(self.globals))
    for a,b in self.globals.pairs(self.globals) do
        if a~="_G" then
            _G[a] = b
        end
    end
end

function MockEnv:getProxies()
    return self.proxyList
end

return MockEnv