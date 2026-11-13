-- Tjommie: Settings
-- One panel builder, used in two places: the "Settings" tab in the Tjommie window and
-- Blizzard's Options > AddOns > Tjommie. Every control reads/writes TjommieDB and fires
-- SETTINGS_CHANGED so the bar, map and window update straight away.

local _, ns = ...

local CHAT_LEVELS = { "off", "important", "all" }
local CHAT_LABELS = { off = "Off", important = "Important only", all = "Everything" }

local function changed() ns:Fire("SETTINGS_CHANGED") end

---------------------------------------------------------------------------
-- Control helpers (plain frames, so they work regardless of template changes)
---------------------------------------------------------------------------
local function header(parent, x, y, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.55, 0.43, 0.2, 0.6)
  line:SetSize(250, 1)
  line:SetPoint("TOPLEFT", x, y - 15)
end

local function checkbox(panel, x, y, label, get, set, tip)
  local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb:SetPoint("TOPLEFT", x, y)
  local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  fs:SetText(label)
  cb:SetScript("OnClick", function(self)
    set(self:GetChecked() and true or false)
    changed()
  end)
  if tip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(label)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  table.insert(panel.refreshers, function() cb:SetChecked(get() and true or false) end)
  return cb
end

local function slider(panel, x, y, label, minV, maxV, step, get, set, fmt)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  title:SetPoint("TOPLEFT", x + 4, y)
  local s = CreateFrame("Slider", nil, panel, "BackdropTemplate")
  s:SetOrientation("HORIZONTAL")
  s:SetSize(200, 16)
  s:SetPoint("TOPLEFT", x + 4, y - 14)
  s:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  local function show(v) title:SetText(label .. ":  |cffffffff" .. (fmt and fmt(v) or v) .. "|r") end
  s:SetScript("OnValueChanged", function(_, v, userInput)
    v = math.floor(v / step + 0.5) * step
    show(v)
    if userInput then set(v); changed() end
  end)
  table.insert(panel.refreshers, function() local v = get(); s:SetValue(v); show(v) end)
  return s
end

local function button(panel, x, y, w, label, onClick)
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetPoint("TOPLEFT", x, y)
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

local function percent(v) return math.floor(v * 100 + 0.5) .. "%" end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
function ns:BuildSettingsPanel(panel)
  panel.refreshers = {}
  local db = function() return ns.db end
  local L, R = 4, 290

  -- Messages ---------------------------------------------------------------
  header(panel, L, -4, "Messages")
  local chatLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  chatLabel:SetPoint("TOPLEFT", L + 4, -28)
  chatLabel:SetText("Chat messages:")
  local chatBtn = button(panel, L + 100, -23, 140, "", function(self)
    local cur = db().chat or "important"
    local idx = 1
    for i, v in ipairs(CHAT_LEVELS) do if v == cur then idx = i end end
    db().chat = CHAT_LEVELS[idx % #CHAT_LEVELS + 1]
    self:SetText(CHAT_LABELS[db().chat])
    changed()
  end)
  chatBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Chat messages")
    GameTooltip:AddLine("Off: nothing in chat.\nImportant only: bugs, requests, warnings.\nEverything: also echo every pop-up.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  chatBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  table.insert(panel.refreshers, function() chatBtn:SetText(CHAT_LABELS[db().chat or "important"]) end)

  checkbox(panel, L, -50, "Pop-ups", function() return db().toasts end, function(v) db().toasts = v end)
  local popupTypes = {
    { "level", "Level-ups" }, { "death", "Deaths" }, { "loot", "Loot, wishlist & upgrades" },
    { "fun", "Fun stuff (drinks, Gees Vuur)" }, { "online", "Tjommie comes online" },
    { "together", "Meet-ups, badges & dungeons" },
  }
  for i, p in ipairs(popupTypes) do
    checkbox(panel, L + 18, -50 - i * 22, p[2],
      function() return db().popups[p[1]] ~= false end,
      function(v) db().popups[p[1]] = v end)
  end
  checkbox(panel, L, -50 - 7 * 22, "Sounds", function() return db().sound end, function(v) db().sound = v end)

  -- Privacy ----------------------------------------------------------------
  header(panel, L, -230, "Privacy")
  checkbox(panel, L, -250, "Share my position", function() return db().sharePosition end,
    function(v) db().sharePosition = v end, "Untick to pause. Your tjommie sees \"Location paused\" but still gets your feed and stats.")
  checkbox(panel, L, -272, "Share my gold", function() return not db().hideGold end,
    function(v) db().hideGold = not v; ns:SendStats() end)

  -- Map --------------------------------------------------------------------
  header(panel, L, -300, "Map")
  checkbox(panel, L, -320, "Show my tjommie's trail", function() return db().showBuddyTrail ~= false end,
    function(v) db().showBuddyTrail = v end)
  checkbox(panel, L, -342, "Show my own trail", function() return db().showMyTrail end,
    function(v) db().showMyTrail = v end)
  slider(panel, L, -366, "Trail length", 100, 1500, 100,
    function() return db().trailLength or 1500 end, function(v) db().trailLength = v end,
    function(v) return v .. " points" end)

  -- Tracker bar ------------------------------------------------------------
  header(panel, R, -4, "Tracker bar")
  checkbox(panel, R, -24, "Show tracker bar", function() return db().compassShown end,
    function(v) db().compassShown = v end)
  checkbox(panel, R, -46, "Lock position", function() return db().barLocked end,
    function(v) db().barLocked = v end)
  checkbox(panel, R, -68, "Hide in dungeons & raids", function() return db().barHideInstance end,
    function(v) db().barHideInstance = v end)
  checkbox(panel, R, -90, "Fade in combat", function() return db().barCombatFade end,
    function(v) db().barCombatFade = v end)
  slider(panel, R, -120, "Size", 0.6, 1.6, 0.05,
    function() return db().barScale or 1 end, function(v) db().barScale = v end, percent)
  slider(panel, R, -160, "Opacity", 0.3, 1, 0.05,
    function() return db().barAlpha or 1 end, function(v) db().barAlpha = v end, percent)

  -- Window -----------------------------------------------------------------
  header(panel, R, -204, "Window")
  slider(panel, R, -226, "Window size", 0.7, 1.4, 0.05,
    function() return db().windowScale or 1 end, function(v) db().windowScale = v end, percent)
  checkbox(panel, R, -262, "Show minimap button", function() return not db().minimapHidden end,
    function(v) db().minimapHidden = not v; ns:Fire("MINIMAP_TOGGLE") end)
  checkbox(panel, R, -284, "Always show route to meet-up", function() return db().showMeetRoute end,
    function(v) db().showMeetRoute = v end, "Otherwise the route shows when you hover over a pin on the map.")
  checkbox(panel, R, -306, "Blizzard waypoint for meet-ups", function() return db().blizzWaypoint ~= false end,
    function(v) db().blizzWaypoint = v end, "Also places the game's own map pin and on-screen marker on the meeting point (if your client has it).")

  -- Help -------------------------------------------------------------------
  checkbox(panel, R, -328, "Auto-guide to meet-ups (Shortest Path)", function() return db().autoGuide end,
    function(v) db().autoGuide = v end, "If you have Shortest Path Forever installed, start turn-by-turn guidance whenever a meeting point is set.")
  header(panel, R, -356, "Help")
  button(panel, R, -378, 80, "Welcome", function() ns:ShowWelcome() end)
  button(panel, R + 84, -378, 80, "Bug log", function() ns:ShowBugs() end)
  button(panel, R + 168, -378, 80, "Demo", function() ns:ToggleDemo() end)
  button(panel, R + 252, -378, 90, "Reset positions", function()
    db().barPos, db().windowPos, db().windowSize, db().minimapAngle = nil, nil, nil, 200
    ns:ResetMeetButton()
    ns:Print("Positions reset. Type /reload to apply.")
  end)

  function panel:Refresh()
    for _, fn in ipairs(self.refreshers) do fn() end
  end
  panel:HookScript("OnShow", function(self) self:Refresh() end)
  if panel:IsShown() then panel:Refresh() end
end

---------------------------------------------------------------------------
-- Blizzard Options > AddOns > Tjommie
---------------------------------------------------------------------------
ns:Listen("LOGIN", function()
  local frame = CreateFrame("Frame")
  frame.name = "Tjommie"
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("|cff33ff99Tjommie|r settings")
  local inner = CreateFrame("Frame", nil, frame)
  inner:SetPoint("TOPLEFT", 12, -48)
  inner:SetSize(580, 400)
  ns:BuildSettingsPanel(inner)
  frame:HookScript("OnShow", function() inner:Refresh() end)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, frame, "Tjommie")
    if ok and category then
      pcall(Settings.RegisterAddOnCategory, category)
      ns.settingsCategory = category
    end
  elseif InterfaceOptions_AddCategory then
    pcall(InterfaceOptions_AddCategory, frame)
  end
end)
