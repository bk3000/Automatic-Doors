-- automatic doors 3.5
-- basic code by Chucklefish, additional code by lornlynx (with some help from Healthire), greatly reworked and updated by bk3k
    --well at this point not much Chucklefish code remains, but it got us started and provided a good reference.
-- the additional code is documentated


----( denotes the begining of a function
----) denotes the end of a function block
  --the () should make it easier to see start/end when combined with an advanced text editor's brace highlighting
  --hopefully this isn't confusing!  But it allows for defining a slimmer function when possible.

require("/scripts/bk3k/bk3k-cMath2d.lua")
require("/scripts/bk3k/bk3kLogger(0.1).lua")

extraFunction = function() end  --blank function called by update.  If more features needed for specialty purposes
                                  --overwrite/replace with an actual function
                                  --just put this script sooner on the list
                                  


function init()
  message.setHandler("openDoor", function() openDoor() end)
  message.setHandler("lockDoor", function() lockDoor() end)
  message.setHandler("closeDoor", function() closeDoor() end)

  self.doDebug = false --change to false for release versions!  Or you'll have HUGE logs!
  storage.id = entity.id()
  storage.doorPosition = object.position()

  initPackages()

  
  if not storage.quickCheck then 
    storage.spaces = object.spaces()
    storage.quickCheck = initDoorStuff()
    --L.dump(L.dumpTable, L.context)
    
    storage.objectName = config.getParameter("objectName", "door")
    
   --boolean values
    storage.postInit = false
    storage.defaultLocked = config.getParameter("defaultlocked", false)
    storage.locked = ( storage.defaultLocked or config.getParameter("locked", false) )
    storage.defaultInteractive =  config.getParameter("interactive", true)
    --storage.wireOpened = false
    --storage.wireControlled = object.isInputNodeConnected(0)
    storage.state = ((config.getParameter("defaultState", "closed") == "open") and not storage.locked)
    storage.playerOpened = false
    storage.playerClosed = false
    storage.liquidAware = config.getParameter("liquidAware" , false)
    storage.lightAware = config.getParameter("lightAware" , false)
    --once implimented, check very infrequently
    storage.doorException = doorException()  --check if door is part of exception list
    storage.noAuto =  noAutomatic()
    storage.noNPCuse = config.getParameter("noNPCuse", false)
      --this is for doors that NPCs must never be allowed to open
        --special case use such as not really a "door" in the traditional sense
        --sort of thing which would be triggered by missions/AI/etc.
        
    
    --numeric values
    
    
    --standard LUA tables start at 1 instead of 0.  Starbound assignes the first node to 0 despite this.
    --storage.queryRadius = config.getParameter("queryOpenRadius", 5)
      --I don't like the door opening directly in my face, but edit to any default value you like!
    
    
    --string values
    storage.openingAnimation_stateName = config.getParameter("openingAnimation", "open")
    --if doors have an opening animation cycle and frames seperate from the "open" state
      --my doors use "opening"
    storage.lockingAnimation_stateName = config.getParameter("lockingAnimation", "closed")
    --if they have an actual locked animation and frames, use instead of "closed" when locked
      --my doors use "locked"
    storage.lockedAnimation_stateName = config.getParameter("lockedAnimation", "closed")
    storage.boundVar = config.getParameter("detectBoundMode", "CollisionArea")


    --table values
    storage.liquidActions = config.getParameter("liquidActions", {default = "ignore"})
    --tells us how to react to the presence of various liquids.  If liquid not listed, use default.
    -- will not have any meaning unless storage.liquidAware is true
    storage.lightColors = storage.lightColors or {
      config.getParameter("openLight", {0,0,0,0}),
      config.getParameter("closedLight", {0,0,0,0})
      }
  end
  
  storage.maxInputNode = ( #(config.getParameter("inputNodes", {})) - 1 )
  storage.maxOutputNode = ( #(config.getParameter("outputNodes", {})) - 1 )
  
  storage.out0 = (storage.maxOutputNode > -1)
  storage.out1 = (storage.maxOutputNode > 0)
  
  self.closeCooldown = 0
  self.openCooldown = 0
  self.npcClosed = false

  anyInputNodeConnected()
  setDirection(storage.doorDirection or object.direction())
  initMaterialSpaces()
  --L.dump(L.dumpTable, {"After calling initMaterialSpaces"})
  updateCollisionAndWires()
  --called only in init(), will call updateMaterialSpaces() after completion
  

  if storage.state and not (storage.locked or storage.wireControlled or storage.wireOpened) then
    realOpenDoor(storage.doorDirection)
  elseif storage.locked then
    lockDoor()
  else
    onInputMultiNodeChange()
  end

  updateInteractive()
  initIncludedTypes() --things we'll regularily scan for

  --if storage.liquidAware or storage.lightAware then
    --initContactQuery()  --not implimented yet 
      --and in light of better ways to control for liquids, this may well get scrapped entirely
  --end
      
  --L.context[1] = "End of "
  --L.dump(L.dumpTable, L.context)
  storage.postInit = true
end


function initPackages()  --added
  cMath = _ENV.bk3kcMath
  L = _ENV.bk3kLogger

  if self.doDebug then --this avoids the need to comment out a million items every time we're ready to release
    L = _ENV.bk3kLogger
    L.context = {"Beginning of ", "init()", " for object: ", tostring(storage.id), " at location ", cMath.cString(storage.doorPosition), " - " }
      --[1], [2] is mostly all I'd want to swap
    L.dumpTable.storage = storage --adds an index named 'storage' to L.dumpTable
    L.dumpTable.self = self       --adds an index named 'self' to L.dumpTable
      --you COULD just do L.dump({storage, self}, L.context) but
      --L.dump(L.dumpTable, L.context) preserves the table names in the logs.
  else
    L = _ENV.bk3kLogger.blankPackage()
      --nothing but empty tables/values and functions as such would not cause errors when called
  end
  
end


function initIncludedTypes()  --added
  storage.scanTargets = storage.scanTargets or config.getParameter("scanTargets", {"player", "vehicle"})
  if not (#storage.scanTargets > 0) or not (type(storage.scanTargets) == "table") then
    storage.scanTargets = {"player", "vehicle"}
  end
end


function initDoorStuff()  --added
  --replaces a disorganized cluster of other functions
  --should make the flow of the code easier to parse and be slightly more efficient

  storage.queryRadius = config.getParameter("queryOpenRadius", 5)
    --this value may get overwritten later because scans start from center, so radius can't be less than half
    --else it can't detect across whole door if the door is rather large

  storage.realSpaces = {}
  local clamp = cMath.floor(storage.doorPosition) --it probably isn't strickly necessary to clamp the location
  for k, v in ipairs(storage.spaces) do
    storage.realSpaces[k] = cMath.add(v , clamp)
  end

  local highX = cMath.highX(storage.realSpaces)
  local lowX = cMath.lowX(storage.realSpaces)
  local highY = cMath.highY(storage.realSpaces)
  local lowY = cMath.lowY(storage.realSpaces)

  storage.corners = {
                    upperRight = {highX, highY},
                    lowerRight = {highX, lowY},
                    upperLeft = {lowX, highY},
                    lowerLeft = {lowX, lowY}
                    } --may not represent actual corners, but outer dimensions in oddly shaped objects
                        --a fact we could easily determine at this point by feeding each "corner" to doorOccupiesSpace()
                        --if we needed to know it

  --storage.center = cMath.midPoint(storage.corners.upperRight, storage.corners.lowerLeft)
  storage.center =  {
                    (highX + lowX) / 2,
                    (highY + lowY) / 2
                    }

  --local xDist = cMath.xDist(storage.corners.upperRight, storage.corners.upperLeft)
  --local yDist = cMath.yDist(storage.corners.upperRight, storage.corners.lowerRight)
  local xDist = highX - lowX
  local yDist = highY - lowY
  local hD = config.getParameter("horizontal_door", nil)  --this can override the detected value

  if hD or ((xDist > yDist) and (hD ~= false)) then
    if (storage.queryRadius < (xDist / 2)) then
      storage.queryRadius = xDist / 2
    end
    if not config.getParameter("platformDoors", false) then  --if set then the 
      storage.queryCenter = cMath.subY(storage.center, {_, storage.queryRadius})
    else 
      storage.queryCenter = storage.center
    end
    --L.dump({storage.queryCenter}, {"after door was determined to be horizontal"})
    storage.isHorizontal = true
  else
    if (storage.queryRadius < (yDist / 2)) then
      storage.queryRadius = yDist / 2
    end
    storage.queryCenter = storage.center
    --L.dump({storage.queryCenter}, {"after door was determined to not be horizontal"})
    storage.isHorizontal = false
  end
  
  return true
    --always return true to set storage.quickCheck and if set this function shouldn't run at all
    --in the event that all the storage variables remain set it would just be a waste of CPU cycles.
end


function noAutomatic() --added, called by init()
  return (storage.doorException or storage.defaultLocked or config.getParameter("noAutomaticDoors", false))
end


function doorException() --added, called by noAutomatic()
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


-----------pure initialization above, mostly actions below

function onNodeConnectionChange(args)
  anyInputNodeConnected()
  updateInteractive()
  onInputMultiNodeChange()
  --onInputNodeChange({ level = object.getInputNodeLevel(0) })
  updateCollisionAndWires()
  
end


function anyInputNodeConnected() --called from init() and onNodeConnectionChange()
  storage.anyInputNodeConnected = false
  local n = 0
  while (n <= storage.maxInputNode) do
    if object.isInputNodeConnected(n) then
      storage.anyInputNodeConnected = true
      break
    end
    n = n + 1
  end
  
  storage.wireControlled = object.isInputNodeConnected(0)
  storage.noClearOpen = object.isOutputNodeConnected(0)  --output not input!
  
  
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
    --trying this out
    animator.setAnimationState("doorState", storage.lockingAnimation_stateName)
  end
end


function onInputMultiNodeChange(args) --added
  
  if storage.defaultLocked then
    --delegate to another function
    secureControl()
    return
  end
  
  local wasOpen = storage.state
  storage.wireOpened = false
  local n = 0
  while (n <= storage.maxInputNode) do
    if object.getInputNodeLevel(n) then
      storage.wireOpened = true
      break  --no need to continue if found any active wire
    end
    n = n + 1
  end

  if storage.wireOpened then
    if not storage.state then
      realOpenDoor(storage.doorDirection)
    else
    
    end
  elseif storage.anyInputNodeConnected then
    realCloseDoor()
    --trying this out
    --animator.setAnimationState("doorState", storage.lockingAnimation_stateName)
  else 
    --autoClose()
  end
  --updateAnimation(wasOpen)

end


function secureControl()  --added, probably will be replaced by better implimentation later
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
  if storage.locked or storage.wireControlled then
    animator.playSound("locked")
    return
  end

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
  if storage.state then
    object.setLightColor(storage.lightColors[1])
  else
    object.setLightColor(storage.lightColors[2])
  end
end


function updateAnimation(wasOpen)
  --storage.state == isOpen
  local aState
  
  if (storage.state ~= wasOpen) then
    if storage.state then --door opening
      aState = storage.openingAnimation_stateName
      animator.playSound("open")
    else  --door closing/locking
      if storage.locked or storage.wireControlled then
        aState = storage.lockingAnimation_stateName
      else
        aState = "closing" --already vanilla supported transition state
      end
      animator.playSound("close")
    end
  elseif storage.locked or storage.wireControlled then
    aState = storage.lockedAnimation_stateName
  elseif storage.state then
    aState = "open"
  else
    aState = "closed"
  end
  
  animator.setAnimationState("doorState", aState)       
end


function updateInteractive()
  object.setInteractive(storage.defaultInteractive and not (storage.wireControlled or storage.defaultLocked or storage.locked))
end


function updateCollisionAndWires()
  updateMaterialSpaces()
  if storage.state then 
    object.setMaterialSpaces(storage.openMaterialSpaces)
  else 
    object.setMaterialSpaces(storage.closedMaterialSpaces)
  end
  
  --object.setAllOutputNodes(storage.state)
  if storage.out0 then 
    object.setOutputNodeLevel(0, storage.state)
  end
end


function updateMaterialSpaces() -- added
  if storage.closedMatSpacesDefined then
    return
  elseif storage.wireControlled then
    storage.closedMaterialSpaces = storage.matTableClosed[2] --"metamaterial:lockedDoor"
  else
    storage.closedMaterialSpaces = storage.matTableClosed[1] -- "metamaterial:door"
  end
end


function initMaterialSpaces()  --added
  --forget the vanilla idea of reading attributes and rebuilding tables every time
  --lets just build and store full material tables at init() time
  --and switch between them as needed with updateMaterialSpaces()
  
  storage.openMaterialSpaces = config.getParameter("openMaterialSpaces", {})  --set by this function, maybe changed
  storage.closedMaterialSpaces = config.getParameter("closedMaterialSpaces", {})  --set, not changed by this function
  storage.closedMatSpacesDefined = ( (#storage.closedMaterialSpaces) >  0 )
  storage.matTableClosed = { {}, {} }
  storage.matTableOpen = { {}, {} }
  
  --local metaMatC = config.getParameter("closedMaterials", nil) or {"bk3k_invisible_hardBlock", "bk3k_invisible_hardBlock"}
  local metaMatC = config.getParameter("closedMaterials", nil) or {"metamaterial:door", "metamaterial:lockedDoor"}
  local metaMatO =  config.getParameter("openMaterials", nil)  
    --^^these are just lists of available metaMaterials per state
  
  local j = 1
  local count = #metaMatC 

  while (j <= count) do
    for _, space in ipairs(storage.spaces) do
      table.insert(storage.matTableClosed[j], {space, metaMatC[j]})
    end
    j = j + 1
  end
  
  if (#storage.openMaterialSpaces > 0) and (#metaMatO > 0) then --openMaterialSpaces won't be redefined if no defined mats
    j = 1
    count = #metaMatO
    
    while (j <= count) do
      for _, space in ipairs(storage.spaces) do
        table.insert(storage.matTableOpen[j], {space, metaMatO[j]})
      end
      j = j + 1
    end
    
    table.insert(storage.matTableOpen, { } ) 
      --add an extra blank table element at the end for when clearing is desirable
    storage.openMaterialSpaces = storage.matTableOpen[1]
      --currently assuming only 1 material defined for this
      --but this could be redefined by setMaterialSpaces
  end
end


function setMaterialSpaces(whatState, whatMaterialTableIndex) --added
  --most doors won't need this and probably only gets called externally through scriptedEntity() only by entities 
  --which understand the specific door and thus what materials are available at what index
  
  if (whatState == "open") then
    storage.openMaterialSpaces = storage.matTableOpen[i]
  elseif (whatState == "closed") then 
    storage.closedMaterialSpaces = storage.matTableClosed[i]
  end
end


function setDirection(direction)  --one of the few NOT changed!
  storage.doorDirection = direction
  animator.setGlobalTag("doorDirection", direction < 0 and "Left" or "Right")
end


function hasCapability(capability)
  --this is called by
  --scripts/actions/movement.lua
  --scripts/pathing.lua
  if capability == "automaticDoor" then
    return not (storage.noAuto or object.isInputNodeConnected(0))
  elseif capability == "objectInterfacing" then
    return config.getParameter("objectInterfacing", false)
    --note that Automatic Doors will NOT be handling this sort of thing.  A seperate script will.
    --This will only inform other mod objects of these capabilities.
  elseif storage.noNPCuse then
    return false
  elseif capability == 'lockedDoor' then
    return storage.locked
  --elseif (object.isInputNodeConnected(0) or storage.wireOpened or storage.locked or (self.closeCooldown > 0) or (self.openCooldown > 0)) then
  elseif storage.wireControlled or storage.wireOpened or storage.locked then
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
  local wasOpen = storage.state
  if (not storage.locked) and (self.closeCooldown <= 0) then

    storage.locked = true

    if storage.state then
      --animator.setAnimationState("doorState", "locking")
      storage.state = false
    else
      --no need to close door etc, just change animation state
      --animator.setAnimationState("doorState", storage.lockingAnimation_stateName)
    end
  end
  updateCollisionAndWires()
  updateAnimation(wasOpen)
  updateLight()
  
end


function unlockDoor()
  local wasOpen = storage.state
  storage.locked = false
  updateInteractive()
  updateAnimation(wasOpen)
  return true --don't know why, but vanilla does this return
end


function realCloseDoor()
  -- only close door when cooldown is zero
  --if storage.state and (self.closeCooldown <= 0) then
  local wasOpen = storage.state
  --if storage.state then
    storage.state = false
    --animator.playSound("close")
    --animator.setAnimationState("doorState", "closing")
  --end
  updateCollisionAndWires()
  updateAnimation(wasOpen)
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
  local wasOpen = storage.state
  if not storage.state then
    storage.state = true
    setDirection((direction == nil or direction * object.direction() < 0) and -1 or 1)
    --animator.playSound("open")
    --animator.setAnimationState("doorState", storage.openingAnimation_stateName)
  --else
    --animator.setAnimationState("doorState", "open")
  end

  updateCollisionAndWires()
  updateAnimation(wasOpen)
  updateLight()
  -- world.debugText("Open!", object.position(), "red")
end


-- Main function, is running constantly with delta t time interval, functions esentially like an infinite while loop
--
function update(dt)
  -- lowers cooldown with each cycle
  if self.closeCooldown > 0 then
    self.closeCooldown = self.closeCooldown - dt
  end
  if self.openCooldown > 0 then
    self.openCooldown = self.openCooldown - dt
  end
  
  --everything remaining is used to make doors automatic, and therefore should be skipped
  --when automatic functionality is undesirable.  No automatic when wired to input 1, opened by wire,
  --don't need automatic functionality when door opened from ANY wire input or locked
  if storage.noAuto or (storage.wireControlled and not self.npcClosed) or storage.locked then
    return
  elseif self.npcClosed and storage.wireControlled and (self.openCooldown <= 0) then
    --onInputNodeChange()
    setDirectionNPC()
    onInputMultiNodeChange()  --should open the door if still approriate per wire input at that point
    self.closeCooldown = 0.05
    self.openCooldown = 0.05
    self.npcClosed = false
    return
  end

  local objectIdsOpen = world.entityQuery(storage.queryCenter, 
        storage.queryRadius, {
        withoutEntityId = storage.id,
        includedTypes = storage.scanTargets,
        boundMode = storage.boundVar})
        
  local targetsfound = (#objectIdsOpen > 0)

  if targetsfound then
    autoOpen(objectIdsOpen)
  else
    -- resetting toggle once player gets out of range
    storage.playerClosed = false
    if not storage.noClearOpen then
      --found some doors in missions with only wired outputs!
      --this will prevent doors with wired outputNode(0) from autoClosing when player opened
      storage.playerOpened = false
    end
    
    autoClose()
  end
  
  if storage.out1 and (self.previousFound ~= targetsfound) then 
    --if the door has a second output node, output true when any scan target found despite the state of the door itself
      --defined by "scanTargets" or defaults to {"player", "vehicle"}
    object.setOutputNodeLevel(1, targetsfound)
  end
  self.previousFound = targetsfound
  extraFunction() --by default this is a blank function
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
    realOpenDoor( cMath.xTravel(storage.doorPosition, playerPosition) )
	  --self.closeCooldown = 0.05
    -- sb.loginfo("direction: %d", playerPosition[1] - object.position()[1])
  else
    realOpenDoor( cMath.yTravel(storage.doorPosition, playerPosition) )
    self.closeCooldown = 2
    --added a small timer
    -- sb.loginfo("direction: %d", playerPosition[1] - object.position()[1])
  end
end


function autoClose()
  if (self.closeCooldown > 0) or not storage.state or storage.playerOpened or storage.wireOpened then
    return
  end
  -- check for NPCs in a smaller radius
  local npcIds = world.npcQuery(storage.queryCenter, storage.queryRadius - 1, {boundMode = storage.boundVar})

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
  local npcIds = world.npcQuery(storage.queryCenter, storage.queryRadius - 1, {boundMode = storage.boundVar})
  if (#npcIds == 0) then
    return --in theory an NPC may move before this is called
  end
  local npcPosition = world.entityPosition(npcIds[1])

  if not storage.isHorizontal then
    setDirection( cMath.xTravel(storage.doorPosition, npcPosition) )
  else
    setDirection( cMath.yTravel(storage.doorPosition, npcPosition) )
  end
end
