--efficient math for tables which you know to be 2d coordinates
--contact bk3k for any requested expansions or to report problems
--free to use reproduce/distribute/modify/etc, but rename to avoid conflict please
--yes that includes commercial use such as by Chuckelfish, in which case I'd appreciate a shout out


local add 
local sub
local addX
local addY
local subX
local subY
local dist
local xDist
local yDist
local floor
local noNeg  --internal function only
local match
local matchX
local matchY
local highX
local highY
local lowX
local lowY
local midPoint
local travel
local xTravel
local yTravel
local cString
local tString

--local codeBlocks = {}

add = function (t1, t2)
  return {(t1[1] + t2[1]), (t1[2] + t2[2])}
end

sub = function(t1, t2)
  return {(t1[1] - t2[1]), (t1[2] - t2[2])}
end

addX = function (t1, t2)
  return {(t1[1] + t2[1]), t1[2]}
end

subX = function(t1, t2)
  return {(t1[1] - t2[1]), t1[2]}
end

addY = function (t1, t2)
  return {t1[1], (t1[2] + t2[2])}
end

subY = function(t1, t2)
  return {t1[1], (t1[2] - t2[2])}
end

dist = function(t1, t2)
  return math.sqrt(((t1[1] - t2[1])^2) + ((t1[2] - t2[2])^2))
end

xDist = function(t1, t2)
  return noNeg(t1[1] - t2[1])
end

yDist = function(t1, t2)
  return noNeg(t1[2] - t2[2])
end

floor = function(t)
  return {math.floor(t[1]), math.floor(t[2])}
end

noNeg = function(n)
  if n < 0 then 
    n = n * -1
  end
  return n
end

match = function(t1, t2)
  return (t1[1] == t2[1]) and (t1[2] == t2[2])
end

matchX = function(t1, t2)
  return (t1[1] == t2[1])
end

matchY = function(t1, t2)
  return (t1[2] == t2[2])
end

highX = function(coT)
  local s = coT[1]  --s = first set of coordinates in table coT
  local highest = s[1]
  for _, co in ipairs(coT) do
    if (co[1] > highest) then
      highest = co[1]
    end
  end
  return highest
end

highY = function(coT)
  local s = coT[1]
  local highest = s[2]
  for _, co in ipairs(coT) do
    if (co[2] > highest) then
      highest = co[2]
    end
  end
  return highest
end

lowX = function(coT)
  local s = coT[1]
  local lowest = s[1]
  for _, co in ipairs(coT) do
    if (co[1] < lowest) then
      lowest = co[1]
    end
  end
  return lowest
end

lowY = function(coT)
  local s = coT[1]
  local lowest = s[2]
  for _, co in ipairs(coT) do
    if (co[2] < lowest) then
      lowest = co[2]
    end
  end
  return lowest
end

midPoint = function(t1, t2)
  return {
    (t1[1] + t2[1]) / 2,
    (t1[2] + t2[2]) / 2
    }
end

travel = function(source, dest)
  return {(dest[1] - source[1]), (dest[2] - source[2])}
end

xTravel = function(source, dest)
  return dest[1] - source[1]
end

yTravel = function(source, dest)
  return dest[2] - source[2]
end

cString = function(t)
  return "(" .. tostring(t[1]) .. ", " .. tostring(t[2]) .. ")"
end

tString = function(coT)
  local toReturn = ""
  local s = #coT
  for t, c in ipairs(coT) do
    toReturn = toReturn .. "(" .. tostring(c[1]) .. ", " .. tostring(c[2]) .. ")"
    if (s ~= t) then
      toReturn = toReturn .. ", "
    end
  end
end


--using my handle makes for a name unlikely to already exist in _ENV 
bk3kcMath = {
  add = add,
  sub = sub,
  addX = addX,
  subX = subX,
  addY = addY,
  subY = subY,
  xDist = xDist,
  yDist = yDist,
  floor = floor,
  match = match,
  matchX = matchX,
  matchY = matchY,
  highX = highX,
  highY = highY,
  lowX = lowX,
  lowY = lowY,
  midPoint = midPoint,
  travel = travel,
  xTravel = xTravel,
  yTravel = yTravel,
  cString = cString,
  tString = tString
  }

return bk3kcMath