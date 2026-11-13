-- Tjommie: Main window
-- Blizzard-style frame with the Tjommie portrait and bottom tabs:
-- Overview (you vs them, recent activity, head-to-head) / Feed / Stats / Wishlist.

local _, ns = ...

local WIDTH, HEIGHT = 650, 470
local MEDIA = "Interface\\AddOns\\Tjommie\\media\\"
local win
local tabs, pages = {}, {}

---------------------------------------------------------------------------
-- Small widget helpers
---------------------------------------------------------------------------
local function sectionHeader(parent, text, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 4, y)
  fs:SetText(text)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.55, 0.43, 0.2, 0.6)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 2, y - 16)
  line:SetPoint("TOPRIGHT", -2, y - 16)
  return fs
end

local function xpBar(parent, width)
  local sb = CreateFrame("StatusBar", nil, parent)
  sb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  sb:SetStatusBarColor(0.58, 0.3, 1)
  sb:SetSize(width, 5)
  sb:SetMinMaxValues(0, 1)
  local bg = sb:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
  return sb
end

local function feedLine(entry)
  local icon = entry.icon and ("|T" .. entry.icon .. ":14:14:0:0:64:64:5:59:5:59|t ") or ""
  local text = entry.b and entry.text or ("|cffbbbbbb" .. entry.text .. "|r")
  return "|cff777777" .. date("%H:%M", entry.t) .. "|r  " .. icon .. text
end

---------------------------------------------------------------------------
-- Window shell
---------------------------------------------------------------------------
local function selectTab(index)
  for i, page in ipairs(pages) do
    local on = i == index
    page:SetShown(on)
    if on then
      tabs[i]:SetBackdropColor(0.17, 0.14, 0.09, 1)
      tabs[i].text:SetTextColor(1, 1, 1)
    else
      tabs[i]:SetBackdropColor(0.08, 0.07, 0.05, 1)
      tabs[i].text:SetTextColor(1, 0.82, 0)
    end
  end
  if pages[index].Refresh then pages[index]:Refresh() end
end

local function createWindow()
  local f = CreateFrame("Frame", "TjommieFrame", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, HEIGHT)
  f:SetPoint("CENTER", -120, 40)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:SetBackdropColor(0.03, 0.03, 0.04, 0.95)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.windowPos = { point, relPoint, x, y }
  end)
  f:Hide()
  table.insert(UISpecialFrames, "TjommieFrame") -- Escape closes it

  -- Drag the bottom-right corner to resize
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(WIDTH, HEIGHT, 1100, 820)
  elseif f.SetMinResize then f:SetMinResize(WIDTH, HEIGHT); f:SetMaxResize(1100, 820) end
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -6, 6)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    ns.db.windowSize = { math.floor(f:GetWidth()), math.floor(f:GetHeight()) }
  end)

  -- Title strip
  local strip = f:CreateTexture(nil, "ARTWORK")
  strip:SetPoint("TOPLEFT", 7, -7)
  strip:SetPoint("TOPRIGHT", -7, -7)
  strip:SetHeight(30)
  strip:SetColorTexture(0.16, 0.12, 0.06, 0.95)
  local stripLine = f:CreateTexture(nil, "ARTWORK")
  stripLine:SetPoint("TOPLEFT", strip, "BOTTOMLEFT")
  stripLine:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT")
  stripLine:SetHeight(1)
  stripLine:SetColorTexture(0.55, 0.43, 0.2, 0.9)

  -- Portrait (overlapping the top-left corner)
  local portrait = CreateFrame("Frame", nil, f)
  portrait:SetSize(76, 76)
  portrait:SetPoint("TOPLEFT", -16, 18)
  portrait:SetFrameLevel(f:GetFrameLevel() + 10)
  local ring = portrait:CreateTexture(nil, "BACKGROUND")
  ring:SetTexture(MEDIA .. "dot")
  ring:SetAllPoints()
  ring:SetVertexColor(0.78, 0.62, 0.3)
  local ringIn = portrait:CreateTexture(nil, "BORDER")
  ringIn:SetTexture(MEDIA .. "dot")
  ringIn:SetSize(68, 68)
  ringIn:SetPoint("CENTER")
  ringIn:SetVertexColor(0, 0, 0)
  local icon = portrait:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(MEDIA .. "icon")
  icon:SetSize(62, 62)
  icon:SetPoint("CENTER")
  if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("LEFT", strip, "LEFT", 70, 0)
  f.title:SetText("Tjommie")

  f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.status:SetPoint("RIGHT", strip, "RIGHT", -34, 0)
  f.status:SetJustifyH("RIGHT")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local choose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  choose:SetSize(120, 20)
  choose:SetPoint("LEFT", f.title, "RIGHT", 16, 0)
  choose:SetText("Choose tjommie")
  choose:SetScript("OnClick", function() ns:ShowPicker() end)

  -- Bottom tabs
  local names = { "Overview", "Together", "Feed", "Stats", "Upgrades", "Crafting", "Wishlist", "Settings" }
  local x = 26
  for i, name in ipairs(names) do
    local b = CreateFrame("Button", nil, f, "BackdropTemplate")
    b:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b:SetBackdropBorderColor(0.6, 0.47, 0.2, 1)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText(name)
    b:SetSize((b.text:GetStringWidth() or 60) + 16, 28)
    b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", x, 6)
    x = x + b:GetWidth() + 4
    b:SetScript("OnClick", function() selectTab(i) end)
    tabs[i] = b

    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 16, -48)
    page:SetPoint("BOTTOMRIGHT", -16, 14)
    page:Hide()
    pages[i] = page
  end
  return f
end

local function updateStatus()
  if not win then return end
  if not ns.db.buddy then
    win.status:SetText("|cffaaaaaaNo tjommie set - /tj set Name|r")
  elseif ns:IsBuddyOnline() then
    win.status:SetText(ns.BuddyNameColored() .. "  |cff00ff00Online|r")
  else
    win.status:SetText(ns.BuddyNameColored() .. "  |cff999999Offline|r")
  end
end

---------------------------------------------------------------------------
-- Overview page
---------------------------------------------------------------------------
local H2H = {
  { "Kills",       "kills" },
  { "Quests",      "quests" },
  { "Gold earned", "goldEarned", true },
  { "Deaths",      "deaths" },
}

local function makeCard(parent, x)
  local c = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  c:SetSize(220, 66)
  c:SetPoint("TOPLEFT", x, -4)
  c:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  c:SetBackdropColor(1, 1, 1, 0.04)
  c:SetBackdropBorderColor(0.4, 0.33, 0.2, 0.9)
  c.portrait = c:CreateTexture(nil, "ARTWORK")
  c.portrait:SetSize(44, 44)
  c.portrait:SetPoint("LEFT", 10, 0)
  c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  c.name:SetPoint("TOPLEFT", c.portrait, "TOPRIGHT", 10, -1)
  c.sub = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
  c.sub:SetWidth(150)
  c.sub:SetJustifyH("LEFT")
  c.sub:SetWordWrap(false)
  c.xp = xpBar(c, 150)
  c.xp:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -6)
  return c
end

local function fillCard(c, name, class, level, zone, xp, xpMax)
  ns.SetClassIcon(c.portrait, class)
  c.name:SetText("|c" .. ns.ClassColorHex(class) .. (name or "?") .. "|r")
  c.sub:SetText(string.format("Lv %s %s%s", tostring(level or "?"), ns.ClassName(class),
    (zone and zone ~= "") and (" · " .. zone) or ""))
  if xp and xpMax and xpMax > 0 then c.xp:SetValue(xp / xpMax); c.xp:Show() else c.xp:Hide() end
end

local function buildOverview(page)
  local me = makeCard(page, 0)
  local them = makeCard(page, 338)

  local mid = CreateFrame("Frame", nil, page)
  mid:SetSize(110, 66)
  mid:SetPoint("TOPLEFT", 224, -4)
  mid.big = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  mid.big:SetPoint("TOP", 0, -6)
  mid.small = mid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  mid.small:SetPoint("TOP", mid.big, "BOTTOM", 0, -2)
  mid.eta = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  mid.eta:SetPoint("TOP", mid.small, "BOTTOM", 0, -3)

  sectionHeader(page, "Recent", -84)
  local rows = {}
  for i = 1, 5 do
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 6, -106 - (i - 1) * 21)
    fs:SetPoint("RIGHT", -6, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    rows[i] = fs
  end

  sectionHeader(page, "Head to head", -218)
  local h2h = {}
  for i, def in ipairs(H2H) do
    local y = -242 - (i - 1) * 24
    local label = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 6, y)
    label:SetText(def[1])
    local track = CreateFrame("Frame", nil, page)
    track:SetSize(300, 10)
    track:SetPoint("TOPLEFT", 100, y - 1)
    track.bg = track:CreateTexture(nil, "BACKGROUND")
    track.bg:SetAllPoints()
    track.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    track.a = track:CreateTexture(nil, "ARTWORK")
    track.a:SetPoint("TOPLEFT"); track.a:SetPoint("BOTTOMLEFT")
    track.b = track:CreateTexture(nil, "ARTWORK")
    track.b:SetPoint("TOPRIGHT"); track.b:SetPoint("BOTTOMRIGHT")
    local val = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("LEFT", track, "RIGHT", 10, 0)
    h2h[i] = { track = track, val = val }
  end

  -- Meet-up buttons
  local meetMe = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  meetMe:SetSize(150, 22)
  meetMe:SetPoint("BOTTOMLEFT", 4, 2)
  meetMe:SetText("Meet at my spot")
  meetMe:SetScript("OnClick", function() ns:MeetAtMe() end)
  local meetClear = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  meetClear:SetSize(120, 22)
  meetClear:SetPoint("LEFT", meetMe, "RIGHT", 6, 0)
  meetClear:SetText("Clear meet-up")
  meetClear:SetScript("OnClick", function() ns:ClearMeet() end)
  local takeMe = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  takeMe:SetSize(130, 22)
  takeMe:SetPoint("LEFT", meetClear, "RIGHT", 6, 0)
  takeMe:SetText("Take me there")
  takeMe:SetScript("OnClick", function()
    if ns:IsGuiding() then ns:StopGuiding() else ns:GuideTo(ns.meet and "meet" or "buddy") end
  end)
  takeMe:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Take me there")
    GameTooltip:AddLine("Turn-by-turn route to the meeting point (or your tjommie) using Shortest Path Forever.", 1, 1, 1, true)
    if not ns.SPF() then GameTooltip:AddLine("Shortest Path Forever isn't installed.", 1, 0.4, 0.4, true) end
    GameTooltip:Show()
  end)
  takeMe:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local tip = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  tip:SetPoint("LEFT", takeMe, "RIGHT", 10, 0)
  tip:SetPoint("RIGHT", page, "RIGHT", -4, 0)
  tip:SetJustifyH("LEFT")
  tip:SetText("Or use \"Meet here\" on the world map.")

  function page:Refresh()
    local mine, theirs = ns:GetMyStats(), ns.buddy.stats or {}
    local info, pos = ns.buddy.info, ns.buddy.pos
    fillCard(me, UnitName("player"), mine.class, mine.level, mine.zone, mine.xp, mine.xpMax)
    local status = ns.BuddyStatusText and ns:BuddyStatusText()
    fillCard(them, ns:BuddyShortName(), info.class, info.level, status or (pos and pos.zone), theirs.xp, theirs.xpMax)
    meetClear:SetEnabled(ns.meet ~= nil)
    takeMe:SetText(ns:IsGuiding() and "Stop guiding" or "Take me there")
    them:SetAlpha(ns:IsBuddyOnline() and 1 or 0.6)

    local nav = ns.nav
    if nav.status == "ok" then
      local together = nav.dist < 40
      mid.big:SetText(together and "|cff00ff00Together!|r" or ns.FormatDistance(nav.dist))
      local label = nav.target == "meet" and "to meet-up" or "apart"
      mid.small:SetText(together and "" or (label .. (nav.heading and (" · " .. nav.heading) or "")))
      mid.eta:SetText(nav.eta and ("|cff88ff88ETA " .. ns.FormatETA(nav.eta) .. "|r") or "")
    else
      mid.big:SetText("|cff777777- -|r")
      local why = { continent = "other continent", hidden = "location hidden", private = "location paused", nobuddy = "no tjommie set" }
      mid.small:SetText(why[nav.status] or "offline")
      mid.eta:SetText("")
    end

    local feed = ns.cdb.feed
    for i = 1, 5 do
      local e = feed[#feed - i + 1]
      rows[i]:SetText(e and feedLine(e) or "")
    end

    local _, myClass = UnitClass("player")
    local ar, ag, ab = ns.ClassColor(myClass)
    local br, bg, bb = ns.ClassColor(info.class)
    for i, def in ipairs(H2H) do
      local a, b = tonumber(mine[def[2]]) or 0, tonumber(theirs[def[2]]) or 0
      local row = h2h[i]
      local total = a + b
      local w = row.track:GetWidth()
      if total > 0 then
        row.track.a:SetWidth(math.max(1, w * a / total)); row.track.a:SetColorTexture(ar, ag, ab, 1)
        row.track.b:SetWidth(math.max(1, w * b / total)); row.track.b:SetColorTexture(br, bg, bb, 1)
        row.track.a:Show(); row.track.b:Show()
      else
        row.track.a:Hide(); row.track.b:Hide()
      end
      if def[3] then
        row.val:SetText(ns.FormatMoney(a) .. "  |cff777777vs|r  " .. ns.FormatMoney(b))
      else
        row.val:SetText(a .. "  |cff777777vs|r  " .. b)
      end
    end
  end

  local t = 0
  page:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    if t > 0.5 then t = 0; self:Refresh() end
  end)
end

---------------------------------------------------------------------------
-- Feed page
---------------------------------------------------------------------------
local function buildFeed(page)
  local smf = CreateFrame("ScrollingMessageFrame", nil, page)
  smf:SetPoint("TOPLEFT", 4, -4)
  smf:SetPoint("BOTTOMRIGHT", -4, 4)
  smf:SetFontObject(GameFontHighlightSmall)
  smf:SetJustifyH("LEFT")
  smf:SetFading(false)
  smf:SetMaxLines(250)
  if smf.SetSpacing then smf:SetSpacing(4) end
  smf:SetHyperlinksEnabled(true)
  smf:EnableMouseWheel(true)
  smf:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
  end)
  smf:SetScript("OnHyperlinkEnter", function(self, link)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    GameTooltip:Show()
  end)
  smf:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)

  for _, entry in ipairs(ns.cdb.feed) do smf:AddMessage(feedLine(entry)) end
  ns:Listen("FEED_ADDED", function(entry) smf:AddMessage(feedLine(entry)) end)
end

---------------------------------------------------------------------------
-- Stats page
---------------------------------------------------------------------------
local function pct(v, s)
  if s.xpMax and s.xpMax > 0 then return string.format("%d%%", math.floor(v / s.xpMax * 100)) end
  return v
end

-- Two blocks side by side: Lifetime (from the game) and Since Tjommie (tracked by the add-on)
local LIFETIME_ROWS = {
  { "Level",            "level" },
  { "XP",               "xp",          pct },
  { "Gold",             "gold",        ns.FormatMoney },
  { "Time played",      "playedTotal", ns.FormatTime },
  { "Quests completed", "questsTotal" },
  { "Kills*",           "killsTotal" },
  { "Deaths*",          "deathsTotal", nil, true },
  { "Drinks*",          "drinksTotal" },
}

local SINCE_ROWS = {
  { "Gold earned",    "goldEarned", ns.FormatMoney },
  { "Kills (XP)",     "kills" },
  { "Deaths",         "deaths",     nil, true },
  { "Quests done",    "quests" },
  { "Zones explored", "zones" },
  { "Distance",       "distance",   ns.FormatDistance },
  { "Blues looted",   "rares" },
  { "Epics looted",   "epics" },
  { "Time played",    "played",     ns.FormatTime },
  { "Drinks",         "drinks" },
  { "Got smashed",    "smashed" },
  { "Time dancing",   "danced",     ns.FormatTime },
  { "At Gees Vuur",   "fireTime",   ns.FormatTime },
  { "Gees Vuurs lit", "fires" },
}

local ROW_H = 20

local function buildStatBlock(page, x, title, rows)
  local colX = { x + 4, x + 128, x + 200 }
  local function cell(row, col, text, font)
    local fs = page:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", colX[col], -26 - row * ROW_H)
    fs:SetText(text or "")
    if col > 1 then fs:SetWidth(70); fs:SetJustifyH("LEFT"); fs:SetWordWrap(false) end
    return fs
  end
  local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  head:SetPoint("TOPLEFT", x + 4, -4)
  head:SetText(title)
  local line = page:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.55, 0.43, 0.2, 0.6)
  line:SetSize(268, 1)
  line:SetPoint("TOPLEFT", x, -20)

  local block = { rows = rows, cells = {} }
  block.myHead = cell(0, 2, "", "GameFontNormalSmall")
  block.budHead = cell(0, 3, "", "GameFontNormalSmall")
  for i, def in ipairs(rows) do
    if i % 2 == 1 then
      local band = page:CreateTexture(nil, "BACKGROUND")
      band:SetColorTexture(1, 1, 1, 0.035)
      band:SetSize(268, ROW_H - 1)
      band:SetPoint("TOPLEFT", x, -22 - i * ROW_H)
    end
    cell(i, 1, def[1], "GameFontNormalSmall")
    block.cells[i] = { cell(i, 2, "-"), cell(i, 3, "-") }
  end
  return block
end

local function fillStatBlock(block, mine, theirs)
  local _, myClass = UnitClass("player")
  block.myHead:SetText("|c" .. ns.ClassColorHex(myClass) .. UnitName("player") .. "|r")
  block.budHead:SetText(ns.BuddyNameColored())
  for i, def in ipairs(block.rows) do
    local key, fmt, lowerWins = def[2], def[3], def[4]
    local a, b = mine[key], theirs[key]
    local fa, fb = block.cells[i][1], block.cells[i][2]
    fa:SetText(a ~= nil and tostring(fmt and fmt(a, mine) or a) or "-")
    fb:SetText(b ~= nil and tostring(fmt and fmt(b, theirs) or b) or "-")
    fa:SetTextColor(1, 1, 1); fb:SetTextColor(1, 1, 1)
    local ra, rb = tonumber(a), tonumber(b)
    if ra and rb and ra ~= rb and key ~= "xp" then
      if (ra > rb) ~= (lowerWins == true) then fa:SetTextColor(0.3, 1, 0.3) else fb:SetTextColor(0.3, 1, 0.3) end
    end
  end
end

local function buildStats(page)
  local life = buildStatBlock(page, 0, "Lifetime", LIFETIME_ROWS)
  local since = buildStatBlock(page, 284, "Since Tjommie", SINCE_ROWS)

  local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 4, -26 - (#LIFETIME_ROWS + 1) * ROW_H - 6)
  note:SetWidth(266)
  note:SetJustifyH("LEFT")
  note:SetText("* Only if Forever keeps Blizzard's Statistics.\n\"Since Tjommie\" counts from when you installed Tjommie on this character.")

  function page:Refresh()
    local mine, theirs = ns:GetMyStats(), ns.buddy.stats or {}
    fillStatBlock(life, mine, theirs)
    fillStatBlock(since, mine, theirs)
  end
  ns:Listen("LIFETIME_UPDATED", function() if page:IsShown() then page:Refresh() end end)

  local t = 0
  page:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    if t > 2 then t = 0; self:Refresh() end
  end)
end

---------------------------------------------------------------------------
-- Wishlist page
---------------------------------------------------------------------------
local ROWS = 10

local function makeItemRow(parent, x, y, removable)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(262, 22)
  row:SetPoint("TOPLEFT", x, y)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.06)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT")
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.text:SetPoint("RIGHT", removable and -22 or 0, 0)
  row.text:SetJustifyH("LEFT")
  row.text:SetWordWrap(false)
  row:SetScript("OnEnter", function(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. self.itemID)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  if removable then
    local x = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    x:SetSize(20, 20)
    x:SetPoint("RIGHT")
    x:SetScript("OnClick", function() ns:RemoveWish(row.itemID) end)
  end
  row:Hide()
  return row
end

local function fillRows(rows, list, empty)
  for i, row in ipairs(rows) do
    local id = list[i]
    if id then
      row.itemID = id
      row.text:SetText("item " .. id)
      row.icon:SetTexture(C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) or 134400)
      local item = Item:CreateFromItemID(id)
      item:ContinueOnItemLoad(function()
        if row.itemID == id then row.text:SetText(item:GetItemLink() or id) end
      end)
      row:Show()
    else
      row.itemID = nil
      row:Hide()
    end
  end
  if empty then empty:SetShown(#list == 0) end
end

local function buildWishlist(page)
  local classInfo = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  classInfo:SetPoint("TOPLEFT", 6, -4)
  classInfo:SetPoint("TOPRIGHT", -6, -4)
  classInfo:SetJustifyH("LEFT")

  sectionHeader(page, "My wishlist", -42)
  local budTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  budTitle:SetPoint("TOPLEFT", 286, -42)

  local myRows, budRows = {}, {}
  for i = 1, ROWS do
    myRows[i] = makeItemRow(page, 4, -64 - (i - 1) * 24, true)
    budRows[i] = makeItemRow(page, 286, -64 - (i - 1) * 24, false)
  end
  local myEmpty = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  myEmpty:SetPoint("TOPLEFT", 8, -68)
  myEmpty:SetText("Nothing yet - add items below.")
  local budEmpty = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  budEmpty:SetPoint("TOPLEFT", 290, -68)
  budEmpty:SetText("Nothing yet.")

  local box = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  box:SetSize(330, 20)
  box:SetPoint("BOTTOMLEFT", 10, 6)
  box:SetAutoFocus(false)
  local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", 4, 0)
  hint:SetText("Click here, then shift-click an item to add it")
  box:SetScript("OnEditFocusGained", function() hint:Hide() end)
  box:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then hint:Show() end end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self)
    ns:AddWish(self:GetText())
    self:SetText("")
    self:ClearFocus()
  end)
  page.box = box

  local add = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  add:SetSize(80, 22)
  add:SetPoint("LEFT", box, "RIGHT", 8, 0)
  add:SetText("Add")
  add:SetScript("OnClick", function() box:GetScript("OnEnterPressed")(box) end)

  local function describe(class, level)
    if not class then return "|cff999999unknown yet|r" end
    local armor = ns.BestArmor(class, level)
    local s = "|c" .. ns.ClassColorHex(class) .. ns.ClassName(class) .. "|r"
    if armor then s = s .. " (" .. ns.ARMOR_NAMES[armor] .. ")" end
    return s
  end

  function page:Refresh()
    local _, myClass = UnitClass("player")
    classInfo:SetText("Upgrade alerts are tuned to your classes:  You = " .. describe(myClass, UnitLevel("player"))
      .. "   " .. ns:BuddyShortName() .. " = " .. describe(ns.buddy.info.class, ns.buddy.info.level)
      .. "\n|cff999999Plate / Mail unlock at level 40 for Warriors, Paladins, Hunters & Shamans.|r")
    budTitle:SetText(ns:BuddyShortName() .. "'s wishlist")
    fillRows(myRows, ns.cdb.wishlist, myEmpty)
    fillRows(budRows, ns.buddy.wishlist or {}, budEmpty)
  end

  ns:Listen("WISHLIST_CHANGED", function() if page:IsShown() then page:Refresh() end end)
  ns:Listen("BUDDY_INFO", function() if page:IsShown() then page:Refresh() end end)
end

---------------------------------------------------------------------------
-- Upgrades page
---------------------------------------------------------------------------
local UP_ROWS = 13

local function buildUpgrades(page)
  local intro = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  intro:SetPoint("TOPLEFT", 6, -4)
  intro:SetPoint("TOPRIGHT", -6, -4)
  intro:SetJustifyH("LEFT")
  intro:SetText("Upgrades found in your quest log, " .. ns:BuddyShortName() .. "'s quest log, quest-givers and vendors you've visited.")

  local rows = {}
  for i = 1, UP_ROWS do
    local row = CreateFrame("Button", nil, page)
    row:SetSize(556, 26)
    row:SetPoint("TOPLEFT", 2, -26 - (i - 1) * 27)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 2, 0)
    row.who = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.who:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.who:SetWidth(54)
    row.who:SetJustifyH("LEFT")
    row.item = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.item:SetPoint("LEFT", row.who, "RIGHT", 4, 6)
    row.item:SetWidth(200)
    row.item:SetJustifyH("LEFT")
    row.item:SetWordWrap(false)
    row.why = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    row.why:SetPoint("LEFT", row.who, "RIGHT", 4, -6)
    row.why:SetWidth(200)
    row.why:SetJustifyH("LEFT")
    row.src = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.src:SetPoint("LEFT", row.item, "RIGHT", 10, 0)
    row.src:SetWidth(270)
    row.src:SetJustifyH("LEFT")
    row.src:SetWordWrap(false)
    row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.zone:SetPoint("LEFT", row.why, "RIGHT", 10, 0)
    row.zone:SetWidth(270)
    row.zone:SetJustifyH("LEFT")
    row:SetScript("OnEnter", function(self)
      if not self.itemID then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink("item:" .. self.itemID)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:Hide()
    rows[i] = row
  end

  local empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 8, -34)
  empty:SetText("No upgrades spotted yet. Pick up quests, talk to quest-givers and open vendors - Tjommie checks them all.")

  local rescan = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  rescan:SetSize(110, 22)
  rescan:SetPoint("BOTTOMRIGHT", -4, 4)
  rescan:SetText("Rescan quests")
  rescan:SetScript("OnClick", function() ns:ScanQuestLog() end)

  function page:Refresh()
    local list = ns:GetUpgradeList()
    for i, row in ipairs(rows) do
      local e = list[i]
      if e then
        row.itemID = e.itemID
        row.icon:SetTexture(C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.itemID) or 134400)
        if e.who == "me" then
          row.who:SetText("|cff00ff00For you|r")
        else
          row.who:SetText("|c" .. ns.ClassColorHex(ns.buddy.info.class) .. ns:BuddyShortName() .. "|r")
        end
        local link = select(2, ns.GetItemInfo(e.itemID))
        row.item:SetText(link or ("item " .. e.itemID))
        row.why:SetText(e.why or "")
        row.src:SetText(e.src or "")
        row.zone:SetText(e.zone or "")
        row:Show()
      else
        row.itemID = nil
        row:Hide()
      end
    end
    empty:SetShown(#list == 0)
  end

  ns:Listen("UPGRADES_CHANGED", function() if page:IsShown() then page:Refresh() end end)
end

---------------------------------------------------------------------------
-- Friend picker
---------------------------------------------------------------------------
local picker
local PICK_ROWS = 12

local function createPicker()
  local p = CreateFrame("Frame", "TjommiePicker", UIParent, "BackdropTemplate")
  p:SetSize(330, 380)
  p:SetFrameStrata("DIALOG")
  p:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  p:SetBackdropColor(0.03, 0.03, 0.04, 0.97)
  p:EnableMouse(true)
  table.insert(UISpecialFrames, "TjommiePicker")

  local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("Choose your tjommie")
  local hint = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  hint:SetText("Click a friend to send a request. They tap Accept - done.")
  local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  p.rows = {}
  for i = 1, PICK_ROWS do
    local row = CreateFrame("Button", nil, p)
    row:SetSize(298, 24)
    row:SetPoint("TOPLEFT", 16, -52 - (i - 1) * 25)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.2, 1, 0.6, 0.12)
    row.portrait = row:CreateTexture(nil, "ARTWORK")
    row.portrait:SetSize(20, 20)
    row.portrait:SetPoint("LEFT", 2, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.portrait, "RIGHT", 6, 0)
    row.name:SetWidth(130)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.info:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.info:SetWidth(134)
    row.info:SetJustifyH("LEFT")
    row.info:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
      if self.fullName then ns:RequestPair(self.fullName); p:Hide() end
    end)
    row:Hide()
    p.rows[i] = row
  end

  p.empty = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  p.empty:SetPoint("TOPLEFT", 18, -60)
  p.empty:SetWidth(290)
  p.empty:SetJustifyH("LEFT")
  p.empty:SetText("No online friends found.\n\nAdd them to your friends list, group up, or target them and type /tj set.")

  function p:Refresh()
    local list = ns:GetPairCandidates()
    for i, row in ipairs(self.rows) do
      local c = list[i]
      if c then
        row.fullName = c.name
        ns.SetClassIcon(row.portrait, c.class)
        row.name:SetText("|c" .. ns.ClassColorHex(c.class) .. (strsplit("-", c.name)) .. "|r" .. (c.level and ("  |cffffffff" .. c.level .. "|r") or ""))
        row.info:SetText((c.zone or "") .. (c.note and ("  |cff777777" .. c.note .. "|r") or ""))
        row:Show()
      else
        row.fullName = nil
        row:Hide()
      end
    end
    self.empty:SetShown(#list == 0)
  end
  return p
end

function ns:ShowPicker()
  picker = picker or createPicker()
  picker:ClearAllPoints()
  if win and win:IsShown() then
    picker:SetPoint("TOPLEFT", win, "TOPRIGHT", 6, 0)
  else
    picker:SetPoint("CENTER")
  end
  picker:Refresh()
  picker:Show()
end

---------------------------------------------------------------------------
-- Together page: dungeon suggestions + badges
---------------------------------------------------------------------------
local DUNGEON_ROWS = 5
local BADGE_COLS = 4

local STATE_COLOR = { both = "|cff00ff00", you = "|cffffd100", them = "|cffffd100", soon = "|cffaaaaaa" }

local function buildTogether(page)
  sectionHeader(page, "Dungeons for you two", -2)
  local dnote = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  dnote:SetPoint("TOPRIGHT", -4, -4)
  dnote:SetText("Click one to ask your tjommie · Classic level ranges")
  local drows = {}
  for i = 1, DUNGEON_ROWS do
    -- Each row is a button: click to ask your tjommie if they're keen
    local row = CreateFrame("Button", nil, page)
    row:SetPoint("TOPLEFT", 2, -22 - (i - 1) * 18)
    row:SetPoint("RIGHT", page, "RIGHT", -2, 0)
    row:SetHeight(18)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.2, 1, 0.6, 0.10)
    row:SetScript("OnClick", function(self) if self.dname then ns:AskDungeon(self.dname) end end)
    row:SetScript("OnEnter", function(self)
      if not self.dname then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.dname)
      GameTooltip:AddLine("Click to ask " .. ns:BuddyShortName() .. " if they're keen.", 1, 1, 1)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.name = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", 6, -24 - (i - 1) * 18)
    row.name:SetWidth(220); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.where = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.where:SetPoint("TOPLEFT", 232, -24 - (i - 1) * 18)
    row.where:SetWidth(150); row.where:SetJustifyH("LEFT"); row.where:SetWordWrap(false)
    row.note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.note:SetPoint("TOPLEFT", 386, -24 - (i - 1) * 18)
    row.note:SetWidth(170); row.note:SetJustifyH("LEFT"); row.note:SetWordWrap(false)
    drows[i] = row
  end
  local dempty = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  dempty:SetPoint("TOPLEFT", 6, -26)
  dempty:SetText("No dungeons in range right now. Keep levelling!")

  local badgeTitle = sectionHeader(page, "Tjommie badges", -122)
  local score = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  score:SetPoint("TOPRIGHT", -4, -124)

  local cells = {}
  local cellW, cellH = 138, 48
  local total = #ns.BADGES + 1 -- + the level-race cell
  for i = 1, total do
    local col = (i - 1) % BADGE_COLS
    local rowN = math.floor((i - 1) / BADGE_COLS)
    local c = CreateFrame("Frame", nil, page)
    c:SetSize(cellW - 4, cellH - 4)
    c:SetPoint("TOPLEFT", 2 + col * cellW, -144 - rowN * cellH)
    c:EnableMouse(true)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(32, 32)
    c.icon:SetPoint("LEFT", 2, 0)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 5, -1)
    c.name:SetWidth(cellW - 46); c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false)
    c.sub = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
    c.sub:SetWidth(cellW - 46); c.sub:SetJustifyH("LEFT"); c.sub:SetWordWrap(false)
    c:SetScript("OnEnter", function(self)
      if not self.tipTitle then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.tipTitle)
      GameTooltip:AddLine(self.tipText or "", 1, 1, 1, true)
      if self.tipExtra then GameTooltip:AddLine(self.tipExtra, 0.6, 0.8, 1, true) end
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cells[i] = c
  end

  function page:Refresh()
    -- Dungeons
    local list = ns:GetDungeonSuggestions(UnitLevel("player"), ns.db.buddy and ns.buddy.info.level or nil)
    for i, row in ipairs(drows) do
      local d = list[i]
      if d then
        row.dname = d.name
        row:Show()
        row.name:SetText((STATE_COLOR[d.state] or "") .. d.name .. "|r  |cff777777" .. d.min .. "-" .. d.max .. "|r")
        row.where:SetText(d.where)
        row.note:SetText(d.note)
      else
        row.dname = nil
        row:Hide()
        row.name:SetText(""); row.where:SetText(""); row.note:SetText("")
      end
    end
    dempty:SetShown(#list == 0)

    -- Badges
    local p = ns.db.buddy and ns:PairData() or nil
    local earned, totalB, me, them = ns:BadgeSummary()
    score:SetText(string.format("%d / %d unlocked   |   Level races: you %d - %d %s", earned, totalB, me, them, ns:BuddyShortName()))
    for i, b in ipairs(ns.BADGES) do
      local c = cells[i]
      local got = p and p.badges[b.id]
      c.icon:SetTexture(b.icon)
      c.icon:SetDesaturated(not got)
      c.icon:SetAlpha(got and 1 or 0.45)
      c.name:SetText(got and ("|cffffd100" .. b.name .. "|r") or ("|cff888888" .. b.name .. "|r"))
      c.sub:SetText(got and date("%d %b %Y", got.t) or b.desc)
      c.tipTitle, c.tipText = b.name, b.desc
      c.tipExtra = got and ("Unlocked " .. date("%d %b %Y %H:%M", got.t)) or "Not yet unlocked"
    end
    -- Level races cell
    local rc = cells[#ns.BADGES + 1]
    rc.icon:SetTexture("Interface\\Icons\\Spell_Holy_SurgeOfLight")
    rc.icon:SetDesaturated(me + them == 0)
    rc.icon:SetAlpha((me + them == 0) and 0.45 or 1)
    rc.name:SetText("|cffffd100Level races|r")
    rc.sub:SetText(string.format("You %d - %d %s", me, them, ns:BuddyShortName()))
    rc.tipTitle = "Level races"
    rc.tipText = "First to level 10, 20, 30, 40, 50 and 60 wins the race."
    local lines = {}
    for _, L in ipairs(ns.RACE_LEVELS) do
      local r = p and p.badges["race" .. L]
      table.insert(lines, "Level " .. L .. ": " .. (r and (r.winner == UnitName("player") and "you" or (r.winner or "?")) or "-"))
    end
    rc.tipExtra = table.concat(lines, "\n")
  end

  ns:Listen("BADGES_CHANGED", function() if page:IsShown() then page:Refresh() end end)
  local t = 0
  page:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    if t > 3 then t = 0; self:Refresh() end
  end)
end

---------------------------------------------------------------------------
-- Crafting page: your tjommie's (or your own) professions and recipes
---------------------------------------------------------------------------
local CRAFT_ROWS = 13

local function buildCrafting(page)
  local view = "theirs"     -- "theirs" | "mine"
  local filter = nil        -- profession name or nil for all
  local search = ""
  local pageNum = 1

  local theirsBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  theirsBtn:SetSize(140, 22)
  theirsBtn:SetPoint("TOPLEFT", 2, -2)
  local mineBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  mineBtn:SetSize(100, 22)
  mineBtn:SetPoint("LEFT", theirsBtn, "RIGHT", 4, 0)
  mineBtn:SetText("Mine")

  local box = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  box:SetSize(170, 20)
  box:SetPoint("TOPRIGHT", -6, -3)
  box:SetAutoFocus(false)
  local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", 4, 0)
  hint:SetText("Search recipes...")

  local summary = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  summary:SetPoint("TOPLEFT", 4, -30)
  summary:SetPoint("RIGHT", page, "RIGHT", -4, 0)
  summary:SetJustifyH("LEFT")
  summary:SetWordWrap(false)

  local filterBtns = {}
  for i = 1, 6 do
    local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    b:SetSize(96, 20)
    b:SetPoint("TOPLEFT", 2 + (i - 1) * 100, -48)
    b:Hide()
    filterBtns[i] = b
  end

  local rows = {}
  for i = 1, CRAFT_ROWS do
    local row = CreateFrame("Button", nil, page)
    row:SetHeight(22)
    row:SetPoint("TOPLEFT", 2, -74 - (i - 1) * 23)
    row:SetPoint("RIGHT", page, "RIGHT", -2, 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 2, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(360); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.prof = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.prof:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.prof:SetWidth(110); row.prof:SetJustifyH("LEFT")
    row.ask = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    row.ask:SetPoint("RIGHT", -6, 0)
    row:SetScript("OnEnter", function(self)
      if not self.entry then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      ns.RecipeTooltip(self.entry)
      if view == "theirs" then GameTooltip:AddLine("Click to ask " .. ns:BuddyShortName() .. " to make this", 0.2, 1, 0.6) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
      if self.entry and view == "theirs" then ns:AskCraft(self.entry) end
    end)
    row:Hide()
    rows[i] = row
  end

  local empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 8, -80)
  empty:SetWidth(600)
  empty:SetJustifyH("LEFT")

  local prev = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  prev:SetSize(28, 20); prev:SetText("<")
  prev:SetPoint("BOTTOMRIGHT", -80, 2)
  local nextBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  nextBtn:SetSize(28, 20); nextBtn:SetText(">")
  nextBtn:SetPoint("BOTTOMRIGHT", -4, 2)
  local pageText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pageText:SetPoint("RIGHT", nextBtn, "LEFT", -6, 0)

  local function data()
    if view == "mine" then return ns.cdb.professions or {}, ns.cdb.recipes or {} end
    return ns.buddy.professions or {}, ns.buddy.recipes or {}
  end

  function page:Refresh()
    theirsBtn:SetText(ns:BuddyShortName() .. "'s")
    theirsBtn:SetEnabled(view ~= "theirs")
    mineBtn:SetEnabled(view ~= "mine")

    local profs, recipes = data()
    -- Summary: "Enchanting 225/300 · Tailoring 180/225"
    local parts = {}
    for name, p in pairs(profs) do table.insert(parts, string.format("|cffffd100%s|r %d/%d", name, p.rank or 0, p.max or 0)) end
    table.sort(parts)
    summary:SetText(#parts > 0 and table.concat(parts, "   ") or "|cffaaaaaaNo professions shared yet.|r")

    -- Profession filter buttons (only professions with recipes)
    local names = {}
    for name in pairs(recipes) do table.insert(names, name) end
    table.sort(names)
    if filter and not recipes[filter] then filter = nil end
    for i, b in ipairs(filterBtns) do
      local label = (i == 1) and "All" or names[i - 1]
      if label and (#names > 0) then
        b:SetText(label)
        b:SetEnabled(((i == 1) and filter ~= nil) or ((i > 1) and filter ~= label))
        b:SetScript("OnClick", function() filter = (i == 1) and nil or label; pageNum = 1; page:Refresh() end)
        b:Show()
      else
        b:Hide()
      end
    end

    -- Build the filtered list
    local list = {}
    local q = search:lower()
    for _, name in ipairs(names) do
      if not filter or filter == name then
        ns.PreloadRecipes(recipes[name])
        for _, e in ipairs(recipes[name]) do
          local label = tostring((ns.RecipeInfo(e)))
          if q == "" or label:lower():find(q, 1, true) then
            table.insert(list, { entry = e, prof = name, label = label })
          end
        end
      end
    end
    table.sort(list, function(a, b)
      local la = a.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|H.-|h", ""):lower()
      local lb = b.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|H.-|h", ""):lower()
      return la < lb
    end)

    local totalPages = math.max(1, math.ceil(#list / CRAFT_ROWS))
    pageNum = math.min(pageNum, totalPages)
    for i, row in ipairs(rows) do
      local item = list[(pageNum - 1) * CRAFT_ROWS + i]
      if item then
        local name, icon = ns.RecipeInfo(item.entry)
        row.entry = item.entry
        row.icon:SetTexture(icon or 134400)
        row.name:SetText(tostring(name))
        row.prof:SetText(item.prof)
        row.ask:SetText(view == "theirs" and "Ask to craft" or "")
        row:Show()
      else
        row.entry = nil
        row:Hide()
      end
    end
    pageText:SetText(pageNum .. " / " .. totalPages)
    prev:SetEnabled(pageNum > 1)
    nextBtn:SetEnabled(pageNum < totalPages)

    if #names == 0 then
      empty:SetText(view == "mine"
        and "Open each of your profession windows once and your recipes will appear here (and be shared with your tjommie)."
        or (ns:BuddyShortName() .. " hasn't shared recipes yet. Ask them to open each profession window once while you're both online, or type /tj share."))
      empty:Show()
    elseif #list == 0 then
      empty:SetText("No recipes match \"" .. search .. "\".")
      empty:Show()
    else
      empty:Hide()
    end
  end

  theirsBtn:SetScript("OnClick", function() view = "theirs"; filter = nil; pageNum = 1; page:Refresh() end)
  mineBtn:SetScript("OnClick", function() view = "mine"; filter = nil; pageNum = 1; page:Refresh() end)
  prev:SetScript("OnClick", function() pageNum = math.max(1, pageNum - 1); page:Refresh() end)
  nextBtn:SetScript("OnClick", function() pageNum = pageNum + 1; page:Refresh() end)
  box:SetScript("OnTextChanged", function(self)
    search = self:GetText() or ""
    hint:SetShown(search == "")
    pageNum = 1
    page:Refresh()
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  ns:Listen("BUDDY_PROFESSIONS", function() if page:IsShown() then page:Refresh() end end)
  ns:Listen("PROFESSIONS_CHANGED", function() if page:IsShown() then page:Refresh() end end)
  -- Item names load asynchronously; refresh a couple of times after opening
  page:HookScript("OnShow", function() C_Timer.After(0.5, function() if page:IsShown() then page:Refresh() end end) end)
end

-- Shift-click an item while the wishlist box has focus -> put its link in the box
local function hookInsertLink(tbl, fnName)
  if type(tbl[fnName]) ~= "function" then return end
  hooksecurefunc(tbl, fnName, function(link)
    local box = pages[7] and pages[7].box
    if box and box:HasFocus() and type(link) == "string" then box:SetText(link) end
  end)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function ns:OpenSettings()
  if not win then return end
  win:Show()
  selectTab(8)
end

ns:Listen("SETTINGS_CHANGED", function()
  if win then win:SetScale(ns.db.windowScale or 1) end
end)

function ns:ToggleWindow()
  if not win then return end
  win:SetShown(not win:IsShown())
end

ns:Listen("LOGIN", function()
  win = createWindow()
  local p = ns.db.windowPos
  if p then win:ClearAllPoints(); win:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
  local size = ns.db.windowSize
  if size then win:SetSize(math.max(WIDTH, size[1]), math.max(HEIGHT, size[2])) end
  win:SetScale(ns.db.windowScale or 1)
  buildOverview(pages[1])
  buildTogether(pages[2])
  buildFeed(pages[3])
  buildStats(pages[4])
  buildUpgrades(pages[5])
  buildCrafting(pages[6])
  buildWishlist(pages[7])
  ns:BuildSettingsPanel(pages[8])
  selectTab(1)
  win:SetScript("OnShow", function()
    updateStatus()
    for _, pg in ipairs(pages) do
      if pg:IsShown() and pg.Refresh then pg:Refresh() end
    end
  end)

  hookInsertLink(_G, "ChatEdit_InsertLink")
  if ChatFrameUtil then hookInsertLink(ChatFrameUtil, "InsertLink") end

  C_Timer.NewTicker(3, updateStatus)
end)

ns:Listen("BUDDY_ONLINE", updateStatus)
ns:Listen("BUDDY_CHANGED", updateStatus)
