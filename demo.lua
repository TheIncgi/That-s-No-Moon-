local myLib = {}
function myLib.addOne( x )
  return x+1
end

function myLib.helloWorld()
  _ENV.print"Hello World!"
end

--------

local Tester = require"TestRunner"
local Env = require"MockEnv"

tester = Tester:new()

tester:add("shouldAddOne", Env:new(), function() 
  return myLib.addOne( 100 )
end)
  :eq( 1, 101 ) --1st return value, == 101


do
  local env = Env:new()
  local printProxy = env:proxy("print", print)
  printProxy("Hello World").always()
  tester:add("shouldPrintHelloWorld", env, function()
    myLib.helloWorld()
  end)
end

local results = tester:run()
print("PASSED: ",results.passed)
print("FAILED: ",results.failed)
