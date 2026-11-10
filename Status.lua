-- Tjommie: Status at a glance
-- Each side works out one short status ("On a flight to Stormwind", "In The Deadmines", "AFK",
-- "At the Gees Vuur", ...) and sends it whenever it changes. Shown on the tracker bar, the
-- Overview card and the map pin tooltip.
--
-- Wire: ST~code~extra   (codes below; extra = destination / instance / zone)

local _, ns = ...

-- Highest priority first: only the most important one is shown
local function computeStatus()
  if UnitIsDeadOrGhost("player") then
    return UnitIsGhost and UnitIsGhost("player") and "GHOST" or "DEAD", ""
  end
  if UnitAffectingCombat("player") then return "COMBAT", "" end
  if IsInInstance then
    local inInstance, kind = IsInInstance()
    if inInstance and (kind == "party" or kind == "raid") then
      local name = GetInstanceInfo and GetInstanceInfo()
      return "INSTANCE", name or ""
    end
  end
  if UnitOnTaxi and UnitOnTaxi("player") then return "TAXI", ns.taxiDestination or "" end
  if UnitIsAFK and UnitIsAFK("player") then return "AFK", "" end
  if ns.IsAtFire and ns:IsAtFire() then return "FIRE", "" end
  if ns.IsDancing and ns:IsDancing() then return "DANCE", "" end
  if IsResting and IsResting() then
    local sub = GetSubZoneText and GetSubZoneText() or ""
    return "REST", (sub ~= "" and sub) or (GetZoneText() or "")
  end
  return "", ""
end
ns.ComputeStatus = computeStatus

local TEXT = {
  DEAD     = { "|cffff5555Dead|r" },
  GHOST    = { "|cffaaaaaaRunning back as a ghost|r" },
  COMBAT   = { "|cffff8800In combat|r" },
  INSTANCE = { "In %s", "In a dungeon" },
  TAXI     = { "On a flight to %s", "On a flight" },
  AFK      = { "|cffaaaaaaAFK|r" },
  FIRE     = { "|cffff8800At the Gees Vuur|r" },
  DANCE    = { "Dancing" },
  REST     = { "Resting in %s", "Resting" },
}

-- Human text for a status (code, extra); nil when there's nothing worth showing
function ns.StatusText(code, extra)
  local t = code and TEXT[code]
  if not t then return nil end
  if t[1]:find("%%s") then
    if extra and extra ~= "" then return t[1]:format(extra) end
    return t[2]
  end
  return t[1]
end

function ns:BuddyStatusText()
  local st = self.buddy.status
  if not st or not self:IsBuddyOnline() then return nil end
  return ns.StatusText(st.code, st.extra)
end

-- Remember where a flight is going (hook the flight-master click)
if type(TakeTaxiNode) == "function" then
  hooksecurefunc("TakeTaxiNode", function(slot)
    local name = TaxiNodeName and TaxiNodeName(slot)
    if name then ns.taxiDestination = (name:match("^([^,]+)") or name) end
  end)
end

---------------------------------------------------------------------------
-- Send on change (checked every second), and on sync
---------------------------------------------------------------------------
local lastCode, lastExtra

local function sendStatus(force)
  local code, extra = computeStatus()
  ns.myStatus = { code = code, extra = extra }
  if force or code ~= lastCode or extra ~= lastExtra then
    lastCode, lastExtra = code, extra
    ns:Send("ST", code, extra)
    ns:Fire("MY_STATUS", code, extra)
  end
end

ns:Listen("LOGIN", function()
  C_Timer.NewTicker(1, function() sendStatus(false) end)
end)
ns:Listen("SYNC_REQUEST", function() sendStatus(true) end)

ns.msgHandlers.ST = function(code, extra)
  local prev = ns.buddy.status and ns.buddy.status.code
  ns.buddy.status = { code = code or "", extra = extra or "", t = time() }
  ns:Fire("BUDDY_STATUS", code, extra, prev)
end
