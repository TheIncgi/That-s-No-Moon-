function generateReport(...)
    local tests = {}
    local results = {
        nPassed = 0,
        nFailed = 0
    }
    for i, test in ipairs(tests) do
        local passed, reason = test:run()
        results.nPassed = results.nPassed + passed and 1 or 0
        results.nFailed = results.nFailed + (not passed) and 1 or 0
        if not passed then
            results[test] = reason
        end
    end
    return results
end