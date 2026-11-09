-- Tjommie: Toasts
-- Loot-alert style pop-ups: icon with quality-coloured border, small header, body, sub-line.
-- Up to 3 stack at once; each fades after a few seconds. Click to dismiss.
--
-- ns:Toast({ header=, body=, sub=, icon=, quality=, sound= })

local _, ns = ...

local MAX_TOASTS = 3
local LIFETIME = 7
local active = {}
local pool = {}

local SOUNDS = {
  LEVELUP = SOUNDKIT and SOUNDKIT.UI_PERSONAL_BEST,
  DEATH   = SOUNDKIT and SOUNDKIT.RAID_WARNING,
  WISH    = SOUNDKIT and (SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.UI_LEGENDARY_LOOT_TOAST),
  UPGRADE = SOUNDKIT and (SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.UI_LEGENDARY_LOOT_TOAST),
}

local function qualityColor(q)
  q = q or 1
  if C_Item and C_Item.GetItemQualityColor then
    local r, g, b = C_Item.GetItemQualityColor(q)
    if r then return r, g, b end
  end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return 1, 0.82, 0
end

local function layout()
  for i, t in ipairs(active) do
    t:ClearAllPoints()
    t:SetPoint("TOP", UIParent, "TOP", 0, -170 - (i - 1) * 70)
  end
end

local function release(t)
  t:Hide()
  for i, a in ipairs(active) do
    if a == t then table.remove(active, i) break end
  end
  table.insert(pool, t)
  layout()
end

local function create()
  local t = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  t:SetSize(400, 62)
  t:SetFrameStrata("HIGH")
  t:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  t:SetBackdropColor(0.04, 0.04, 0.05, 0.94)

  t.iconFrame = CreateFrame("Frame", nil, t, "BackdropTemplate")
  t.iconFrame:SetSize(44, 44)
  t.iconFrame:SetPoint("LEFT", 10, 0)
  t.iconFrame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  t.icon = t.iconFrame:CreateTexture(nil, "ARTWORK")
  t.icon:SetPoint("TOPLEFT", 2, -2)
  t.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  t.header = t:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  t.header:SetPoint("TOPLEFT", t.iconFrame, "TOPRIGHT", 10, -1)
  t.header:SetPoint("RIGHT", -10, 0)
  t.header:SetJustifyH("LEFT")

  t.body = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t.body:SetPoint("TOPLEFT", t.header, "BOTTOMLEFT", 0, -3)
  t.body:SetPoint("RIGHT", -10, 0)
  t.body:SetJustifyH("LEFT")
  t.body:SetWordWrap(false)

  t.sub = t:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
  t.sub:SetPoint("TOPLEFT", t.body, "BOTTOMLEFT", 0, -3)
  t.sub:SetPoint("RIGHT", -10, 0)
  t.sub:SetJustifyH("LEFT")
  t.sub:SetWordWrap(false)

  t:SetScript("OnClick", release)
  t:SetScript("OnUpdate", function(self, dt)
    self.age = self.age + dt
    if self.age < 0.25 then
      self:SetAlpha(self.age / 0.25)
    elseif self.age > LIFETIME then
      local a = 1 - (self.age - LIFETIME) / 0.8
      if a <= 0 then release(self) else self:SetAlpha(a) end
    else
      self:SetAlpha(1)
    end
  end)
  return t
end

-- Pop-up categories (each can be switched off in Settings)
local SOUND_CATEGORY = { LEVELUP = "level", DEATH = "death", WISH = "loot", UPGRADE = "loot" }

function ns:Toast(opts, kind)
  -- Back-compat: ns:Toast("text", "KIND")
  if type(opts) == "string" then opts = { body = opts, sound = kind } end
  local cat = opts.cat or SOUND_CATEGORY[opts.sound or ""] or "other"
  local text = (opts.body or "") .. (opts.sub and opts.sub ~= "" and ("  " .. opts.sub) or "")

  local popups = self.db.popups or {}
  local wanted = self.db.toasts and (cat == "other" or popups[cat] ~= false)
  if not wanted then
    -- Pop-up switched off: fall back to a chat line only if chat is set to Everything
    self:Chat(text, "all")
    return
  end
  -- Pop-up shown: only echo to chat when chat is set to Everything (this was the old spam)
  self:Chat(text, "all")

  if #active >= MAX_TOASTS then release(active[#active]) end
  local t = table.remove(pool) or create()
  local r, g, b = qualityColor(opts.quality)
  t.iconFrame:SetBackdropBorderColor(r, g, b, 1)
  t:SetBackdropBorderColor(r, g, b, 0.9)
  t.icon:SetTexture(opts.icon or "Interface\\AddOns\\Tjommie\\media\\icon")
  t.header:SetText("|cff33ff99TJOMMIE|r  |cff777777·|r  " .. (opts.header or ""))
  t.body:SetText(opts.body or "")
  t.sub:SetText(opts.sub or "")
  t.age = 0
  t:SetAlpha(0)
  table.insert(active, 1, t)
  layout()
  t:Show()

  if self.db.sound and opts.sound and SOUNDS[opts.sound] then
    PlaySound(SOUNDS[opts.sound], "Master")
  end
end
