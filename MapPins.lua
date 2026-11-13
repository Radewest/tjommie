-- Tjommie: World map pins + breadcrumb trail
-- Draws your buddy's live position and the route they've taken on whatever map you have open
-- (zone or continent). Optionally draws your own trail too (/tj trail mine).

local _, ns = ...

local MEDIA = "Interface\\AddOns\\Tjommie\\media\\"
local MAX_DRAWN = 700       -- cap dots per trail per refresh (older points get thinned)
local DOT_SIZE = 7
local PIN_SIZE = 18

local overlay, canvas, buddyPin, meetPin
local dotPool = {}
local usedDots = 0
local lastScale

local function getDot()
  usedDots = usedDots + 1
  local dot = dotPool[usedDots]
  if not dot then
    dot = overlay:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(MEDIA .. "dot")
    dotPool[usedDots] = dot
  end
  dot:Show()
  return dot
end

local function releaseDots()
  for i = 1, #dotPool do dotPool[i]:Hide() end
  usedDots = 0
end

local function canvasScale()
  return (WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()) or 1
end

local function place(region, x, y, size)
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local s = size / canvasScale()
  region:SetSize(s, s)
  region:ClearAllPoints()
  region:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
end

local function drawTrail(trail, mapID, r, g, b)
  local n = #trail
  if n == 0 then return end
  local step = math.max(1, math.ceil(n / MAX_DRAWN))
  for i = 1, n, step do
    local p = trail[i]
    local x, y = ns.WorldToMap(p.c, p.x, p.y, mapID)
    if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
      local dot = getDot()
      -- fade older points
      local age = (n - i) / n
      dot:SetVertexColor(r, g, b, 0.95 - age * 0.6)
      place(dot, x, y, DOT_SIZE)
    end
  end
end

-- Dotted line(s) for the planned route: white = run, gold = flight
local function routeTargetCoords(target)
  if target == "meet" and ns.meet then return ns.meet.c, ns.meet.wx, ns.meet.wy end
  local pos = ns.buddy and ns.buddy.pos
  if target == "buddy" and pos and pos.wx then return pos.c, pos.wx, pos.wy end
end

local function drawRoute(target, mapID)
  local c, x, y = routeTargetCoords(target)
  if not c then return end
  local plan = ns:PlanRoute(c, x, y)
  for _, leg in ipairs(plan.legs or {}) do
    local len = math.sqrt((leg.x2 - leg.x1) ^ 2 + (leg.y2 - leg.y1) ^ 2)
    local steps = math.min(80, math.max(2, math.floor(len / 40)))
    for i = 0, steps do
      local f = i / steps
      local mx, my = ns.WorldToMap(leg.c, leg.x1 + (leg.x2 - leg.x1) * f, leg.y1 + (leg.y2 - leg.y1) * f, mapID)
      if mx and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
        local dot = getDot()
        if leg.fly then dot:SetVertexColor(1, 0.82, 0, 0.95) else dot:SetVertexColor(1, 1, 1, 0.9) end
        place(dot, mx, my, leg.fly and 6 or 5)
      end
    end
  end
end

function ns:SetRouteHover(target)
  if ns.routeHover == target then return end
  ns.routeHover = target
  ns:RefreshMap()
end

function ns:AddRouteTooltip(target)
  local c, x, y = routeTargetCoords(target)
  if not c then return end
  GameTooltip:AddLine(" ")
  for _, line in ipairs(ns:RouteText(ns:PlanRoute(c, x, y))) do GameTooltip:AddLine(line, 1, 1, 1, true) end
  ns:SetRouteHover(target)
end

function ns:RefreshMap()
  if not overlay or not WorldMapFrame:IsShown() then return end
  local mapID = WorldMapFrame:GetMapID()
  releaseDots()
  -- Pins are only hidden at the end if they're not placed again, so a pin under the mouse
  -- doesn't flicker (hiding it would fire OnLeave and hide the route tooltip)
  local showBuddy, showMeet = false, false
  if not mapID then buddyPin:Hide(); if meetPin then meetPin:Hide() end; return end

  local br, bg, bb = ns.ClassColor(ns.buddy.info.class)
  if ns.db.showBuddyTrail ~= false then drawTrail(ns.buddy.trail, mapID, br, bg, bb) end
  if ns.db.showMyTrail then
    local _, myClass = UnitClass("player")
    local r, g, b = ns.ClassColor(myClass)
    drawTrail(ns.cdb.myTrail, mapID, r * 0.6, g * 0.6, b * 0.6)
  end

  local pos = ns.buddy.pos
  if pos and pos.wx then
    local x, y = ns.WorldToMap(pos.c, pos.wx, pos.wy, mapID)
    if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
      buddyPin.icon:SetVertexColor(br, bg, bb, ns:IsBuddyOnline() and 1 or 0.4)
      buddyPin.glow:SetVertexColor(br, bg, bb, 0.5)
      buddyPin.glow:SetShown(ns:IsBuddyOnline())
      place(buddyPin, x, y, PIN_SIZE)
      buddyPin:Show()
      showBuddy = true
    end
  end
  -- Route (Route.lua): shown while hovering a pin, or always for a meet-up if that setting is on
  local routeTarget = ns.routeHover or ((ns.meet and ns.db.showMeetRoute) and "meet" or nil)
  if routeTarget then drawRoute(routeTarget, mapID) end

  -- Meeting point (Meet.lua)
  local meet = ns.meet
  if meet and meet.wx and meetPin then
    local x, y = ns.WorldToMap(meet.c, meet.wx, meet.wy, mapID)
    if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
      place(meetPin, x, y, 24)
      meetPin:Show()
      showMeet = true
    end
  end
  if not showBuddy then buddyPin:Hide() end
  if meetPin and not showMeet then meetPin:Hide() end
  lastScale = canvasScale()
end

local function init()
  if overlay or not WorldMapFrame then return end
  canvas = (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()) or WorldMapFrame.ScrollContainer.Child

  overlay = CreateFrame("Frame", nil, canvas)
  overlay:SetAllPoints(canvas)
  overlay:SetFrameLevel(canvas:GetFrameLevel() + 2000)

  buddyPin = CreateFrame("Frame", nil, overlay)
  buddyPin:SetFrameLevel(overlay:GetFrameLevel() + 5)
  buddyPin:EnableMouse(true)
  buddyPin.glow = buddyPin:CreateTexture(nil, "BACKGROUND")
  buddyPin.glow:SetTexture(MEDIA .. "dot")
  buddyPin.glow:SetPoint("TOPLEFT", -9, 9)
  buddyPin.glow:SetPoint("BOTTOMRIGHT", 9, -9)
  buddyPin.ring = buddyPin:CreateTexture(nil, "ARTWORK")
  buddyPin.ring:SetTexture(MEDIA .. "dot")
  buddyPin.ring:SetVertexColor(0, 0, 0, 0.9)
  buddyPin.ring:SetAllPoints()
  buddyPin.icon = buddyPin:CreateTexture(nil, "OVERLAY")
  buddyPin.icon:SetTexture(MEDIA .. "dot")
  buddyPin.icon:SetPoint("TOPLEFT", 2, -2)
  buddyPin.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  buddyPin:SetScript("OnEnter", function(self)
    local pos = ns.buddy.pos or {}
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.BuddyNameColored())
    if ns.buddy.info.level then GameTooltip:AddLine("Level " .. ns.buddy.info.level, 1, 1, 1) end
    GameTooltip:AddLine((pos.subzone and pos.subzone ~= "" and (pos.subzone .. ", ") or "") .. (pos.zone or ""), 0.6, 0.8, 1)
    local status = ns.BuddyStatusText and ns:BuddyStatusText()
    if status then GameTooltip:AddLine(status, 1, 1, 1) end
    if not ns:IsBuddyOnline() then GameTooltip:AddLine("Offline - last known position", 0.6, 0.6, 0.6) end
    ns:AddRouteTooltip("buddy")
    GameTooltip:Show()
  end)
  buddyPin:SetScript("OnLeave", function() GameTooltip:Hide(); ns:SetRouteHover(nil) end)
  buddyPin:Hide()

  meetPin = CreateFrame("Frame", nil, overlay)
  meetPin:SetFrameLevel(overlay:GetFrameLevel() + 6)
  meetPin:EnableMouse(true)
  local ring = meetPin:CreateTexture(nil, "ARTWORK")
  ring:SetTexture(MEDIA .. "dot")
  ring:SetAllPoints()
  ring:SetVertexColor(0, 0, 0, 0.9)
  local star = meetPin:CreateTexture(nil, "OVERLAY")
  star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
  star:SetPoint("TOPLEFT", 2, -2)
  star:SetPoint("BOTTOMRIGHT", -2, 2)
  meetPin:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("|cffffd100Meeting point|r")
    if ns.meet then
      GameTooltip:AddLine(ns.meet.zone or "", 0.6, 0.8, 1)
      GameTooltip:AddLine("Set by " .. (ns.meet.by == "me" and "you" or ns:BuddyShortName()), 1, 1, 1)
    end
    GameTooltip:AddLine("Right-click or Shift-click to clear it.", 0.7, 0.7, 0.7)
    ns:AddRouteTooltip("meet")
    GameTooltip:Show()
  end)
  meetPin:SetScript("OnLeave", function() GameTooltip:Hide(); ns:SetRouteHover(nil) end)
  meetPin:SetScript("OnMouseUp", function(_, btn)
    if btn == "RightButton" or IsShiftKeyDown() then ns:ClearMeet() end
  end)
  meetPin:Hide()

  hooksecurefunc(WorldMapFrame, "OnMapChanged", function() ns:RefreshMap() end)
  WorldMapFrame:HookScript("OnShow", function() ns:RefreshMap() end)

  -- Keep dot sizes constant while zooming
  overlay:SetScript("OnUpdate", function()
    if buddyPin:IsShown() and buddyPin.glow:IsShown() then
      buddyPin.glow:SetAlpha(0.35 + 0.35 * math.sin(GetTime() * 3))
    end
    if lastScale and math.abs(canvasScale() - lastScale) > 0.01 then ns:RefreshMap() end
  end)
end

ns:Listen("LOGIN", function()
  if WorldMapFrame then
    init()
  else
    ns:On("ADDON_LOADED", function(name)
      if name == "Blizzard_WorldMap" then init() end
    end)
  end
end)

-- Throttled refreshes from data changes
local pending = false
local function queueRefresh()
  if pending then return end
  pending = true
  C_Timer.After(0.5, function()
    pending = false
    ns:RefreshMap()
  end)
end
ns:Listen("BUDDY_POS", queueRefresh)
ns:Listen("TRAIL_CHANGED", queueRefresh)
ns:Listen("BUDDY_CHANGED", queueRefresh)
ns:Listen("SETTINGS_CHANGED", queueRefresh)
ns:Listen("MEET_CHANGED", queueRefresh)
