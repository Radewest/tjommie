-- Tjommie: Welcome guide
-- Shown once on first install (and any time with /tj welcome or the Settings "Welcome guide" button).

local _, ns = ...

local frame

local STEPS = {
  { "Link up", "Right-click your friend (name in chat, friends list or portrait) and choose |cff33ff99Add as Tjommie|r. Or click |cffffff00Choose tjommie|r in the window. They tap Accept, done. They need Tjommie too!" },
  { "Follow the arrow", "The tracker bar under your minimap points to your tjommie, with distance, compass heading and how long until you reach them. Drag it anywhere." },
  { "Help each other", "Pop-ups tell you when one of you loots, levels, dies or finds an upgrade for the other. Check the Upgrades and Wishlist tabs." },
  { "Make it yours", "Open |cffffff00/tj settings|r to change pop-ups, chat messages, the bar's size and privacy. Try |cffffff00/tj demo|r to see it all with a fake tjommie." },
}

local function create()
  local f = CreateFrame("Frame", "TjommieWelcome", UIParent, "BackdropTemplate")
  f:SetSize(460, 380)
  f:SetPoint("CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:SetBackdropColor(0.03, 0.03, 0.04, 0.97)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  table.insert(UISpecialFrames, "TjommieWelcome")
  f:SetScript("OnHide", function() ns.db.welcomed = true end)

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\AddOns\\Tjommie\\media\\icon")
  icon:SetSize(48, 48)
  icon:SetPoint("TOPLEFT", 18, -16)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4)
  title:SetText("Howzit! Welcome to |cff33ff99Tjommie|r")
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetText("Level apart, stay together. Four quick things:")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local y = -84
  for i, step in ipairs(STEPS) do
    local num = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    num:SetPoint("TOPLEFT", 22, y)
    num:SetText(i .. ".")
    local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", 48, y)
    head:SetText(step[1])
    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -3)
    body:SetWidth(380)
    body:SetJustifyH("LEFT")
    body:SetText(step[2])
    y = y - 62
  end

  local function btn(label, x, onClick)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(130, 24)
    b:SetPoint("BOTTOMLEFT", x, 16)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
  end
  btn("Choose tjommie", 22, function() f:Hide(); ns:ShowPicker() end)
  btn("Try the demo", 164, function() f:Hide(); if not ns.demoActive then ns:ToggleDemo() end end)
  btn("Got it, lekker", 306, function() f:Hide() end)
  return f
end

function ns:ShowWelcome()
  frame = frame or create()
  frame:Show()
end

ns:Listen("LOGIN", function()
  if not ns.db.welcomed then
    C_Timer.After(6, function() ns:ShowWelcome() end)
  end
end)
