-- Tjommie: Nav
-- TomTom-style navigation to your buddy: direction, compass heading, distance and ETA.
-- Everything that draws an arrow reads ns.nav, which is refreshed 10x per second.
-- Optional: mirror your buddy's position into TomTom's Crazy Arrow (/tj tomtom).

local _, ns = ...

ns.nav = { status = "nobuddy" }

local HEADINGS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
local samples = {}          -- recent { t, d } for closing-speed / ETA
local SAMPLE_WINDOW = 5     -- seconds
local smoothedSpeed = 0

function ns.FormatETA(sec)
  if not sec then return nil end
  sec = math.floor(sec + 0.5)
  if sec >= 3600 then return string.format("%dh %dm", math.floor(sec / 3600), math.floor((sec % 3600) / 60)) end
  if sec >= 60 then return string.format("%dm %02ds", math.floor(sec / 60), sec % 60) end
  return sec .. "s"
end

local function updateETA(dist)
  local now = GetTime()
  table.insert(samples, { t = now, d = dist })
  while #samples > 1 and now - samples[1].t > SAMPLE_WINDOW do table.remove(samples, 1) end
  local first = samples[1]
  local dt = now - first.t
  if dt < 1.5 then return nil end
  local speed = (first.d - dist) / dt                 -- yards/sec you're closing in
  smoothedSpeed = smoothedSpeed * 0.7 + speed * 0.3
  if smoothedSpeed > 1 then return dist / smoothedSpeed end
  return nil
end

local function resetETA()
  wipe(samples)
  smoothedSpeed = 0
end

function ns:UpdateNav()
  local nav = self.nav
  local pos = self.buddy and self.buddy.pos
  nav.dist, nav.eta, nav.rotation, nav.heading = nil, nil, nil, nil

  if not self.db.buddy then nav.status = "nobuddy"; resetETA(); return nav end
  if not pos or not self:IsBuddyOnline() then nav.status = "offline"; resetETA(); return nav end
  if pos.hidden then nav.status = "private"; resetETA(); return nav end

  local myMap, mx, my, mc, mwx, mwy = self.GetPlayerPos()
  if not myMap then nav.status = "hidden"; resetETA(); return nav end
  local dist = self.YardsBetween(mc, mwx, mwy, pos.c, pos.wx, pos.wy)
  if not dist then nav.status = "continent"; resetETA(); return nav end

  nav.status = "ok"
  nav.dist = dist
  nav.eta = updateETA(dist)

  local bx, by = self.WorldToMap(pos.c, pos.wx, pos.wy, myMap)
  local w, h = C_Map.GetMapWorldSize(myMap)
  if bx and w and w > 0 then
    local dx = (bx - mx) * w             -- east +
    local dy = (by - my) * h             -- south +
    local bearing = math.atan2(dx, -dy)  -- clockwise from north
    local deg = (math.deg(bearing) + 360) % 360
    nav.heading = HEADINGS[math.floor((deg + 22.5) / 45) % 8 + 1]
    local facing = GetPlayerFacing and GetPlayerFacing()
    if facing and not self.IsSecret(facing) then
      nav.rotation = -bearing - facing   -- texture rotation (counter-clockwise radians)
    end
  end
  return nav
end

-- One line summary: "1,240 yd · NE · 1m 25s"
function ns:NavText()
  local nav = self.nav
  if nav.status == "nobuddy" then return "No tjommie set" end
  if nav.status == "offline" then return "|cff999999Offline|r" end
  if nav.status == "hidden" then return "|cff999999Location hidden here|r" end
  if nav.status == "private" then return "|cff999999Location paused|r" end
  if nav.status == "continent" then return "|cffaaaaaaOther continent|r" end
  if nav.dist < 40 then return "|cff00ff00Right here!|r" end
  local parts = { BreakUpLargeNumbers and (BreakUpLargeNumbers(math.floor(nav.dist)) .. " yd") or self.FormatDistance(nav.dist) }
  if nav.heading then table.insert(parts, nav.heading) end
  table.insert(parts, nav.eta and ("|cff88ff88" .. ns.FormatETA(nav.eta) .. "|r") or "|cff777777--:--|r")
  return table.concat(parts, " |cff777777·|r ")
end

local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if acc < 0.1 then return end
  acc = 0
  if ns.db then
    ns:UpdateNav()
    ns:Fire("NAV_UPDATE", ns.nav)
  end
end)

---------------------------------------------------------------------------
-- TomTom bridge (optional)
---------------------------------------------------------------------------
local ttUid, ttKey

local function clearTomTom()
  if ttUid and TomTom and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, ttUid) end
  ttUid, ttKey = nil, nil
end

local function syncTomTom()
  if not (ns.db and ns.db.tomtom and TomTom and TomTom.AddWaypoint) then
    if ttUid then clearTomTom() end
    return
  end
  local pos = ns.buddy.pos
  if not pos or not ns:IsBuddyOnline() then clearTomTom(); return end
  local key = string.format("%d:%.3f:%.3f", pos.mapID, pos.x, pos.y)
  if key == ttKey then return end
  clearTomTom()
  local ok, uid = pcall(TomTom.AddWaypoint, TomTom, pos.mapID, pos.x, pos.y, {
    title = ns:BuddyShortName() .. " (Tjommie)", from = "Tjommie",
    persistent = false, minimap = false, world = false, crazy = true, silent = true,
    cleardistance = 0, arrivaldistance = 0,
  })
  if ok and uid then
    ttUid, ttKey = uid, key
  end
end

ns:Listen("LOGIN", function() C_Timer.NewTicker(2, syncTomTom) end)

function ns:ToggleTomTom()
  if not TomTom then self:Print("TomTom isn't installed/enabled.") return end
  self.db.tomtom = not self.db.tomtom
  if not self.db.tomtom then clearTomTom() end
  self:Print("TomTom arrow " .. (self.db.tomtom and "on: it now points at your tjommie." or "off."))
end
