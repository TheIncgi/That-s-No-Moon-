local myLib = {}
function myLib.addOne( x )
  return x+1
end

function myLib.helloWorld()
  print"Hello World!"
end

function myLib.printAll( tbl )
  for a,b in pairs(tbl) do
    print(a, b)
  end
end

--------

local Tester = require"TestRunner"
local Env = require"MockEnv"
local Proxy = require"MockProxy"

tester = Tester:new()

do --test 1, expected: PASS
  tester:add("shouldAddOne", Env:new(), function() 
    return myLib.addOne( 100 )
  end)
    :var_eq( 1, 101 ) --1st return value, == 101
end

do --test 2, expected: PASS
  local env = Env:new()
  local printProxy = env:proxy("print", print)
  printProxy("Hello World!").exact()
  tester:add("shouldPrintHelloWorld", env, function()
    myLib.helloWorld()
  end)
end

do --test 3, expected: FAIL, un-used stubbing
  local env = Env:new()
  local printProxy = env:proxy("print", print)
  printProxy("Hello World!").exact()
  printProxy().always()
  tester:add("shouldPrintHelloWorld", env, function()
    myLib.helloWorld()
  end)
end

do --test 4, expected: FAIL, uses pairs instead of ipairs
  local foo = {x="do not look!", "a","b","c'"}
  local env = Env:new()
  local fooProxy = Proxy:new("foo",foo)  
  tester:add("shouldNotLook", nil, function()
    myLib.printAll( fooProxy.proxy )
  end)
    :eq(fooProxy.records.index.x or 0, 0)
end

local results = tester:run()
print("====== Results ======")
print("TOTAL:  ",results.total )
print("PASSED: ",results.passed)
print("FAILED: ",results.failed)
print("====== Details ======")
local wid = 1
for test in pairs(results.tests) do 
  wid = math.max(wid, #test.name)
end
for test, detail in pairs(results.tests) do
  print(("%-"..wid.."s | %s | %s"):format(test.name, detail.passed and "PASS" or "FAIL", detail.reason or ""))
end
