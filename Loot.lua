-- Tjommie: Loot
-- Wishlists + class-aware upgrade detection.
--
-- When either of you loots something:
--   * it shows in the feed (green quality and up)
--   * if it's on the other person's wishlist -> alert on both screens
--   * if it looks like an upgrade for the other person's class/level/gear -> alert
-- Class rules (armour type by level, weapon skills, main stats) are built in below,
-- so you never need to maintain item lists by hand.

local _, ns = ...

local MIN_FEED_QUALITY = 2  -- 2 = green, 3 = blue, 4 = purple

---------------------------------------------------------------------------
-- Class rules (Classic-era proficiencies)
---------------------------------------------------------------------------
-- Armour subclass: 1 cloth, 2 leather, 3 mail, 4 plate
local function bestArmor(class, level)
  level = level or 1
  if class == "WARRIOR" or class == "PALADIN" then return level >= 40 and 4 or 3 end
  if class == "HUNTER" or class == "SHAMAN" then return level >= 40 and 3 or 2 end
  if class == "ROGUE" or class == "DRUID" then return 2 end
  if class == "PRIEST" or class == "MAGE" or class == "WARLOCK" then return 1 end
  return nil -- unknown class: don't filter
end
ns.BestArmor = bestArmor

local ARMOR_NAMES = { "Cloth", "Leather", "Mail", "Plate" }
ns.ARMOR_NAMES = ARMOR_NAMES

-- Weapon subclass IDs: 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm,
-- 7 1H sword, 8 2H sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand
local function set(list) local t = {} for _, v in ipairs(list) do t[v] = true end return t end
local WEAPONS = {
  WARRIOR = set{0,1,2,3,4,5,6,7,8,10,13,15,16,18},
  PALADIN = set{0,1,4,5,6,7,8},
  HUNTER  = set{0,1,2,3,6,7,8,10,13,15,16,18},
  ROGUE   = set{2,3,4,7,13,15,16,18},
  PRIEST  = set{4,10,15,19},
  SHAMAN  = set{0,1,4,5,10,13,15},
  MAGE    = set{7,10,15,19},
  WARLOCK = set{7,10,15,19},
  DRUID   = set{4,5,6,10,13,15},
}
local SHIELD_CLASSES   = set{"WARRIOR", "PALADIN", "SHAMAN"}
local HOLDABLE_CLASSES = set{"PRIEST", "MAGE", "WARLOCK", "DRUID", "SHAMAN", "PALADIN"}

-- Main stats each class cares about. Items with main stats but none of these get skipped.
local MAIN_STATS = {
  WARRIOR = set{"STR", "AGI"},
  PALADIN = set{"STR", "INT"},
  HUNTER  = set{"AGI", "INT"},
  ROGUE   = set{"AGI", "STR"},
  PRIEST  = set{"INT", "SPI"},
  SHAMAN  = set{"INT", "STR", "AGI"},
  MAGE    = set{"INT", "SPI"},
  WARLOCK = set{"INT", "SPI"},
  DRUID   = set{"INT", "AGI", "STR", "SPI"},
}
local STAT_KEYS = {
  ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI",
  ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI",
}

-- Equip location -> inventory slot(s)
local RANGED = INVSLOT_RANGED or 18
local EQUIP_SLOTS = {
  INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CHEST = {5},
  INVTYPE_ROBE = {5}, INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8},
  INVTYPE_WRIST = {9}, INVTYPE_HAND = {10}, INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14},
  INVTYPE_CLOAK = {15}, INVTYPE_WEAPON = {16, 17}, INVTYPE_2HWEAPON = {16},
  INVTYPE_WEAPONMAINHAND = {16}, INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17},
  INVTYPE_HOLDABLE = {17}, INVTYPE_RANGED = {RANGED}, INVTYPE_RANGEDRIGHT = {RANGED},
  INVTYPE_THROWN = {RANGED},
}
local GEAR_SLOTS = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,RANGED}

---------------------------------------------------------------------------
-- Upgrade evaluation (works for you OR your buddy)
-- who = { class = "MAGE", level = 20, gear = { [slot] = ilvl } }
-- returns isUpgrade, reasonText
---------------------------------------------------------------------------
function ns:EvaluateFor(itemID, who)
  local name, link, quality, ilvl, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID =
    ns.GetItemInfo(itemID)
  if not name then return false end
  local slots = EQUIP_SLOTS[equipLoc]
  if not slots then return false end

  local class, level = who.class, who.level or 1
  if (reqLevel or 0) > level + 3 then return false end

  -- Can they use it?
  if classID == 4 then -- armour
    if equipLoc == "INVTYPE_SHIELD" then
      if class and not SHIELD_CLASSES[class] then return false end
    elseif equipLoc == "INVTYPE_HOLDABLE" then
      if class and not HOLDABLE_CLASSES[class] then return false end
    elseif subclassID and subclassID >= 1 and subclassID <= 4 and equipLoc ~= "INVTYPE_CLOAK" then
      local best = bestArmor(class, level)
      if best and subclassID ~= best then return false end
    end
  elseif classID == 2 then -- weapon
    local allowed = class and WEAPONS[class]
    if allowed and not allowed[subclassID] then return false end
  end

  -- Does it have stats they care about?
  local wanted = class and MAIN_STATS[class]
  if wanted and ns.GetItemStats and link then
    local stats = ns.GetItemStats(link)
    if stats then
      local hasMain, hasWanted = false, false
      for key in pairs(stats) do
        local s = STAT_KEYS[key]
        if s then
          hasMain = true
          if wanted[s] then hasWanted = true end
        end
      end
      if hasMain and not hasWanted then return false end
    end
  end

  -- Better than what they wear? (compare against the weakest matching slot)
  local gear = who.gear or {}
  local worst = nil
  for _, slot in ipairs(slots) do
    local cur = gear[slot] or 0
    if not worst or cur < worst then worst = cur end
  end
  ilvl = ilvl or 0
  if worst and ilvl > worst then
    if worst == 0 then return true, "empty slot" end
    return true, string.format("+%d item level", ilvl - worst)
  end
  return false
end

function ns:GetMyGear()
  local gear = {}
  for _, slot in ipairs(GEAR_SLOTS) do
    local link = GetInventoryItemLink("player", slot)
    if link then
      local ilvl = ns.GetDetailedItemLevelInfo and ns.GetDetailedItemLevelInfo(link)
      if not ilvl then ilvl = select(4, ns.GetItemInfo(link)) end
      gear[slot] = ilvl or 0
    end
  end
  return gear
end

function ns:Me()
  local _, class = UnitClass("player")
  return { class = class, level = UnitLevel("player"), gear = self:GetMyGear() }
end

function ns:Buddy()
  local info = self.buddy.info
  return { class = info.class, level = info.level, gear = self.buddy.gear }
end

---------------------------------------------------------------------------
-- Gear sync
---------------------------------------------------------------------------
function ns:SendGear()
  local parts = {}
  for slot, ilvl in pairs(self:GetMyGear()) do
    table.insert(parts, slot .. ":" .. ilvl)
  end
  self:Send("G", table.concat(parts, ","))
end

ns.msgHandlers.G = function(payload)
  local gear = {}
  for slot, ilvl in (payload or ""):gmatch("(%d+):(%d+)") do
    gear[tonumber(slot)] = tonumber(ilvl)
  end
  ns.buddy.gear = gear
end

local gearTimer
ns:On("PLAYER_EQUIPMENT_CHANGED", function()
  if gearTimer then gearTimer:Cancel() end
  gearTimer = C_Timer.NewTimer(2, function() ns:SendGear() end)
end)

ns:Listen("SYNC_REQUEST", function()
  ns:SendGear()
  ns:SendWishlist()
end)

---------------------------------------------------------------------------
-- Wishlist
---------------------------------------------------------------------------
local function parseItemID(text)
  if not text then return nil end
  return tonumber(text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
end
ns.ParseItemID = parseItemID

local function contains(list, id)
  for i, v in ipairs(list) do if v == id then return i end end
end

function ns:AddWish(text)
  local id = parseItemID(text)
  if not id then self:Print("Shift-click an item into the command, e.g. /tj wish [Item], or use an item ID.") return end
  if contains(self.cdb.wishlist, id) then return end
  table.insert(self.cdb.wishlist, id)
  self:SendWishlist()
  self:Fire("WISHLIST_CHANGED")
  local item = Item:CreateFromItemID(id)
  item:ContinueOnItemLoad(function()
    self:Print("Added " .. (item:GetItemLink() or id) .. " to your wishlist.")
  end)
end

function ns:RemoveWish(text)
  local id = type(text) == "number" and text or parseItemID(text)
  local idx = id and contains(self.cdb.wishlist, id)
  if not idx then return end
  table.remove(self.cdb.wishlist, idx)
  self:SendWishlist()
  self:Fire("WISHLIST_CHANGED")
end

function ns:SendWishlist()
  self:Send("W", table.concat(self.cdb.wishlist, ","))
end

ns.msgHandlers.W = function(payload)
  local list = {}
  for id in (payload or ""):gmatch("%d+") do table.insert(list, tonumber(id)) end
  ns.buddy.wishlist = list
  ns:Fire("WISHLIST_CHANGED")
end

---------------------------------------------------------------------------
-- My loot (parse loot chat)
---------------------------------------------------------------------------
local function toPattern(fmt)
  if not fmt then return nil end
  return "^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
end
local SELF_LOOT = {}
for _, g in ipairs({ LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF, LOOT_ITEM_PUSHED_SELF_MULTIPLE }) do
  local p = toPattern(g)
  if p then table.insert(SELF_LOOT, p) end
end

local function isSelfLoot(msg)
  for _, p in ipairs(SELF_LOOT) do
    if msg:match(p) then return true end
  end
  return false
end

local function bindNote(bindType)
  if bindType == 1 then return " |cff999999(soulbound)|r" end
  return " |cff00ff00(tradeable - mail it!)|r"
end

local function itemIcon(itemID)
  return (C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or select(10, ns.GetItemInfo(itemID))
end

local function onMyLoot(itemID)
  local item = Item:CreateFromItemID(itemID)
  item:ContinueOnItemLoad(function()
    local _, link, quality, _, _, _, _, _, _, _, _, _, _, bindType = ns.GetItemInfo(itemID)
    quality = quality or 0
    link = link or ("item " .. itemID)
    if quality == 3 then ns.cdb.stats.rares = ns.cdb.stats.rares + 1 end
    if quality >= 4 then ns.cdb.stats.epics = ns.cdb.stats.epics + 1 end
    if quality < MIN_FEED_QUALITY then return end

    local icon = itemIcon(itemID)
    ns:Send("E", "LOOT", itemID)
    ns:AddFeed("You looted " .. link .. ".", false, icon)

    if not ns.db.buddy then return end
    local tradeable = bindType ~= 1
    if contains(ns.buddy.wishlist, itemID) then
      ns:Toast({ header = "ON " .. ns:BuddyShortName():upper() .. "'S WISHLIST", icon = icon, quality = quality, sound = "WISH",
        body = "You looted " .. link, sub = tradeable and "Tradeable - mail it to them!" or "|cff999999Soulbound, sadly.|r" })
      ns:AddFeed("  -> on " .. ns.BuddyNameColored() .. "'s wishlist!" .. bindNote(bindType), false, icon)
    elseif tradeable then
      local up, why = ns:EvaluateFor(itemID, ns:Buddy())
      if up then
        ns:Toast({ header = "UPGRADE FOR " .. ns:BuddyShortName():upper(), icon = icon, quality = quality, sound = "UPGRADE",
          body = "You looted " .. link, sub = why .. " for " .. ns:BuddyShortName() .. " - mail it!" })
        ns:AddFeed("  -> possible upgrade for " .. ns.BuddyNameColored() .. " (" .. why .. ")" .. bindNote(bindType), false, icon)
      end
    end
  end)
end

ns:On("CHAT_MSG_LOOT", function(msg)
  if not msg or ns.IsSecret(msg) then return end
  if not isSelfLoot(msg) then return end
  local id = tonumber(msg:match("item:(%d+)"))
  if id then onMyLoot(id) end
end)

---------------------------------------------------------------------------
-- Buddy loot
---------------------------------------------------------------------------
ns.buddyEventHandlers.LOOT = function(itemID)
  itemID = tonumber(itemID)
  if not itemID then return end
  local item = Item:CreateFromItemID(itemID)
  item:ContinueOnItemLoad(function()
    local _, link, quality, _, _, _, _, _, _, _, _, _, _, bindType = ns.GetItemInfo(itemID)
    link = link or ("item " .. itemID)
    local icon = itemIcon(itemID)
    ns:AddFeed(ns.BuddyNameColored() .. " looted " .. link .. ".", true, icon)

    if contains(ns.cdb.wishlist, itemID) then
      ns:Toast({ header = "FROM YOUR WISHLIST", icon = icon, quality = quality, sound = "WISH",
        body = ns.BuddyNameColored() .. " looted " .. link,
        sub = bindType ~= 1 and "Tradeable - ask for it!" or "|cff999999Soulbound, sadly.|r" })
    elseif bindType ~= 1 then
      local up, why = ns:EvaluateFor(itemID, ns:Me())
      if up then
        ns:Toast({ header = "UPGRADE FOR YOU", icon = icon, quality = quality, sound = "UPGRADE",
          body = ns.BuddyNameColored() .. " looted " .. link, sub = why .. " - tradeable, ask for it!" })
      end
    end
  end)
end
