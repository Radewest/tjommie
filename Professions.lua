-- Tjommie: Professions & recipes
-- Shares your professions (with skill levels) and, once you've opened a profession window,
-- the list of recipes you know. Your tjommie can browse and search them in the Crafting tab
-- and click one to ask "can you make this for me?".
--
-- Works with both the modern (C_TradeSkillUI) and Classic (GetTradeSkillInfo / GetCraftInfo)
-- profession APIs, since Forever runs Classic professions on the modern client.
--
-- Recipe entries are compact strings: "i<itemID>" (makes an item) or "s<spellID>" (e.g. enchants).
-- Wire:
--   PF~Name:rank:max,Name:rank:max         professions
--   RC~prof~part~total~entry,entry,...     recipe list in chunks
--   CR~entry                               "can you make this?"
--   CA~entry~1|0                           answer

local _, ns = ...

local CHUNK_CHARS = 200
local PROF_ICON = "Interface\\Icons\\Trade_BlackSmithing"

local PROF_NAMES = {}
for _, n in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Leatherworking",
  "Mining", "Skinning", "Tailoring", "Cooking", "First Aid", "Fishing", "Jewelcrafting", "Inscription" }) do
  PROF_NAMES[n] = true
end

---------------------------------------------------------------------------
-- Skill levels
---------------------------------------------------------------------------
local function scanRanks()
  local out = {}
  if GetProfessions and GetProfessionInfo then
    local list = { GetProfessions() }
    for i = 1, 6 do
      local idx = list[i]
      if idx then
        local ok, name, _, rank, max = pcall(GetProfessionInfo, idx)
        if ok and name then out[name] = { rank = rank or 0, max = max or 0 } end
      end
    end
  end
  if next(out) == nil and GetNumSkillLines and GetSkillLineInfo then
    for i = 1, (GetNumSkillLines() or 0) do
      local name, isHeader, _, rank, _, _, max = GetSkillLineInfo(i)
      if name and not isHeader and PROF_NAMES[name] then out[name] = { rank = rank or 0, max = max or 0 } end
    end
  end
  return out
end

function ns:EncodeProfessions(profs)
  local parts = {}
  for name, p in pairs(profs or {}) do
    table.insert(parts, name:gsub("[,:~|]", "") .. ":" .. (p.rank or 0) .. ":" .. (p.max or 0))
  end
  table.sort(parts)
  return table.concat(parts, ",")
end

function ns:UpdateProfessions(send)
  local profs = scanRanks()
  local encoded = self:EncodeProfessions(profs)
  local changed = encoded ~= self.cdb.professionsSig
  self.cdb.professions = profs
  self.cdb.professionsSig = encoded
  if (changed or send) and encoded ~= "" then self:Send("PF", encoded) end
  if changed then self:Fire("PROFESSIONS_CHANGED") end
end

ns.msgHandlers.PF = function(payload)
  local profs = {}
  for entry in (payload or ""):gmatch("[^,]+") do
    local name, rank, max = entry:match("^(.-):(%d+):(%d+)$")
    if name then profs[name] = { rank = tonumber(rank), max = tonumber(max) } end
  end
  ns.buddy.professions = profs
  ns:Fire("BUDDY_PROFESSIONS")
end

---------------------------------------------------------------------------
-- Recipes (read when you open a profession window)
---------------------------------------------------------------------------
local function entryFromLinks(itemLink, recipeLink, spellID)
  local item = itemLink and itemLink:match("item:(%d+)")
  if item then return "i" .. item end
  local sp = recipeLink and (recipeLink:match("enchant:(%d+)") or recipeLink:match("spell:(%d+)"))
  if sp then return "s" .. sp end
  if spellID then return "s" .. spellID end
end

local function scanModern()
  if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs) then return end
  if C_TradeSkillUI.IsTradeSkillReady and not C_TradeSkillUI.IsTradeSkillReady() then return end
  if C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked() then return end
  if C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild() then return end
  local prof
  if C_TradeSkillUI.GetBaseProfessionInfo then
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    prof = info and info.professionName
  end
  if (not prof or prof == "") and C_TradeSkillUI.GetTradeSkillLine then
    local _, name = C_TradeSkillUI.GetTradeSkillLine()
    prof = name
  end
  if not prof or prof == "" then return end
  local list = {}
  for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
    local r = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(id)
    if r and r.learned then
      local link = C_TradeSkillUI.GetRecipeItemLink and C_TradeSkillUI.GetRecipeItemLink(id)
      local e = entryFromLinks(link, nil, id)
      if e then table.insert(list, e) end
    end
  end
  return prof, list
end

local function scanClassicTradeSkill()
  if not (GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillLine) then return end
  if IsTradeSkillLinked and IsTradeSkillLinked() then return end
  local prof = GetTradeSkillLine()
  if not prof or prof == "" or prof == "UNKNOWN" then return end
  local list = {}
  for i = 1, (GetNumTradeSkills() or 0) do
    local name, kind = GetTradeSkillInfo(i)
    if name and kind ~= "header" and kind ~= "subheader" then
      local e = entryFromLinks(GetTradeSkillItemLink and GetTradeSkillItemLink(i),
                               GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i))
      if e then table.insert(list, e) end
    end
  end
  return prof, list
end

local function scanClassicCraft()
  if not (GetNumCrafts and GetCraftInfo) then return end
  local prof = (GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()) or (GetCraftName and GetCraftName())
  if not prof or prof == "" then return end
  local list = {}
  for i = 1, (GetNumCrafts() or 0) do
    local name, _, kind = GetCraftInfo(i)
    if name and kind ~= "header" then
      local link = GetCraftItemLink and GetCraftItemLink(i)
      local e = entryFromLinks(link, link) or (GetCraftRecipeLink and entryFromLinks(nil, GetCraftRecipeLink(i)))
      if e then table.insert(list, e) end
    end
  end
  return prof, list
end

local function storeRecipes(prof, list)
  if not prof or not list or #list == 0 then return end
  ns.cdb.recipes = ns.cdb.recipes or {}
  local sig = #list .. ":" .. table.concat(list, ",")
  local old = ns.cdb.recipes[prof]
  ns.cdb.recipes[prof] = list
  if not old or (#old .. ":" .. table.concat(old, ",")) ~= sig then
    ns:SendRecipes(prof)
    ns:Fire("PROFESSIONS_CHANGED")
  end
end

local scanTimer
local function queueScan(kind)
  if scanTimer then scanTimer:Cancel() end
  scanTimer = C_Timer.NewTimer(1, function()
    scanTimer = nil
    if kind == "craft" then
      storeRecipes(scanClassicCraft())
    else
      local prof, list = scanModern()
      if not prof then prof, list = scanClassicTradeSkill() end
      storeRecipes(prof, list)
    end
    ns:UpdateProfessions(false)
  end)
end

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE" }) do
  ns:On(ev, function() queueScan("trade") end)
end
for _, ev in ipairs({ "CRAFT_SHOW", "CRAFT_UPDATE" }) do
  ns:On(ev, function() queueScan("craft") end)
end
ns:On("SKILL_LINES_CHANGED", function() ns:UpdateProfessions(false) end)

---------------------------------------------------------------------------
-- Sending / receiving recipe lists (chunked to stay under the message limit)
---------------------------------------------------------------------------
function ns:SendRecipes(prof)
  local list = self.cdb.recipes and self.cdb.recipes[prof]
  if not list or not self.db.buddy then return end
  local chunks, cur = {}, {}
  local len = 0
  for _, e in ipairs(list) do
    if len + #e + 1 > CHUNK_CHARS then
      table.insert(chunks, table.concat(cur, ","))
      cur, len = {}, 0
    end
    table.insert(cur, e)
    len = len + #e + 1
  end
  if #cur > 0 then table.insert(chunks, table.concat(cur, ",")) end
  local safeProf = prof:gsub("[~|,]", "")
  for i, chunk in ipairs(chunks) do
    C_Timer.After((i - 1) * 0.4, function() self:Send("RC", safeProf, i, #chunks, chunk) end)
  end
end

local incoming = {}
ns.msgHandlers.RC = function(prof, part, total, payload)
  part, total = tonumber(part), tonumber(total)
  if not prof or not part or not total then return end
  incoming[prof] = incoming[prof] or { total = total, parts = {} }
  local buf = incoming[prof]
  if buf.total ~= total then buf.total, buf.parts = total, {} end
  buf.parts[part] = payload or ""
  for i = 1, total do if not buf.parts[i] then return end end
  local list = {}
  for i = 1, total do
    for e in buf.parts[i]:gmatch("[^,]+") do table.insert(list, e) end
  end
  incoming[prof] = nil
  ns.buddy.recipes = ns.buddy.recipes or {}
  ns.buddy.recipes[prof] = list
  ns:Fire("BUDDY_PROFESSIONS")
end

ns:Listen("SYNC_REQUEST", function()
  ns:UpdateProfessions(true)
  local i = 0
  for prof in pairs(ns.cdb.recipes or {}) do
    C_Timer.After(1 + i * 2, function() ns:SendRecipes(prof) end)
    i = i + 1
  end
end)
ns:Listen("LOGIN", function() C_Timer.After(6, function() ns:UpdateProfessions(false) end) end)

---------------------------------------------------------------------------
-- Turning entries into names, icons and links
---------------------------------------------------------------------------
local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end
local function spellIcon(id)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  if GetSpellInfo then return select(3, GetSpellInfo(id)) end
end

-- Returns name (coloured link text for items), icon, kind, id. Items may need a moment to load.
function ns.RecipeInfo(entry)
  local kind, id = entry:sub(1, 1), tonumber(entry:sub(2))
  if not id then return entry, nil end
  if kind == "i" then
    local name, link, _, _, _, _, _, _, _, icon = ns.GetItemInfo(id)
    return link or name or ("item " .. id), icon or (C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)), "item", id
  end
  return spellName(id) or ("spell " .. id), spellIcon(id), "spell", id
end

function ns.RecipeTooltip(entry)
  local kind, id = entry:sub(1, 1), tonumber(entry:sub(2))
  if not id then return end
  if kind == "i" then
    pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. id)
  elseif GameTooltip.SetSpellByID then
    pcall(GameTooltip.SetSpellByID, GameTooltip, id)
  end
end

-- Ask for items to load so names appear (call before showing a list)
function ns.PreloadRecipes(list)
  for _, e in ipairs(list or {}) do
    local id = e:sub(1, 1) == "i" and tonumber(e:sub(2))
    if id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
end

---------------------------------------------------------------------------
-- "Can you make this for me?"
---------------------------------------------------------------------------
local function plainName(entry)
  local name = ns.RecipeInfo(entry)
  return (tostring(name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""))
end

function ns:AskCraft(entry)
  if not self.db.buddy then return end
  if not self:IsBuddyOnline() then self:Print(self:BuddyShortName() .. " is offline right now.") return end
  self:Send("CR", entry)
  local name, icon = ns.RecipeInfo(entry)
  self:AddFeed("You asked " .. ns.BuddyNameColored() .. " to make " .. tostring(name) .. ".", false, icon or PROF_ICON)
  self:Toast({ cat = "together", header = "CRAFT REQUEST SENT", icon = icon or PROF_ICON, quality = 2,
    body = "Asked " .. ns.BuddyNameColored() .. " to make " .. tostring(name), sub = "Waiting for an answer..." })
end

StaticPopupDialogs["TJOMMIE_CRAFT_ASK"] = {
  text = "%s",
  button1 = "Sure!",
  button2 = "Can't right now",
  OnAccept = function(_, data) if data then ns:Send("CA", data, 1) end end,
  OnCancel = function(_, data, reason) if data and reason == "clicked" then ns:Send("CA", data, 0) end end,
  timeout = 120,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

ns.msgHandlers.CR = function(entry)
  if not entry or entry == "" then return end
  local name, icon = ns.RecipeInfo(entry)
  ns:AddFeed(ns.BuddyNameColored() .. " asked if you can make " .. tostring(name) .. ".", true, icon or PROF_ICON)
  StaticPopup_Show("TJOMMIE_CRAFT_ASK", "|cff33ff99Tjommie|r\n\n" .. ns.BuddyNameColored()
    .. " asks: can you make\n|cffffd100" .. plainName(entry) .. "|r\nfor them?", nil, entry)
  if ns.db.sound and SOUNDKIT and SOUNDKIT.READY_CHECK then PlaySound(SOUNDKIT.READY_CHECK, "Master") end
end

ns.msgHandlers.CA = function(entry, yes)
  local name, icon = ns.RecipeInfo(entry or "")
  if yes == "1" then
    ns:AddFeed(ns.BuddyNameColored() .. " will make " .. tostring(name) .. " for you!", true, icon or PROF_ICON)
    ns:Toast({ cat = "together", header = "CRAFT REQUEST", icon = icon or PROF_ICON, quality = 3, sound = "LEVELUP",
      body = ns.BuddyNameColored() .. " will make " .. tostring(name), sub = "Send them the materials (or meet up to trade)." })
  else
    ns:AddFeed(ns.BuddyNameColored() .. " can't make " .. tostring(name) .. " right now.", true, icon or PROF_ICON)
    ns:Chat(ns:BuddyShortName() .. " can't make " .. plainName(entry or "") .. " right now.", "important")
  end
end
