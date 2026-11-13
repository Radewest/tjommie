-- Tjommie: Shortest Path Forever integration (optional)
-- If the Shortest Path Forever add-on is installed, Tjommie uses its public API
-- (ShortestPathForever.API, version 2) for real routes: walking paths, flights, boats,
-- zeppelins, portals and teleports, with proper times. It can also start a full guided
-- journey ("Take me there") to the meeting point or to your tjommie.
-- Without it, Tjommie falls back to its own simple estimate (Route.lua).
--
-- We only call its API; none of its (GPL) code is copied into Tjommie.

local _, ns = ...

local OWNER = "Tjommie"
local FOLLOW_EVERY = 8       -- seconds between re-routes while following a moving tjommie
local FOLLOW_MOVED = 60      -- yards the tjommie must move before we re-route
local REUNITE_YARDS = 40

-- The API table, or nil when Shortest Path Forever isn't installed / too old
function ns.SPF()
  local api = _G.ShortestPathForever and _G.ShortestPathForever.API
  if type(api) == "table" and (api.version or 0) >= 2 and api.EstimateDetail and api.Navigate then
    return api
  end
end

---------------------------------------------------------------------------
-- Targets: "meet" (meeting point) or "buddy" (the tjommie's last position)
---------------------------------------------------------------------------
function ns:TargetPlace(target)
  if target == "meet" and self.meet then
    return self.meet.mapID, self.meet.x, self.meet.y, "Meet " .. self:BuddyShortName()
  end
  local pos = self.buddy and self.buddy.pos
  if target == "buddy" and pos and pos.mapID and not pos.hidden then
    return pos.mapID, pos.x, pos.y, self:BuddyShortName()
  end
end

---------------------------------------------------------------------------
-- Route estimates through Shortest Path Forever
---------------------------------------------------------------------------
local MODE_TEXT = {
  walk = "Walk", flight = "Fly", boat = "Boat", zeppelin = "Zeppelin",
  portal = "Portal", teleport = "Teleport", passage = "Take", tram = "Tram", lift = "Lift",
}

-- Returns a plan { kind = "spf", seconds, legs = { {mode, to, seconds, wait} } } or nil, reason
function ns:SPFPlan(target)
  local api = ns.SPF()
  if not api then return nil, "missing" end
  local tMap, tx, ty = self:TargetPlace(target)
  local mMap, mx, my = ns.GetPlayerPos()
  if not (tMap and mMap) then return nil, "unknown" end
  local ok, detail, reason = pcall(api.EstimateDetail, mMap, mx, my, tMap, tx, ty)
  if not ok then return nil, "error" end
  if not detail then return nil, reason end
  return { kind = "spf", seconds = detail.seconds, legs = detail.legs or {} }
end

function ns:SPFRouteText(plan, reason)
  if not plan then
    local why = {
      combat = "Shortest Path: route available after combat.",
      loading = "Shortest Path is still loading its maps...",
      unreachable = "Shortest Path: no route found with your known flights and boats.",
    }
    return { "|cffaaaaaa" .. (why[reason] or "Shortest Path couldn't plan a route here.") .. "|r" }
  end
  local lines = { string.format("|cff88ff88Fastest (Shortest Path): ~%s|r", ns.FormatETA(plan.seconds)) }
  for i, leg in ipairs(plan.legs) do
    if i > 6 then table.insert(lines, "|cffaaaaaa...|r") break end
    local verb = MODE_TEXT[leg.mode] or (leg.mode and (leg.mode:sub(1, 1):upper() .. leg.mode:sub(2))) or "Go"
    local wait = leg.wait and (" |cffaaaaaa(wait " .. ns.FormatETA(leg.wait) .. ")|r") or ""
    table.insert(lines, string.format("%d. %s to |cffffd100%s|r  |cffaaaaaa%s|r%s",
      i, verb, tostring(leg.to or "?"), ns.FormatETA(leg.seconds or 0), wait))
  end
  table.insert(lines, "|cff33ff99Click the pin: take me there|r")
  return lines
end

---------------------------------------------------------------------------
-- Guided journeys ("Take me there")
---------------------------------------------------------------------------
ns.guiding = nil  -- { target = "meet"|"buddy", lastX, lastY, lastMap, at }

function ns:IsGuiding()
  local api = ns.SPF()
  if not api or not self.guiding then return false end
  local ok, stop = pcall(api.CurrentStop, OWNER)
  if ok and stop then return true end
  self.guiding = nil  -- journey ended (arrived, cancelled, or replaced by another add-on)
  return false
end

function ns:GuideTo(target)
  local api = ns.SPF()
  if not api then
    self:Print("Install |cffffd100Shortest Path Forever|r for turn-by-turn routes. Tjommie's own arrow still points the way.")
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    self:Print("Can't start a route in combat. Try again after the fight.")
    return false
  end
  local map, x, y, title = self:TargetPlace(target)
  if not map then
    self:Print(target == "meet" and "No meeting point set." or (self:BuddyShortName() .. "'s location isn't known right now."))
    return false
  end
  local ok, started = pcall(api.Navigate, OWNER, map, x, y, title)
  if ok and started then
    self.guiding = { target = target, lastMap = map, lastX = x, lastY = y, at = GetTime() }
    self:Chat("Shortest Path is guiding you to " .. title .. ".", "important")
    self:Fire("GUIDE_CHANGED")
    return true
  end
  self:Print("Shortest Path couldn't start that route" .. ((not ok) and " (error)" or "") .. ".")
  return false
end

function ns:StopGuiding(quiet)
  local api = ns.SPF()
  if self.guiding and api then pcall(api.Cancel, OWNER) end
  local was = self.guiding
  self.guiding = nil
  if was then
    if not quiet then self:Chat("Stopped guiding.", "important") end
    self:Fire("GUIDE_CHANGED")
  end
end

function ns:ToggleGuide(target)
  if self:IsGuiding() and self.guiding.target == target then
    self:StopGuiding()
  else
    self:GuideTo(target)
  end
end

-- Follow a moving tjommie: re-route when they've moved a fair bit; stop when we meet
ns:Listen("LOGIN", function()
  C_Timer.NewTicker(FOLLOW_EVERY, function()
    local g = ns.guiding
    if not g or not ns:IsGuiding() then return end
    if g.target == "buddy" then
      local d = ns.nav and ns.nav.buddyDist
      if d and d < REUNITE_YARDS then
        ns:StopGuiding(true)
        ns:Chat("You found " .. ns:BuddyShortName() .. "! Guidance stopped.", "important")
        return
      end
      local map, x, y = ns:TargetPlace("buddy")
      if map and (map ~= g.lastMap or ns.MapDistanceYards(map, x, y, g.lastX, g.lastY) > FOLLOW_MOVED) then
        if not (InCombatLockdown and InCombatLockdown()) then ns:GuideTo("buddy") end
      end
    end
  end)
end)

-- Rough yards between two points on the same map
function ns.MapDistanceYards(map, x1, y1, x2, y2)
  local w, h = C_Map.GetMapWorldSize(map)
  if not w or w == 0 then return math.huge end
  local dx, dy = (x2 - x1) * w, (y2 - y1) * h
  return math.sqrt(dx * dx + dy * dy)
end

-- Meeting points: optionally start guidance automatically; stop when it's cleared or we reunite
ns:Listen("MEET_CHANGED", function()
  if ns.meet then
    if ns.db.autoGuide and ns.SPF() then
      C_Timer.After(0.5, function() if ns.meet then ns:GuideTo("meet") end end)
    end
  elseif ns.guiding and ns.guiding.target == "meet" then
    ns:StopGuiding(true)
  end
end)
ns:Listen("REUNITED", function() ns:StopGuiding(true) end)
ns:Listen("BUDDY_CHANGED", function() ns:StopGuiding(true) end)
