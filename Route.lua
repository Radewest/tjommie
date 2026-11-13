-- Tjommie: Routes
-- Add-ons can't see roads or terrain, so "fastest route" here means: run straight there, or
-- run to the nearest flight master you know, fly to the one nearest the target, and run the rest.
-- Flight masters are remembered whenever you open a flight map (per character).
-- Also mirrors the meeting point into Blizzard's own map waypoint / on-screen tracker when the
-- client has it (setting: "Blizzard waypoint for meet-ups").
--
-- ns:PlanRoute(c, wx, wy) -> plan { kind = "walk"|"fly"|"continent"|"unknown", time, dist,
--                                    from = node, to = node, legs = { {c,x1,y1,x2,y2,fly}, ... } }

local _, ns = ...

local RUN_SPEED, MOUNT_SPEED = 7, 14       -- yards/second (normal run, 60% mount)
local FLIGHT_SPEED = 30                    -- yards/second, roughly
local FLIGHT_DETOUR = 1.2                  -- flight paths aren't straight lines
local FLIGHT_OVERHEAD = 15                 -- seconds: talking to the flight master, landing
local FLY_IF_FASTER = 0.85                 -- only suggest flying when it's clearly quicker

---------------------------------------------------------------------------
-- Remember flight masters
---------------------------------------------------------------------------
local function nodes()
  ns.cdb.flightNodes = ns.cdb.flightNodes or {}
  return ns.cdb.flightNodes
end

local function continentMapFor(mapID)
  local id = mapID
  for _ = 1, 6 do
    local info = id and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    if not info then return mapID end
    if info.mapType == 2 then return id end -- continent
    id = info.parentMapID
  end
  return mapID
end

local function remember(name, mapID, x, y)
  if not (name and mapID and x and y) or (x == 0 and y == 0) then return end
  local c, wx, wy = ns.MapToWorld(mapID, x, y)
  if not wx then return end
  nodes()[name] = { name = (name:match("^([^,]+)") or name), c = c, x = wx, y = wy }
end

local function scanTaxi()
  local mapID = GetTaxiMapID and GetTaxiMapID()
  if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and mapID then
    local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
    if ok and list then
      for _, n in ipairs(list) do
        -- state 2 = unreachable (not discovered)
        if n.state ~= 2 and n.position then
          local x, y = n.position:GetXY()
          remember(n.name, mapID, x, y)
        end
      end
      return
    end
  end
  -- Classic API fallback: positions are on the continent's flight map
  if NumTaxiNodes and TaxiNodeName and TaxiNodePosition then
    local pmap = C_Map.GetBestMapForUnit("player")
    local cont = pmap and continentMapFor(pmap)
    for i = 1, (NumTaxiNodes() or 0) do
      local kind = TaxiNodeGetType and TaxiNodeGetType(i)
      if kind == "CURRENT" or kind == "REACHABLE" then
        local x, y = TaxiNodePosition(i)
        remember(TaxiNodeName(i), cont, x, y)
      end
    end
  end
end
ns:On("TAXIMAP_OPENED", function() C_Timer.After(0.2, scanTaxi) end)

function ns:KnownFlightCount()
  local n = 0
  for _ in pairs(nodes()) do n = n + 1 end
  return n
end

---------------------------------------------------------------------------
-- Route planning
---------------------------------------------------------------------------
local function dist(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

local function groundSpeed()
  if IsMounted and IsMounted() then return MOUNT_SPEED end
  return (UnitLevel("player") >= 40) and MOUNT_SPEED or RUN_SPEED
end

local function nearestNode(c, x, y)
  local best, bestD
  for _, n in pairs(nodes()) do
    if n.c == c then
      local d = dist(x, y, n.x, n.y)
      if not bestD or d < bestD then best, bestD = n, d end
    end
  end
  return best, bestD
end

function ns:PlanRoute(tc, tx, ty)
  local _, _, _, mc, mx, my = ns.GetPlayerPos()
  if not mx or not tx then return { kind = "unknown" } end
  if mc ~= tc then return { kind = "continent" } end

  local v = groundSpeed()
  local direct = dist(mx, my, tx, ty)
  local plan = { kind = "walk", dist = direct, time = direct / v,
                 legs = { { c = mc, x1 = mx, y1 = my, x2 = tx, y2 = ty } } }

  local a, da = nearestNode(mc, mx, my)
  local b, db = nearestNode(mc, tx, ty)
  if a and b and a ~= b then
    local flight = dist(a.x, a.y, b.x, b.y) * FLIGHT_DETOUR
    local t = da / v + flight / FLIGHT_SPEED + db / v + FLIGHT_OVERHEAD
    if t < plan.time * FLY_IF_FASTER then
      plan = { kind = "fly", time = t, dist = direct, from = a, to = b, walkTo = da, walkFrom = db,
               walkTime = plan.time,
               legs = { { c = mc, x1 = mx, y1 = my, x2 = a.x, y2 = a.y },
                        { c = mc, x1 = a.x, y1 = a.y, x2 = b.x, y2 = b.y, fly = true },
                        { c = mc, x1 = b.x, y1 = b.y, x2 = tx, y2 = ty } } }
    end
  end
  return plan
end

-- One or two lines for tooltips
function ns:RouteText(plan)
  if not plan or plan.kind == "unknown" then return { "|cffaaaaaaRoute unknown here (inside a dungeon?)|r" } end
  if plan.kind == "continent" then return { "|cffaaaaaaOn another continent: take a boat or zeppelin first.|r" } end
  local eta = ns.FormatETA(plan.time)
  if plan.kind == "fly" then
    return {
      string.format("|cff88ff88Fastest: ~%s|r", eta),
      string.format("Run %s to |cffffd100%s|r, fly to |cffffd100%s|r, then run %s.",
        ns.FormatDistance(plan.walkTo), plan.from.name, plan.to.name, ns.FormatDistance(plan.walkFrom)),
      string.format("|cffaaaaaaRunning straight there: ~%s|r", ns.FormatETA(plan.walkTime)),
    }
  end
  local lines = { string.format("|cff88ff88Run straight there: %s, ~%s|r", ns.FormatDistance(plan.dist), eta) }
  if ns:KnownFlightCount() == 0 then
    table.insert(lines, "|cffaaaaaaOpen a flight map once and Tjommie can suggest flights too.|r")
  end
  return lines
end

---------------------------------------------------------------------------
-- Blizzard's own waypoint for meeting points (if the client has it)
---------------------------------------------------------------------------
local ownWaypoint = false

ns:Listen("MEET_CHANGED", function()
  local meet = ns.meet
  if meet and ns.db.blizzWaypoint ~= false and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(meet.mapID, meet.x, meet.y))
    if ok then
      ownWaypoint = true
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
      end
    end
  elseif not meet and ownWaypoint then
    ownWaypoint = false
    if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
  end
end)
