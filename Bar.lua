-- Tjommie: Tracker bar
-- Sits under the minimap: your tjommie's class portrait with a direction arrow orbiting it,
-- name + level, "distance · heading · ETA", zone, and their XP bar.
-- Left-click: open window. Drag: move. Right-click: toggle TomTom arrow (if installed).

local _, ns = ...

local MEDIA = "Interface\\AddOns\\Tjommie\\media\\"
local ORBIT = 34
local bar

local function create()
  local f = CreateFrame("Button", "TjommieBar", UIParent, "BackdropTemplate")
  f:SetSize(270, 78)
  f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -18, -215)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.03, 0.03, 0.04, 0.85)
  f:SetBackdropBorderColor(0.72, 0.58, 0.29, 1)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.barPos = { point, relPoint, x, y }
  end)
  f:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns:ToggleTomTom() else ns:ToggleWindow() end
  end)

  -- Portrait + ring
  local holder = CreateFrame("Frame", nil, f)
  holder:SetSize(56, 56)
  holder:SetPoint("LEFT", 14, 0)
  f.ring = holder:CreateTexture(nil, "BACKGROUND")
  f.ring:SetTexture(MEDIA .. "dot")
  f.ring:SetSize(54, 54)
  f.ring:SetPoint("CENTER")
  f.ring:SetVertexColor(0.85, 0.68, 0.3)
  local inner = holder:CreateTexture(nil, "BORDER")
  inner:SetTexture(MEDIA .. "dot")
  inner:SetSize(49, 49)
  inner:SetPoint("CENTER")
  inner:SetVertexColor(0, 0, 0)
  f.portrait = holder:CreateTexture(nil, "ARTWORK")
  f.portrait:SetSize(44, 44)
  f.portrait:SetPoint("CENTER")

  f.arrow = holder:CreateTexture(nil, "OVERLAY")
  f.arrow:SetTexture(MEDIA .. "arrow")
  f.arrow:SetSize(22, 22)
  f.arrow:SetPoint("CENTER")
  f.holder = holder

  -- Text
  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 12, -2)
  f.name:SetJustifyH("LEFT")

  f.nav = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.nav:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
  f.nav:SetJustifyH("LEFT")

  f.zone = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.zone:SetPoint("TOPLEFT", f.nav, "BOTTOMLEFT", 0, -3)
  f.zone:SetWidth(170)
  f.zone:SetJustifyH("LEFT")
  f.zone:SetWordWrap(false)

  f.xp = CreateFrame("StatusBar", nil, f)
  f.xp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f.xp:SetStatusBarColor(0.58, 0.3, 1)
  f.xp:SetSize(170, 5)
  f.xp:SetPoint("TOPLEFT", f.zone, "BOTTOMLEFT", 0, -5)
  f.xp:SetMinMaxValues(0, 1)
  local xpbg = f.xp:CreateTexture(nil, "BACKGROUND")
  xpbg:SetAllPoints()
  xpbg:SetColorTexture(0.12, 0.12, 0.12, 0.9)

  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine("|cff33ff99Tjommie|r")
    local s = ns.buddy.stats or {}
    if s.xp and s.xpMax and s.xpMax > 0 then
      GameTooltip:AddLine(string.format("XP: %d / %d (%d%%)", s.xp, s.xpMax, math.floor(s.xp / s.xpMax * 100)), 1, 1, 1)
    end
    GameTooltip:AddLine("Left-click: open window", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move", 0.8, 0.8, 0.8)
    if TomTom then GameTooltip:AddLine("Right-click: TomTom arrow " .. (ns.db.tomtom and "|cff00ff00on|r" or "off"), 0.8, 0.8, 0.8) end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return f
end

local function update(nav)
  if not bar or not bar:IsShown() then return end
  local info = ns.buddy.info
  local pos = ns.buddy.pos

  ns.SetClassIcon(bar.portrait, info.class)
  bar.name:SetText(ns.BuddyNameColored() .. (info.level and ("  |cffffffffLv " .. info.level .. "|r") or ""))
  bar.nav:SetText(ns:NavText())

  local zone = ""
  if not ns.db.buddy then
    zone = "Type /tj set Name"
  elseif pos and pos.zone then
    zone = (pos.subzone and pos.subzone ~= "" and pos.subzone ~= pos.zone) and (pos.subzone .. ", " .. pos.zone) or pos.zone
    if nav.status == "offline" then zone = "Last seen: " .. zone end
  end
  bar.zone:SetText(zone)

  local s = ns.buddy.stats or {}
  if s.xp and s.xpMax and s.xpMax > 0 then
    bar.xp:SetValue(s.xp / s.xpMax)
    bar.xp:Show()
  else
    bar.xp:Hide()
  end

  local online = nav.status ~= "offline" and nav.status ~= "nobuddy"
  bar.portrait:SetDesaturated(not online)
  bar.portrait:SetAlpha(online and 1 or 0.6)

  if nav.rotation then
    local rot = nav.rotation
    bar.arrow:ClearAllPoints()
    bar.arrow:SetPoint("CENTER", bar.holder, "CENTER", -math.sin(rot) * ORBIT * 0.82, math.cos(rot) * ORBIT * 0.82)
    bar.arrow:SetRotation(rot)
    local r, g, b = ns.ClassColor(info.class)
    bar.arrow:SetVertexColor(r, g, b)
    bar.arrow:Show()
    bar.ring:SetVertexColor(0.85, 0.68, 0.3)
  else
    bar.arrow:Hide()
    bar.ring:SetVertexColor(0.35, 0.35, 0.35)
  end
end

ns:Listen("LOGIN", function()
  bar = create()
  local p = ns.db.barPos
  if p then bar:ClearAllPoints(); bar:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
  bar:SetShown(ns.db.compassShown)
end)

ns:Listen("NAV_UPDATE", update)
ns:Listen("COMPASS_TOGGLE", function() if bar then bar:SetShown(ns.db.compassShown) end end)
