local Test = require"Test"

local TestRunner = {
    static = {}
}

function TestRunner.static.generateReport(...)
    local tests = {...}
    local results = {
        passed = 0,
        failed = 0,
        tests = {}
    }
    for i, test in ipairs(tests) do
        local passed, reason = test:run()
        results.passed = results.passed + (passed and 1 or 0)
        results.failed = results.failed + ((not passed) and 1 or 0)
        results.tests[test] = {
            passed = passed, 
            reason = reason
        }
    end
    results.total = results.passed + results.failed
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