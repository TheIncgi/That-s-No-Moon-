local Test = require"Test"

local TestRunner = {
    static = {}
}

function TestRunner.static.generateReport(...)
    local tests = {...}
    local results = {
        nPassed = 0,
        nFailed = 0
    }
    for i, test in ipairs(tests) do
        local passed, reason = test:run()
        results.nPassed = results.nPassed + (passed and 1 or 0)
        results.nFailed = results.nFailed + ((not passed) and 1 or 0)
        if not passed then
            results[test] = reason
        end
    end
    return results
end

function TestRunner:new()
    local obj = {
        tests = {},
        results = {}
    }
    setmetatable(obj, {__index=self})
    return obj
end

function TestRunner:add( name, env, action )
    local test = Test:new( name, env, action )
    table.insert(self.tests, test)
    return test
end

function TestRunner:run()
    local results = TestRunner.static.generateReport( table.unpack(self.tests) )
    self.results = results
    return results
end

return TestRunner