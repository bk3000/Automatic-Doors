-- automatic doors 3.3(tentative)
-- basic code by Chucklefish, additional code by lornlynx (with some help from Healthire), greatly reworked and updated by bk3k
-- the additional code is documentated

require("/scripts/bk3k/bk3k-cMath2d.lua")

function init()
  message.setHandler("openDoor", function() openDoor() end)
  message.setHandler("lockDoor", function() lockDoor() end)
  message.setHandler("closeDoor", function() closeDoor() end)
  
  self.doDebug = false --change to false for release versions!  Or you'll have HUGE logs!
  storage.id = entity.id()
  storage.doorPosition = object.position()
  
  initPackages()
  
  L.dump(L.dumpTable, L.context)
  storage.spaces = storage.spaces or object.spaces()
  storage.realSpaces = storage.realSpaces or setRealSpaces()
  storage.center = storage.center or findCenter()
    
  
 --boolean values
  storage.postInit = false
  storage.defaultLocked = storage.defaultLocked or config.getParameter("defaultlocked", false)
  storage.locked = storage.locked or ( storage.defaultLocked or config.getParameter("locked", false) )
  storage.defaultInteractive = storage.defaultInteractive or config.getParameter("interactive", true)
  storage.wireOpened = storage.wireOpened or false 
  storage.wireControlled = storage.wireControlled or object.isInputNodeConnected(0)
  storage.noClearOpen = storage.noClearOpen or object.isOutputNodeConnected(0)
  storage.state = storage.state or ((config.getParameter("defaultState", "closed") == "open") and not storage.locked)
  storage.isHorizontal = storage.isHorizontal or isDoorHorizontal()
  storage.largeDoor = storage.largeDoor or config.getParameter("largeDoor" , false)
  storage.playerOpened = storage.playerOpened or false
  storage.playerClosed = storage.playerClosed or false
  storage.liquidAware = storage.liquidAware or config.getParameter("liquidAware" , false)
  storage.lightAware = storage.lightAware or config.getParameter("lightAware" , false)  
  --once implimented, check very infrequently
  storage.doorException = storage.doorException or doorException()  --check if door is part of exception list 
  storage.noAuto = storage.noAuto or noAutomatic()
  storage.noNPCuse = storage.noNPCuse or config.getParameter("noNPCuse", false)
    --this is for doors that NPCs must never be allowed to open, special case use such as not really a "door"
  self.Interacted = false --may pull this value
  self.npcClosed = false
    
  
  --numeric values
  storage.maxInputNode = ( #(config.getParameter("inputNodes", {})) - 1 )
    --standard LUA tables start at 1 instead of 0.  Starbound assignes the first node to 0 despite this.
  self.closeCooldown = 0
  self.openCooldown = 0
  storage.queryRadius = config.getParameter("queryOpenRadius", 5) --I don't like the door opening directly in my face
  
  
  --string values
  storage.objectName = config.getParameter("objectName", "door")
  storage.openingAnimation_stateName = config.getParameter("openingAnimation", "open")  
  --if doors have an opening animation cycle and frames seperate from the "open" state
    --my doors use "opening"
  storage.lockedAnimation_stateName = config.getParameter("lockedAnimation", "closed")
  --if they have an actual locked animation and frames, use instead of "closed" when locked
    --my doors use "locked"
  storage.boundVar = config.getParameter("detectBoundMode", "CollisionArea")
    
  
  --table values
  storage.liquidActions = config.getParameter("liquidActions", {default = "ignore"}) 
    --tells us how to react to the presence of various liquids.  If liquid not listed, use default.
    -- will not have any meaning unless storage.liquidAware is true
  
  
  setDirection(storage.doorDirection or object.direction())
  initializeMaterialSpaces()
  --called only in init(), will call updateMaterialSpaces() after completion
  
  if storage.state and not (storage.locked or storage.wireControlled or storage.wireOpened) then
    realOpenDoor(storage.doorDirection)
  elseif storage.locked then
    lockDoor()
  else
    onInputMultiNodeChange()
  end
  
  updateInteractive()
  setIncludedTypes()
  if storage.largeDoor then
    setLargeQuerry()
  else
    setQuery()
  end
  
  if storage.liquidAware or storage.lightAware then 
    setContactQuery()
  end
  
  
  L.context[1] = "End of "  
  L.dump(L.dumpTable, L.context)  
  storage.postInit = true
end
  

function setIncludedTypes()
  storage.scanTargets = storage.scanTargets or config.getParameter("scanTargets", {"player", "vehicle"})
  if not (#storage.scanTargets > 0) or not (type(storage.scanTargets) == "table") then
    storage.scatTargets = {"player", "vehicle"}
  end
end


function initPackages()
  cMath = _ENV.bk3kcMath
  
  if self.doDebug then
    require("/scripts/bk3k/bk3kLogger(0.1).lua")
    L = _ENV.bk3kLogger
    L.context = {"Beginning of ", "init()", " for object: ", tostring(storage.id), " at location (", tostring(storage.doorPosition[1]), ", ", tostring(storage.doorPosition[2]), ") - " } 
      --[1], [2] is mostly all I'd want to swap
    L.dumpTable.storage = storage --adds and index named 'storage' to L.dumpTable 
    L.dumpTable.self = self       --adds and index named 'self' to L.dumpTable
    --you COULD just do L.dump({storage, self}, L.context) but 
    --L.dump(L.dumpTable, L.context) preserves the table names in the logs.
  else
    --this avoids the need to comment out a million items every time we're ready to release
    --L = {}
    L = {
      flush = function(...) end,
      newTable = function(...) end,
      append = function(...) end,
      setMode = function(...) end,
      dump = function(...) end,
      sAT = function(...) end,
      sAR = function(...) end,
      doSanitize = false,
      context = {},
      dumpTable = {}
      }
      --initalize empty table to attempting assignment won't cause errors
    --L.dump = function(...) end
      --empty function won't do anything but won't cause errors when called either
  end
  
end


function askMeAnything(requestedInfo)
  --this function would be the worst idea in the history of ideas if not for the fact this is a game
  --I'm probably porting this sort of thing to a package
  --the package would be for standardized cross-communication between objects
    --so they aren't limited to the boolean values wireNodes transmit.
  return ENV[toString(requestedInfo)]
end


function setLargeQuerry()
  --for larger than standard doors, better to just find the real center for as a basis for scan radius
  storage.queryArea = getQueryArea(storage.center, storage.queryRadius)

end


function setQuery()  --new function of code moved from update() and called by init() so only done once
  if (storage.objectName == "lunarbasedoor") then
    storage.queryRadius = 5.5
    storage.doorPosition[2] = storage.doorPosition[2] + 2.5
    storage.doorPosition[1] = storage.doorPosition[1]
    -- world.debugLine({storage.doorPosition[1], storage.doorPosition[2]}, {storage.doorPosition[1] + storage.queryRadius, storage.doorPosition[2] + storage.queryRadius}, "blue") 
  -- changes door position slightly to make scanning position at height of half
  -- the door (or width if horizontal door)
  elseif storage.isHorizontal then
    storage.doorPosition[1] = storage.doorPosition[1] + 2.5
    storage.doorPosition[2] = storage.doorPosition[2]
    
    -- world.debugLine(getQueryArea(storage.doorPosition, storage.queryRadius)[1], getQueryArea(storage.doorPosition, storage.queryRadius)[2], "blue")
  else
    storage.doorPosition[2] = storage.doorPosition[2] + 2.5
    storage.doorPosition[1] = storage.doorPosition[1] + 0.5
    -- world.debugLine({storage.doorPosition[1], storage.doorPosition[2]}, {storage.doorPosition[1] + storage.queryRadius, storage.doorPosition[2] + storage.queryRadius}, "blue")
  end
  
  -- sb.loginfo("dt")
  -- world.debugPoint(storage.doorPosition, "green")
  -- world.debugPoint(object.position(), "red")
  -- world.debugText("pos: %s, %s", storage.doorPosition[1], storage.doorPosition[2], {object.position()[1], object.position()[2] + 1}, "black")
  
  -- checks for players around and saves
  -- them in array.
   --storage.queryArea = getQueryArea(object.position(), storage.queryRadius)
   storage.queryArea = getQueryArea(storage.doorPosition, storage.queryRadius)
  
end


function setContactQuery()  
  if not storage.isHorizontal then
    
  else --isHorizontal
  
  end
  --world.liquidAlongLine(`Vec2F` startPoint, `Vec2F` endPoint)
end


function onNodeConnectionChange(args)
  updateInteractive()
  storage.wireControlled = object.isInputNodeConnected(0)
  onInputNodeChange({ level = object.getInputNodeLevel(0) })
  updateCollisionAndWires()
  storage.noClearOpen = object.isOutputNodeConnected(0)
end


function onInputNodeChange(args)  --modified
-- @tab args Map of:
--    {
--      node = <(int) index of the node that is changing>
--      level = <new level of the node>
--    }
  if (storage.maxInputNode > 0) then 
    --delegate to another function
    onInputMultiNodeChange(args)
    return 
  end
    
  if args.level then
    storage.wireOpened = true
    realOpenDoor(storage.doorDirection)
  else
    storage.wireOpened = false
    realCloseDoor()
  end
end


function onInputMultiNodeChange(args) --added
 
  if storage.defaultLocked then 
    --delegate to another function
    secureControl(args) 
    return 
  end
  
  storage.wireControlled = object.isInputNodeConnected(0)
  storage.wireOpened = false
  local n = 0
  while (n <= storage.maxInputNode) do
    if object.getInputNodeLevel(n) then
      storage.wireOpened = true
      break  --no need to continue if found any active wire
    end
    n = n + 1
  end
  
  if storage.wireOpened and not storage.state then 
    realOpenDoor(storage.doorDirection) 
  elseif storage.state then
    realCloseDoor()
  else 
    
  end
  
  
end


function secureControl()
  --this requires multiple inputs to open, else lock
  if object.getInputNodeLevel(0) and object.getInputNodeLevel(1) then 
    unlockDoor()
    realOpenDoor(storage.doorDirection)
  else 
    lockDoor()
  end
  --I may expand this later to demand wire inputs that conform to a pattern.  Such as having 8 input nodes, 
  --and only opening when only the correct nodes are activated at once, perhaps in sequence!
  --For now think of this as a built-in AND switch
end


function onInteraction(args)
  if storage.locked then
    animator.playSound("locked")
    return
  end
  
  self.Interacted = true
  --because storage.state will soon flip value
  storage.playerClosed = storage.state
  storage.playerOpened = not storage.state
  
  if not storage.state then
    if storage.isHorizontal then
      -- give the door a cooldown before closing again
      realOpenDoor(args.source[2])
      self.closeCooldown = 2  --increased cooldown
    else
      realOpenDoor(args.source[1])
      self.closeCooldown = 0
    end
  else
    realCloseDoor()
  end
    
end


function updateLight()
  if not storage.state then
    object.setLightColor(config.getParameter("closedLight", {0,0,0,0}))
  else
    object.setLightColor(config.getParameter("openLight", {0,0,0,0}))
  end
end


function updateInteractive()
  object.setInteractive(storage.defaultInteractive and not (object.isInputNodeConnected(0) or storage.defaultLocked or storage.locked))
end


function updateCollisionAndWires()
  updateMaterialSpaces()
  object.setMaterialSpaces(storage.state and storage.openMaterialSpaces or storage.closedMaterialSpaces)
  object.setAllOutputNodes(storage.state)
end


function updateMaterialSpaces()
  if object.isInputNodeConnected(0) then
    storage.closedMaterialSpaces = storage.materialTable[1]
  else 
    storage.closedMaterialSpaces = storage.materialTable[2]
  end
  
end


function initializeMaterialSpaces()
  --forget the vanilla idea of reading attributes and rebuilding tables every time
  --lets just build and store 2 tables at init() time
  --and switch between them as needed with updateMaterialSpaces()
  storage.openMaterialSpaces = config.getParameter("openMaterialSpaces", {})
  storage.closedMaterialSpaces = config.getParameter("closedMaterialSpaces", {})
  storage.materialTable = { {}, {} }
  local metamaterial = {"metamaterial:door", "metamaterial:lockedDoor"}
  local j = 1
  local count = 2 --could use #metamaterial but why bother?
  
  while (j <= count) do
    for _, space in ipairs(storage.spaces) do
      table.insert(storage.materialTable[j], {space, metamaterial[j]})
    end
    j = j + 1
  end
  updateCollisionAndWires()
  
end


function setDirection(direction)
  storage.doorDirection = direction
  animator.setGlobalTag("doorDirection", direction < 0 and "Left" or "Right")
end


function hasCapability(capability)
  --this is called by 
  --scripts/actions/movement.lua
  --scripts/pathing.lua
  --it would be more accurate to call the argument "currentState" but I'll preserve the original name anyhow
  if storage.noNPCuse then
    return false
  end
  
  if capability == 'lockedDoor' then
    return storage.locked
  --elseif (object.isInputNodeConnected(0) or storage.wireOpened or storage.locked or (self.closeCooldown > 0) or (self.openCooldown > 0)) then
  elseif object.isInputNodeConnected(0) or storage.wireOpened or storage.locked then
    return false
  elseif capability == 'door' then
    return true
  elseif capability == 'closedDoor' then
    return not storage.state
  elseif capability == 'openDoor' then
    return storage.state
  else
    return false
  end
end


function setRealSpaces()
  local toReturn = {}
  local adj = cMath.floor(storage.doorPosition)
  for k, v in ipairs(storage.spaces) do
    toReturn[k] = cMath.add(v , adj)
  end
  return toReturn
  
end


function doorOccupiesSpace(position)
  --used by objects/spawner/colonydeed/scanner.lua and called quite often
  --altered implimentation avoids needlessly repeating the same calculations countless times
  local clamp = cMath.floor(position)
  
  for _, space in ipairs(storage.realSpaces) do
    if cMath.match(clamp, space) then
      return true
    end
  end
  return false
end


function lockDoor()
  if storage.noNPCuse then  --special use
    return false
  end
  
  --going to try this and make sure it doesn't break any missions!  Don't "think" it will if called postInit()
  --doing this to potentially cut off stupid NPC behavior at outpost etc
    --(locking wired doors that should be opened by proximity sensors etc)
  
  if storage.postInit and object.isOutputNodeConnected(0) then
    --no "locking" wire controlled doors.  
    onInputMultiNodeChange()
    return
  end
  
  --below code is fine
  if (not storage.locked and (self.closeCooldown <= 0)) then 
    
    storage.locked = true
    
    if storage.state then
      animator.setAnimationState("doorState", "locking")
      storage.state = false
      animator.playSound("close")
    else 
      --no need to close door etc, just change animation state
      animator.setAnimationState("doorState", storage.lockedAnimation_stateName)
    end
    
    updateCollisionAndWires()
    updateLight()
    
  end
end


function unlockDoor()
  storage.locked = false
  updateInteractive()
  if not storage.state then
    animator.setAnimationState("doorState", "closed")
  end
end


function realCloseDoor()
  -- only close door when cooldown is zero
  --if storage.state and (self.closeCooldown <= 0) then
  if storage.state then
    storage.state = false
    animator.playSound("close")
    animator.setAnimationState("doorState", "closing")
  end
  updateCollisionAndWires()
  updateLight()
  -- world.debugText("Close!", object.position(), "red")
end


function closeDoor()
  --all internal functions will use realCloseDoor()
  --see openDoor() for why
if storage.wireControlled then return end
  self.npcClosed = true
  self.openCooldown = 2
  realCloseDoor()
end


function openDoor(direction)
  --all internal functions will use realOpenDoor() 
  --therefore if this is called, we know it is externally sourced and can take extra measures
  
  unlockDoor()
  self.closeCooldown = 2
  if (direction == nil) then
    setDirectionNPC()
  end
  realOpenDoor(direction)
    
  
end


function realOpenDoor(direction)
  if not storage.state then
    storage.state = true
    setDirection((direction == nil or direction * object.direction() < 0) and -1 or 1)
    animator.playSound("open")
    animator.setAnimationState("doorState", storage.openingAnimation_stateName)
    --if storage.isHorizontal and not self.interacted then self.openCooldown = 2 end
  else 
    animator.setAnimationState("doorState", "open")
  end
   
  updateCollisionAndWires()
  updateLight()
  -- world.debugText("Open!", object.position(), "red")
end


-- Checks if doors is horizontal, depending on different use of anchors.
--
-- @return BOOL value for confirmation
--
function isDoorHorizontal() 
  --This will only run from init()
  --3 checks, being defined from the actual door would probably be fastest
  --failing that it checks for anchors
  --and failing that, it compares spaces()
    
    
  if (type(config.getParameter("horizontal_door", nil)) == "boolean") then
    return config.getParameter("horizontal_door", nil)
    end
  
  local anchors = config.getParameter("anchors", {"top", "bottom"})
 
  for _,anchor in ipairs(anchors) do
    if anchor == "left" or anchor == "right" then 
      return true
    end
  end
    
  if not storage.corners then 
    findCorners()
  end
  
  --lazy search assuming square/rectangle
  
  local xDist = cMath.xDist(storage.corners.upperRight, storage.corners.upperLeft)
  local yDist = cMath.yDist(storage.corners.upperRight, storage.corners.lowerRight)
  
  if (xDist > yDist) then
    return true
  else 
    return false
  end
end


function findCenter()
  if not storage.corners then
    findCorners()
  end
  
  return cMath.midPoint(storage.corners.upperRight, storage.corners.lowerLeft)
end 


function findCorners()
  --I'm completely assuming a square/rectangle and simple shape.  I'd have to do this differently if not.
  local highX = cMath.highX(storage.realSpaces)
  local lowX = cMath.lowX(storage.realSpaces)
  local highY = cMath.highY(storage.realSpaces)
  local lowY = cMath.lowY(storage.realSpaces)
  
  storage.corners = { 
                    upperRight = {highX, highY},
                    lowerRight = {highX, lowY},
                    upperLeft = {lowX, highY},
                    lowerLeft = {lowX, lowY} 
                    }
end


-- Modifies query values for horizontal doors
--
-- If the door is horizontal, the position and radius are used as min & max
-- positions which causes Query to use a rectangular scanning area.
--
-- @tab position Default door position
-- @tab radius Wanted radius/sidelenght for scanning area
--
-- @return minPos Position for left bottom corner of scanning rectangle
-- @return minPos Position for right top corner of scanning rectangle
-- @return position Does get return unmodified if vertical door
-- @return radius Does get return unmodified if vertical door
--
function getQueryArea(position, radius)
  if storage.isHorizontal then
    local minPos = {position[1] - radius, position[2] - radius}
    local maxPos = {position[1] + radius, position[2]} -- Don't query above, want players to walk on the door
    return {minPos, maxPos}
  else
    return {position, radius}
  end
end


function noAutomatic() --added
  return (storage.doorException or storage.defaultLocked or config.getParameter("noAutomaticDoors", false))
end


function doorException() --added, call this before noAutomatic() in init()
  --I'd prefer to load this from JSON, but don't know that Starbound would allow access beyond current object
  --so manual table loading it is!  This seems more managable in case more exceptions get added.
  local doorTable = {
    "castlehiddentrapdoor", 
    "castlehiddendoor",
    "templehiddentrapdoor", 
    "pilch_horizdoor", 
    "dirttrapdoor",
    "stonedoor",
    "ancientlightplatform",
    "ancienthiddenplatform",
    "templepressureplatform" 
    }
  
  local doorCount = #doorTable
  local i = 1
  while (i <= doorCount) do
    if (doorTable[i] == storage.objectName) then
      return true
    end
    i = i + 1
  end
  return false
end

-- Main function, is running constantly with delta t time interval, functions esentially like an infinite while loop
--
function update(dt)
  -- lowers cooldown with each cycle
  if (self.closeCooldown > 0) then 
    self.closeCooldown = self.closeCooldown - dt
  end
  if (self.openCooldown > 0) then 
    self.openCooldown = self.openCooldown - dt
  end
  
  self.interacted = false
  --everything remaining is used to make doors automatic, and therefore should be skipped
  --when automatic functionality is undesirable.  No automatic when wired to input 1, opened by wire, 
  --don't need automatic functionality when door opened from ANY wire input or locked
  if (storage.noAuto or ((storage.wireControlled or storage.wireOpened) and not self.npcClosed) or storage.locked) then 
    return 
  elseif self.npcClosed and storage.wireControlled and (self.openCooldown <= 0) then
    --onInputNodeChange()
    setDirectionNPC()
    onInputMultiNodeChange()  --should open the door if still approriate per wire input at that point
    self.closeCooldown = 0.1
    self.openCooldown = 0.1
    self.npcClosed = false
    return
  end
  
  local objectIdsOpen = world.entityQuery(storage.queryArea[1], storage.queryArea[2], {
        withoutEntityId = storage.id,
        includedTypes = storage.scanTargets,
        boundMode = storage.boundVar})
        
  if (#objectIdsOpen == 0) then
    -- resetting toggle once player gets out of range
    storage.playerClosed = false
    if not storage.noClearOpen then
      --found some doors in missions with only wired outputs!
      --this will prevent doors with wired outputNode(0) from autoClosing when player opened
      storage.playerOpened = false
    end
    autoClose()
  else 
    autoOpen(objectIdsOpen)
  end
end


function autoOpen(objectIdsOpen)
  if storage.playerClosed or storage.state or (self.openCooldown > 0) then 
    return 
  end
  -- query for player at door proximity
  local playerPosition = world.entityPosition(objectIdsOpen[1])
  -- sb.loginfo("Player detected!")
  -- open door in direction depending on position of the player
    
  storage.playerOpened = false
  
  if not storage.isHorizontal then
    realOpenDoor(playerPosition[1] - storage.doorPosition[1])
	  self.closeCooldown = 0.1
    -- sb.loginfo("direction: %d", playerPosition[1] - object.position()[1])
  else
    realOpenDoor(playerPosition[2] - storage.doorPosition[2])
    self.closeCooldown = 2
    --added a small timer
    -- sb.loginfo("direction: %d", playerPosition[1] - object.position()[1])
  end
end


function autoClose()
  if (self.closeCooldown > 0) or not storage.state or storage.playerOpened then
    return
  end
  -- check for NPCs in a smaller radius
  local npcIds = world.npcQuery(storage.doorPosition, storage.queryRadius - 1, {boundMode = storage.boundVar})
    
    -- prevents door spasming
  if (#npcIds > 0) and (not storage.isHorizontal) then
    return
  end
    
 --disable for NPC's, close when opened by player
  realCloseDoor()
  storage.playerClosed = false
end


function setDirectionNPC()
  --special case function corrects direction if NPC opened door or will be nearest when opening
  local npcIds = world.npcQuery(storage.doorPosition, storage.queryRadius - 1, {boundMode = storage.boundVar})
  if (#npcIds == 0) then 
    return --in theory an NPC may move before this is called
  end
  local npcPosition = world.entityPosition(npcIds[1])
  
  if not storage.isHorizontal then
    setDirection((npcPosition[1] - storage.doorPosition[1]))
  else
    setDirection((npcPosition[2] - storage.doorPosition[2]))
  end
end
