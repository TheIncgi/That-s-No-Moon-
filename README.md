# That's No Moon!
 A lua mock testing library

Checkout `demo.lua` to get started

For a project with a more complex set of unit tests, check out these links  
(Test organizer) https://github.com/TheIncgi/RetroGadgets-GGOS/blob/main/RunAllTests.lua  
(Multiple unit tests) https://github.com/TheIncgi/RetroGadgets-GGOS/blob/main/tests/RasterizerTest.lua


## MockProxy note:
Create using `local myProxy = env:proxy( name, object )`

### Stubbing:

| method         | usage |description |
|----------------|---------|-----------|
| exact          | myProxy{ "hello" }.exact( "world" ) | when `myProxy` is called with the value `"hello"` it will return `"world"` |
| matched        | myProxy{ matchers... }.matched( "world" ) | `matchers` are functions that accept an arg and return true if they match, if all are true then the return values are returned. |
| always         | myProxy().always( "world" )               | if no other stubs match, then this is used as a default set of return values                                     |
| exactCompute   | myProxy( "hello" ).exactCompute( function( str ) return os.clock() end ) | Similar to `exact` but allows you to use a funciton to generate the return values |
| matchedCompute | myProxy( any(), eq("foo") ).matchedCompute( function( a,b ) return os.clock() end ) | Similar to `matched` but allows you to use a function to generate the return values |
| alwaysCompute  | myProxy().alwaysCompute( os.clock ) | Similar to `always`, but allows you to use a function to generate return values |
| exactNever     | myProxy{"goodbye"}.exactNever() | Test fails if the proxy is called with exactly the values provided |
| matchedNever   | myProxy{eq("goodbye"), any()}.matchedNever | Uses `matchers` instead of exact values, test fails if matched |

#### Additional stubbing notes:
You can specify nil matches and varargs like this
```lua
-- stubbing match for 2 args
myProxy{n=2, "foo", nil}                      .exact("bar")

--stubbing for varargs (2+)
myProxy{n=2, varargs=true, eq("foo"), NIL()}   .matched("bar")

--stubbing with a hypothetical matcher function for varargs
myProxy{n=2, varargs=matcher, eq("foo"), NIL}  .matched("bar")
```

You can have a proxy default to it's real implementation using
```lua
myProxy.realDefault = true
```

If you need to pass the proxy value in to something (such as the test code as an arg)
you can access it with
```lua
myProxy.proxy
```

## Test notes:
Adding a test should look something like this
```lua
--somewhere above
local Tester = require"TestRunner"
local Env = require"MockEnv"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local LoaderLibs = {}


local tester = Tester:new()
-----------------------------------------------------------------
-- Tests                                                       --
-----------------------------------------------------------------

-----------------
-- Hello World --  --useful description in an easy to find spot
-----------------
do --limit scope of test stuff
  --given
  local env = Env:new()
  --..required objects & libraries, reset things if needed..
  
  --proxies
  --local printProxy = env:proxy( "print", print) --with `.realDefault = true` will do a real print
  local printProxy = env:proxy( "print", function() end) --dummy function if you want to disable normal functionality

  --stubbing
  printProxy{"Hello world!"}.exact()

  --test code
  local test = tester:add("shouldPrintHelloWorld", env, function()
     print("Hello world!") --more realisticly, some library that calls print
     
     --can return values here to use in tests
  end)

  --checks
  test:var_isTrue(function()
    for i, callArgs in ipairs(printProxy.records.call) do
      --check stuff about callArgs
      --callArgs is a table with args used on each call
      if badThing then
        return "printProxy call #"..i.." of "..#printProxy.records.call.." with arg "..callArgs[1]).." had the bad thing happen"
      end
    end
    return true -- to pass the check
  end, "$1" )
end
```

### More test notes
There's a bunch of different checks you can use.
The ones that do not start with `var_` will look for an exact match
The ones that do start with `var_` can take a `string` `number` or `function` as their first arg
| type | description |
|-|-|
|`string` | looks for a global variable from the sandbox env by name to test |
|`number` | uses the nth return value of test code function |
|`function` | lets you return a value to use in the test |

`$1` refers to the value produced by test code. It will be replaced in any related error messages.

```lua
test:var_eq(function()
    return printProxy.hits
end, 1, "top test pixel called $1 times instead of once")
```

### Test checks
| Checks |
|------------------------------------------|
|test:var_eq( var, expected, errorMsg )            |
|test:var_neq( var, expected, errorMsg )           |
|test:var_gt( var, expected, errorMsg )            |
|test:var_lt( var, expected, errorMsg )            |
|test:var_gte( var, expected, errorMsg )           |
|test:var_lte( var, expected, errorMsg )           |
|test:var_isTrue( var, errorMsg )                  |
|test:var_isFalse( var, errorMsg )                 |
|test:var_isTruthy( var, errorMsg )                |
|test:var_isFalsy( var, errorMsg )                 |
|test:var_isNil( var, errorMsg )                   |
|test:var_hasEntry( var, key, expected, errorMsg ) |
|test:var_hasKey( var, key, errorMsg )             |
| ************************************************ |
|test:eq( actual, expected, errorMsg )             |
|test:neq( actual, expected, errorMsg )            |
|test:gt( actual, expected, errorMsg )             |
|test:lt( actual, expected, errorMsg )             |
|test:gte( actual, expected, errorMsg )            |
|test:lte( actual, expected, errorMsg )            |
|test:isTrue( actual, errorMsg )                   |
|test:isFalse( actual, errorMsg )                  |
|test:isTruthy( actual, errorMsg )                 |
|test:isFalsy( actual, errorMsg )                  |
|test:isNil( actual, errorMsg )                    |
|test:hasEntry( actual, key, expected, errorMsg )  |
|test:hasKey( actual, key, errorMsg )              |
| ************************************************ |
|test:expectError( withMessage )                   |

Additionally you can make custom test checks with this
```lua
test:expect(function() --use upvalues
  local msg = errorMsg or (fVar(actual).." is not falsy")
  return <true to pass, false to fail>, msg
end)
```
The `n`th return value can be retreived with
`test.actionResults[n]` 
