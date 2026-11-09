-- Tjommie: Main window
-- Blizzard-style frame with the Tjommie portrait and bottom tabs:
-- Overview (you vs them, recent activity, head-to-head) / Feed / Stats / Wishlist.

local _, ns = ...

local WIDTH, HEIGHT = 590, 470
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
  local names = { "Overview", "Feed", "Stats", "Upgrades", "Wishlist" }
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
    b:SetSize((b.text:GetStringWidth() or 60) + 32, 28)
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

  local tip = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  tip:SetPoint("BOTTOMLEFT", 6, 2)
  tip:SetText("Tip: right-click the tracker bar to point TomTom's arrow at your tjommie.")

  function page:Refresh()
    local mine, theirs = ns:GetMyStats(), ns.buddy.stats or {}
    local info, pos = ns.buddy.info, ns.buddy.pos
    fillCard(me, UnitName("player"), mine.class, mine.level, mine.zone, mine.xp, mine.xpMax)
    fillCard(them, ns:BuddyShortName(), info.class, info.level, pos and pos.zone, theirs.xp, theirs.xpMax)
    them:SetAlpha(ns:IsBuddyOnline() and 1 or 0.6)

    local nav = ns.nav
    if nav.status == "ok" then
      local together = nav.dist < 40
      mid.big:SetText(together and "|cff00ff00Together!|r" or ns.FormatDistance(nav.dist))
      mid.small:SetText(together and "" or ("apart" .. (nav.heading and (" · " .. nav.heading) or "")))
      mid.eta:SetText(nav.eta and ("|cff88ff88ETA " .. ns.FormatETA(nav.eta) .. "|r") or "")
    else
      mid.big:SetText("|cff777777- -|r")
      local why = { continent = "other continent", hidden = "location hidden", nobuddy = "no tjommie set" }
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

local STAT_ROWS = {
  { "Level",          "level" },
  { "XP",             "xp",         pct },
  { "Gold",           "gold",       ns.FormatMoney },
  { "Gold earned",    "goldEarned", ns.FormatMoney },
  { "Kills (XP)",     "kills" },
  { "Deaths",         "deaths",     nil, true },
  { "Quests done",    "quests" },
  { "Zones explored", "zones" },
  { "Distance",       "distance",   ns.FormatDistance },
  { "Blues looted",   "rares" },
  { "Epics looted",   "epics" },
  { "Time (tracked)", "played",     ns.FormatTime },
  { "Drinks",         "drinks" },
  { "Got smashed",    "smashed" },
  { "Time dancing",   "danced",     ns.FormatTime },
  { "At Gees Vuur",   "fireTime",   ns.FormatTime },
  { "Gees Vuurs lit", "fires" },
}

local function buildStats(page)
  local colX = { 10, 230, 400 }
  local function cell(row, col, text, font)
    local fs = page:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", colX[col], -6 - row * 21)
    fs:SetText(text or "")
    return fs
  end
  local myHead = cell(0, 2, "", "GameFontNormal")
  local budHead = cell(0, 3, "", "GameFontNormal")
  for i = 1, #STAT_ROWS, 2 do
    local band = page:CreateTexture(nil, "BACKGROUND")
    band:SetColorTexture(1, 1, 1, 0.035)
    band:SetPoint("TOPLEFT", 2, -2 - i * 21)
    band:SetPoint("TOPRIGHT", -2, -2 - i * 21)
    band:SetHeight(20)
  end
  local cells = {}
  for i, def in ipairs(STAT_ROWS) do
    cell(i, 1, def[1], "GameFontNormalSmall")
    cells[i] = { cell(i, 2, "-"), cell(i, 3, "-") }
  end

  function page:Refresh()
    local _, myClass = UnitClass("player")
    myHead:SetText("|c" .. ns.ClassColorHex(myClass) .. UnitName("player") .. "|r")
    budHead:SetText(ns.BuddyNameColored())
    local mine, theirs = ns:GetMyStats(), ns.buddy.stats or {}
    for i, def in ipairs(STAT_ROWS) do
      local key, fmt, lowerWins = def[2], def[3], def[4]
      local a, b = mine[key], theirs[key]
      local fa, fb = cells[i][1], cells[i][2]
      fa:SetText(a ~= nil and tostring(fmt and fmt(a, mine) or a) or "-")
      fb:SetText(b ~= nil and tostring(fmt and fmt(b, theirs) or b) or "-")
      fa:SetTextColor(1, 1, 1); fb:SetTextColor(1, 1, 1)
      local ra, rb = tonumber(a), tonumber(b)
      if ra and rb and ra ~= rb and key ~= "xp" then
        if (ra > rb) ~= (lowerWins == true) then fa:SetTextColor(0.3, 1, 0.3) else fb:SetTextColor(0.3, 1, 0.3) end
      end
    end
  end

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

-- Shift-click an item while the wishlist box has focus -> put its link in the box
local function hookInsertLink(tbl, fnName)
  if type(tbl[fnName]) ~= "function" then return end
  hooksecurefunc(tbl, fnName, function(link)
    local box = pages[5] and pages[5].box
    if box and box:HasFocus() and type(link) == "string" then box:SetText(link) end
  end)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function ns:ToggleWindow()
  if not win then return end
  win:SetShown(not win:IsShown())
end

ns:Listen("LOGIN", function()
  win = createWindow()
  local p = ns.db.windowPos
  if p then win:ClearAllPoints(); win:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
  buildOverview(pages[1])
  buildFeed(pages[2])
  buildStats(pages[3])
  buildUpgrades(pages[4])
  buildWishlist(pages[5])
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
