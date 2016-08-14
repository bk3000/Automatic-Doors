--contact bk3k for any requested expansions or to report problems
--free to use reproduce/distribute/modify/etc, but rename to avoid conflict please
--yes that includes commercial use such as by Chuckelfish, in which case I'd appreciate a shout out

--presently far from finished!  Mistakes certainly abound.

local stateTables = {}
local logTable = {}
local highestTableIndex = 0  --we won't be storing anything on [0], but that will tell us the last index with data
local currentTable = 1
local tableNames = {}    --will store the indexNames and numbers
local doSanitize = false  -- just change to false if you want faster performance
                          -- at the expense of potentially passing bad arguments

local codeBlocks = {keyNameExists = {} }
local clientContext = {}
local clientTable = {}
--the purpose of these tables is to have a conventient place to store what will be sent from client to package, 
--avoiding accidentally sending the content as the data itself(poluting the data you need to parse)
--and you won't easily confuse it for something else as the intent should be obvious


--start function declarations without definitions
local flush         --not implimented yet
local newTable      --not implimented yet
local append        --not implimented yet
local isTableEmpty  --maybe not needed, may remove
local setMode       --not implimented yet
local updateMode    --not implimented yet

local sanitizeArgumentType  --partially done
local sanitizeArgumentRange --not implimented yet
local spacer                --done
local whatIs                --done
local tableDump             --done
local dump                  --done
local keyNameExists1        --???
local keyNameExists2        --done
local keyNameExists         --codeBlock will be chosen
local keyReturn             --probably done
local elementsToString      --done
local updateMode            --???
--end function declarations

elementsToString = function(whatTable)
  local toReturn = ""
  for k, v in pairs(whatTable) do
    local t = type(v)
    if (t == "table") then
      toReturn = toReturn .. elementsToString(whatTable[k])
    elseif (t == "string") then
      toReturn = toReturn .. v
    elseif (t == "number") or (t == "boolean") then
      toReturn = toReturn .. tostring(v)
    end
  end
  return toReturn  
end


updateMode = function()
  --assume variable has changed, and redefine certain functions accordingly
    --for now that means 'doSanitize'
  if doSanitize then 
    keyNameExists = codeBlocks.keyNameExists[1]
  else
    keyNameExists = codeBlocks.keyNameExists[2]
  end
    
end


setMode = function(args)
  --stuff here
  --then call
  updateMode()
end


flush = function(whatTable)
  
end


newTable = function(tableName)
  --if no tableName, use index instead!
    
end


append = function(whatTable)
 
end


sanitizeArgumentType = function(...) 
  --probably an expensive function, but versitile where argument integrity is important
  --any amount of arguments are valid, but should come in triples of argumentPassed, expectedtypes(table), default if unclean
  --will return a table of tables for each argument in the order of which they where recieved
    --parent funtion will need to unpack
    --returnTables[...][1] represents the new value of the argument.
    --returnTables[...][2] is a boolean value indicating if the value was initially invalid, for error handling purposes
  local argT = 1 -- will serve to count the "argTable" tables made
  local argI = 1
  local argTable = {} --each will contain 3 indexes
  for _, v in pairs({...}) do
    if (argI == 1) then
      argTable[argT] = { v }
      argI = 2
    elseif (argI == 2) then
      argTable[argT][2] = v
      argI = 3
    else 
      argTable[argT][3] = v
      argI = 1
    end
  end
  --thus ... has been split in to 3 element tables contained within argTable
  
  
end


sanitizeArgumentRange = function(...)
  --much like sanitizeArgumentType, but specify the range of acceptable arguments instead of type
end


spacer = function(nestingLevel)
  --base level would be nesting level 0
  --relative to the table sent to logger
  local s = 0
  local toReturn = ""
  while (s < nestingLevel) do
    toReturn = toReturn .. "  "
    s = s + 1
  end
  return toReturn
end


whatIs = function(k, v, i) -- was whatIs = function(whatTable, k, v, i)
         --(key, value, index)
  local t = type(v)  --was local t = type(whatTable[k])
    --evalutates value not key
    
  if (t == "table") then
    return tableDump(v , tostring(k), i)  -- was (whatTable[k], i + 1, tostring(k)
  elseif (t == "string") then
    return tostring(k) .. " : \"" .. v .. "\""
  elseif (t == "number") or (t == "boolean") then
    return tostring(k) .. " : " .. tostring(v)
  elseif (t == "nil") then
    return tostring(k) .. " : nil"
  elseif (t == "function") then
    return tostring(k) .. "()"
  else 
    return ""
    --I am not at the current time interested in dealing with "userdata" or "thread" 
    --and don't imagine they'd get passed to this anyhow
  end
end


tableDump = function(whatTable, tableName, i)
  local toReturn = tableName .. " : {\n"
  --table.sort(whatTable)
  i = i + 1
  for k, v in pairs(whatTable) do
    toReturn = toReturn .. spacer(i) .. whatIs(k, v, i) .. "\n"
  end
    
  toReturn = toReturn .. spacer(i - 1) .. "}"
  return toReturn
end


dump = function(whatTables, context)
  --this function expects to recieve a table exclusively full of other tables.
  --reason 1 is to allow the dump of multiple tables with a single function call
  --reason 2 is to easily extract the names of the tables
  --if you only have 1 table to send, then call the function like this
    --dump( {onlyTable}, "totally optional context" ) 
  local logOut = ""
  
  context = context or {"no context given"}
  if not (type(context) == "table") then
    context = { context }
    end
  local fContext = elementsToString(context)
  
  
  for k, v in pairs(whatTables) do
    if (type(v) == "table") then 
      logOut = logOut .. "\n" .. fContext .. "\n" .. spacer(1) .. "Beginning dump : {\n" .. spacer(2) .. tableDump(v, tostring(k), 2) .. "\n  }\n  Ending dump of table : " .. k .. "\nfrom " .. fContext .. "\n"
    else
      logOut = "\ndump() recieved " .. type(v) .. " as an argument!\n"
    end
  end  
  sb.logInfo(logOut)
end


isTableEmpty = function(whatTable)
  --not sure I need this
  for _ in pairs(whatTable) do 
    return false
  end
  return true
end


codeBlocks.keyNameExists[1] = function(whatTable, keyTable)
  --keyTable obviously expects a table containing either strings or numbers representing keys you hope to find.
  --If you only have loose keys to check for, call function like this
    --keyNameExists(myTable, { "someString" } )
    --keyNameExists(myTable, { 3.14 } )
    --keyNameExists(myTable), { someVariable } )
    --keyNameExists(myTable), { someVariable, "someString", 3.14, "etc" }
  --you could compare a single result against a list like this
    --keyNameExists( { tostring(someTable[i]) } , tableOfKeys)
  local t1 = type(whatTable)
  local t2 = type(keyTable)

  if not (t1 == "table") then 
    if (t1 == "nil") then 
      return false
    end
    whatTable = table.pack(whatTable)
  end

  if not (t2 == "table") then 
    keyTable = table.pack(keyTable)
  end
  
  for _, v in pairs(keyTable) do
    for key, _ in pairs(whatTable) do
      if ( key == v ) then
         return true
      end
    end
  end

  return false
end


codeBlocks.keyNameExists[2] = function(whatTable, keyTable)
  --raw version of function accessed only by functions I know will pass correct data
  --regular version sanitizes data(possibly erroring/aborting) then passes to raw
  --raw versions perform slightly better for when we have that luxury
    
  for _, v in pairs(keyTable) do
    for key, _ in pairs(whatTable) do
      if ( key == v ) then
         return true
      end
    end
  end

  return false
end  


keyReturn = function(whatTable, doSort, ignoreKeys)
  --I may use this elsewhere if not here
  --returns a table containing the keynames of all keys for a table
  --the returned table will be all numberic keys paired with values thus very easy to parse for other functions
  local toReturn = {}
  local i = i
  doSort = doSort or false  --doSort is optional.  If not used, will not sort table before return
  if ignoreKeys then 
    for k, v in pairs(whatTable) do
      if not (keyNameExists( { k }, ignoreKeys)) then
        toReturn[i] = k
        i = i + 1
      end
    end
  else
    for k, v in pairs(whatTable) do
      toReturn[i] = k
      i = i + 1
    end
  end
  
  if doSort then
    return table.sort(toReturn)
  else 
    return toReturn
  end
end
  

bk3kLogger = {
  flush = flush,
  newTable = newTable,
  append = append,
  setMode = setMode,
  dump = dump,
  sAT = sanitizeArgumentType,
  sAR = sanitizeArgumentRange,
  doSanitize = doSanitize,
  context = clientContext,
  dumpTable = clientTable
  }

return bk3kLogger
