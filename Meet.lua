-- Tjommie: Meet here
-- Drop a meeting point and both arrows switch to it (each with your own ETA).
--   * World map: click "Meet here", then click a spot on the map
--   * /tj meet         -> meet at my current position
--   * /tj meet clear   -> cancel
-- When you're both within 40 yd of each other near the spot, it clears itself: "Reunited!".
--
-- Wire: M~mapID~x~y~zone   (set)   MC   (clear)

local _, ns = ...

local ARRIVE_YARDS = 25

local function zoneName(mapID)
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or ""
end

-- Set the meeting point. fromBuddy = true when it came in over the wire.
function ns:SetMeet(mapID, x, y, fromBuddy, zone)
  mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
  if not (mapID and x and y) then return end
  local c, wx, wy = ns.MapToWorld(mapID, x, y)
  if not wx then
    if not fromBuddy then self:Print("Can't place a meeting point there.") end
    return
  end
  zone = (zone and zone ~= "") and zone or zoneName(mapID)
  self.meet = { mapID = mapID, x = x, y = y, c = c, wx = wx, wy = wy, zone = zone,
                by = fromBuddy and "buddy" or "me", t = time(), arrived = false }

  if fromBuddy then
    self:AddFeed(ns.BuddyNameColored() .. " wants to meet in |cff88ccff" .. zone .. "|r.", true, "Interface\\Icons\\INV_Misc_Map_01")
    self:Toast({ cat = "together", header = "MEET HERE", icon = "Interface\\Icons\\INV_Misc_Map_01", quality = 2,
      sound = "LEVELUP", body = ns.BuddyNameColored() .. " set a meeting point in " .. zone,
      sub = "Your arrow now points there. /tj meet clear to cancel." })
  else
    self:Send("M", mapID, string.format("%.4f", x), string.format("%.4f", y), zone)
    self:Chat("Meeting point set in " .. zone .. ". Your tjommie's arrow points there too.", "important")
  end
  self:Fire("MEET_CHANGED")
end

function ns:ClearMeet(fromBuddy, quiet)
  if not self.meet then return end
  self.meet = nil
  if not fromBuddy then self:Send("MC") end
  if not quiet then self:Chat("Meeting point cleared.", "important") end
  self:Fire("MEET_CHANGED")
end

function ns:MeetAtMe()
  local mapID, x, y = ns.GetPlayerPos()
  if not mapID then self:Print("Can't place a meeting point here (inside a dungeon?).") return end
  self:SetMeet(mapID, x, y, false)
end

ns.msgHandlers.M = function(mapID, x, y, zone) ns:SetMeet(mapID, x, y, true, zone) end
ns.msgHandlers.MC = function() ns:ClearMeet(true, true) end

---------------------------------------------------------------------------
-- Arrival: tell me when I'm there; clear it when we're together
---------------------------------------------------------------------------
ns:Listen("NAV_UPDATE", function(nav)
  local meet = ns.meet
  if not meet then return end
  if nav.target == "meet" and nav.status == "ok" and nav.dist and nav.dist < ARRIVE_YARDS and not meet.arrived then
    meet.arrived = true
    ns:Toast({ cat = "together", header = "MEET HERE", icon = "Interface\\Icons\\INV_Misc_Map_01", quality = 2,
      body = "You're at the meeting point.", sub = "Waiting for " .. ns:BuddyShortName() .. "..." })
  end
  if meet.arrived and nav.buddyDist and nav.buddyDist < 40 then
    local zone = meet.zone
    ns:ClearMeet(false, true)
    ns:AddFeed("Reunited with " .. ns.BuddyNameColored() .. " in |cff88ccff" .. (zone or "?") .. "|r!", false, "Interface\\Icons\\INV_Misc_Map_01")
    ns:Toast({ cat = "together", header = "REUNITED", icon = "Interface\\AddOns\\Tjommie\\media\\icon", quality = 3,
      sound = "LEVELUP", body = "You and " .. ns.BuddyNameColored() .. " made it!", sub = zone or "" })
    ns:Fire("REUNITED", zone)
  end
end)

-- A new tjommie means an old meeting point no longer applies
ns:Listen("BUDDY_CHANGED", function() ns:ClearMeet(true, true) end)

---------------------------------------------------------------------------
-- World map: "Meet here" button + click-to-place
---------------------------------------------------------------------------
local placing = false
local mapButton, catcher

local function cursorMapPosition()
  local sc = WorldMapFrame.ScrollContainer
  if sc and sc.GetNormalizedCursorPosition then
    local ok, x, y = pcall(sc.GetNormalizedCursorPosition, sc)
    if ok and x then return x, y end
  end
  local canvas = (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()) or (sc and sc.Child)
  if not canvas then return end
  local cx, cy = GetCursorPosition()
  local scale = canvas:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  local left, top = canvas:GetLeft(), canvas:GetTop()
  if not left then return end
  return (cx - left) / canvas:GetWidth(), (top - cy) / canvas:GetHeight()
end

local function setPlacing(on)
  placing = on
  if catcher then catcher:SetShown(on) end
  if mapButton then mapButton:SetText(on and "Click the map..." or "Meet here") end
end

local function initMap()
  if mapButton or not WorldMapFrame then return end
  local parent = WorldMapFrame.ScrollContainer or WorldMapFrame

  mapButton = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
  mapButton:SetSize(120, 22)
  mapButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
  mapButton:SetFrameStrata("HIGH")
  mapButton:SetText("Meet here")
  mapButton:SetScript("OnClick", function(_, btn)
    if not ns.db.buddy then ns:Print("Link up with a tjommie first.") return end
    if ns.meet and IsShiftKeyDown() then ns:ClearMeet() return end
    setPlacing(not placing)
  end)
  mapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff33ff99Tjommie|r: Meet here")
    GameTooltip:AddLine("Click, then click a spot on the map. Both your arrows will point there.", 1, 1, 1, true)
    if ns.meet then GameTooltip:AddLine("Shift-click to clear the current meeting point.", 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
  end)
  mapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Invisible layer that catches the next click on the map while placing
  catcher = CreateFrame("Button", nil, parent)
  catcher:SetAllPoints(parent)
  catcher:SetFrameStrata("HIGH")
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  catcher:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then setPlacing(false) return end
    local x, y = cursorMapPosition()
    local mapID = WorldMapFrame:GetMapID()
    setPlacing(false)
    if x and mapID and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
      ns:SetMeet(mapID, x, y, false)
    end
  end)
  catcher:Hide()
  WorldMapFrame:HookScript("OnHide", function() setPlacing(false) end)
end

ns:Listen("LOGIN", function()
  if WorldMapFrame then
    initMap()
  else
    ns:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then initMap() end end)
  end
end)
