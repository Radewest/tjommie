-- Tjommie: Minimap button
-- Left-click: window. Right-click: show/hide tracker bar. Drag: move around the minimap.

local _, ns = ...

local button

local function updatePosition()
  local angle = math.rad(ns.db.minimapAngle or 200)
  local radius = (Minimap:GetWidth() / 2) + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function create()
  local b = CreateFrame("Button", "TjommieMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(24, 24)
  bg:SetPoint("CENTER")

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\AddOns\\Tjommie\\media\\icon")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  b:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
      ns.db.compassShown = not ns.db.compassShown
      ns:Fire("COMPASS_TOGGLE")
    else
      ns:ToggleWindow()
    end
  end)

  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      ns.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
      updatePosition()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff33ff99Tjommie|r")
    GameTooltip:AddLine(ns:NavText(), 1, 1, 1)
    GameTooltip:AddLine("Left-click: open window", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: show/hide tracker bar", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

ns:Listen("LOGIN", function()
  if not Minimap then return end
  button = create()
  updatePosition()
  button:SetShown(not ns.db.minimapHidden)
end)

ns:Listen("MINIMAP_TOGGLE", function()
  if button then button:SetShown(not ns.db.minimapHidden) end
end)
