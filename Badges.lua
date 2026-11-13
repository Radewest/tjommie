-- Tjommie: Badges
-- Shared achievements for you and your tjommie. Most are earned together and appear on both
-- screens (B message); level races record who got there first.
-- Stored per tjommie in TjommieCharDB.pairs[buddy] = { together, fireTogether, danceTogether, badges = { id = { t, winner } } }
--
-- Wire: B~id~winner

local _, ns = ...

local ICON = "Interface\\AddOns\\Tjommie\\media\\icon"

ns.BADGES = {
  { id = "linked",     name = "Howzit, Tjommie",   desc = "Link up as tjommies",                              icon = ICON },
  { id = "met",        name = "Finally Met",       desc = "Be within 40 yards of each other",                 icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing" },
  { id = "party",      name = "Party Up",          desc = "Group up together",                                icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
  { id = "reunited",   name = "Reunited",          desc = "Meet up at a meeting point",                       icon = "Interface\\Icons\\INV_Misc_Spyglass_02" },
  { id = "hour",       name = "Joined at the Hip", desc = "Spend 1 hour near each other",                     icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
  { id = "tenhours",   name = "Ride or Die",       desc = "Spend 10 hours near each other",                   icon = "Interface\\Icons\\INV_Misc_PocketWatch_02" },
  { id = "fire",       name = "Gees Vuur Gesels",  desc = "Sit at a Gees Vuur together for 5 minutes",        icon = "Interface\\Icons\\Spell_Fire_Fire" },
  { id = "dance",      name = "Dance-off",         desc = "Dance together for 10 seconds",                    icon = "Interface\\Icons\\Spell_Shadow_Charm" },
  { id = "drinks",     name = "Drinking Buddies",  desc = "Both get completely smashed within 15 minutes",    icon = "Interface\\Icons\\INV_Drink_05" },
  { id = "samefate",   name = "Same Fate",         desc = "Both die within a minute of each other",           icon = "Interface\\Icons\\Ability_Rogue_FeignDeath" },
  { id = "dungeon",    name = "Dungeon Duo",       desc = "Be in the same dungeon together",                  icon = "Interface\\Icons\\INV_Misc_Key_03" },
  { id = "distance",   name = "Long Way Round",    desc = "Travel 100,000 yards between you",                 icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
  { id = "quests",     name = "Quest Machines",    desc = "Complete 250 quests between you (since Tjommie)",  icon = "Interface\\Icons\\INV_Misc_Book_09" },
}
local BY_ID = {}
for _, b in ipairs(ns.BADGES) do BY_ID[b.id] = b end

ns.RACE_LEVELS = { 10, 20, 30, 40, 50, 60 }

---------------------------------------------------------------------------
-- Per-tjommie storage
---------------------------------------------------------------------------
function ns:PairData()
  local key = (self.db.buddy or ""):lower()
  if key == "" then return nil end
  self.cdb.pairs = self.cdb.pairs or {}
  local p = self.cdb.pairs[key]
  if not p then
    p = { together = 0, fireTogether = 0, danceTogether = 0, badges = {} }
    self.cdb.pairs[key] = p
  end
  return p
end

function ns:HasBadge(id)
  local p = self:PairData()
  return p and p.badges[id] ~= nil
end

-- Award a badge (shared with the tjommie unless it came from them)
function ns:AwardBadge(id, winner, fromWire, quiet)
  if self.demoActive and not fromWire then return end
  local p = self:PairData()
  if not p or p.badges[id] then return end
  p.badges[id] = { t = time(), winner = winner }
  self:Fire("BADGES_CHANGED", id)
  if not fromWire then self:Send("B", id, winner or "") end

  local title, desc, icon
  local race = id:match("^race(%d+)$")
  if race then
    title = "Race to " .. race
    local who = (winner and winner ~= "") and winner or "?"
    desc = (who == UnitName("player")) and ("You beat " .. self:BuddyShortName() .. " to level " .. race .. "!")
      or (who .. " got to level " .. race .. " first")
    icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight"
  else
    local b = BY_ID[id]
    if not b then return end
    title, desc, icon = b.name, b.desc, b.icon
  end
  self:AddFeed("Badge unlocked: |cffffd100" .. title .. "|r. " .. desc, fromWire, icon)
  if quiet then return end
  self:Toast({ cat = "together", header = "TJOMMIE BADGE", icon = icon, quality = 4, sound = "LEVELUP",
    body = "|cffffd100" .. title .. "|r", sub = desc })
end

ns.msgHandlers.B = function(id, winner)
  if id and id ~= "" then ns:AwardBadge(id, winner, true) end
end

-- Badge sync: on login/online both sides send their full list, so badges missed while
-- messages were blocked (dungeons) or while one of you was offline catch up.
-- Wire: BL~id:winner,id,id...
function ns:SendBadgeList()
  local p = self:PairData()
  if not p then return end
  local parts = {}
  for id, b in pairs(p.badges) do
    table.insert(parts, (b.winner and b.winner ~= "") and (id .. ":" .. b.winner) or id)
  end
  if #parts > 0 then self:Send("BL", table.concat(parts, ",")) end
end

ns.msgHandlers.BL = function(list)
  for entry in (list or ""):gmatch("[^,]+") do
    local id, winner = entry:match("^([^:]+):?(.*)$")
    if id then ns:AwardBadge(id, winner, true, true) end
  end
end

ns:Listen("SYNC_REQUEST", function() ns:SendBadgeList() end)

---------------------------------------------------------------------------
-- Level races
---------------------------------------------------------------------------
local function checkRaces()
  if not ns.db.buddy then return end
  local mine, theirs = UnitLevel("player"), ns.buddy.info.level
  if not theirs then return end
  for _, L in ipairs(ns.RACE_LEVELS) do
    local id = "race" .. L
    if not ns:HasBadge(id) then
      if mine >= L and theirs < L then
        ns:AwardBadge(id, UnitName("player"))
      end
      -- (if they got there first, their side awards it and sends it to us)
    end
  end
end
ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(1, checkRaces) end)
ns:Listen("BUDDY_INFO", checkRaces)

---------------------------------------------------------------------------
-- Being together: time, fire, dancing, first meeting
---------------------------------------------------------------------------
local TICK = 2

-- "Are we together?" Works outdoors (positions) AND in dungeons/groups, where positions are
-- hidden and add-on messages can be blocked: there we ask the game about the party unit.
-- Returns near (~100 yd), close (~40 yd)
local function togetherness()
  local d = ns.nav and ns.nav.buddyDist
  local near, close = d and d < 100, d and d < 40
  local unit = ns:BuddyUnit()
  if unit then
    if UnitIsVisible and UnitIsVisible(unit) then near = true end
    if UnitInRange then
      local inRange, checked = UnitInRange(unit)
      if inRange and (checked == nil or checked) and not ns.IsSecret(inRange) then close = true end
    end
  end
  return near, close, unit
end
ns.Togetherness = togetherness

local function inDungeon()
  if not IsInInstance then return false end
  local inInstance, kind = IsInInstance()
  return inInstance and (kind == "party" or kind == "raid")
end

ns:Listen("LOGIN", function()
  C_Timer.NewTicker(TICK, function()
    if not ns.db.buddy or ns.demoActive then return end
    local p = ns:PairData()
    if not p then return end

    -- Combined totals (since Tjommie) - don't need to be near each other
    local mine, theirs = ns.cdb.stats, ns.buddy.stats or {}
    if (mine.distance or 0) + (tonumber(theirs.distance) or 0) >= 100000 then ns:AwardBadge("distance") end
    if (mine.quests or 0) + (tonumber(theirs.quests) or 0) >= 250 then ns:AwardBadge("quests") end

    local near, close, unit = togetherness()
    if close then ns:AwardBadge("met") end
    if near then
      p.together = p.together + TICK
      if p.together >= 3600 then ns:AwardBadge("hour") end
      if p.together >= 36000 then ns:AwardBadge("tenhours") end
      -- Same dungeon: grouped, both inside, and they're in sight
      if unit and inDungeon() then ns:AwardBadge("dungeon") end
    end

    local st = ns.buddy.status and ns.buddy.status.code
    if close and st == "FIRE" and ns.IsAtFire and ns:IsAtFire() then
      p.fireTogether = p.fireTogether + TICK
      if p.fireTogether >= 300 then ns:AwardBadge("fire") end
    end
    if close and st == "DANCE" and ns.IsDancing and ns:IsDancing() then
      p.danceTogether = p.danceTogether + TICK
      if p.danceTogether >= 10 then ns:AwardBadge("dance") end
    end
  end)
end)

ns:Listen("BUDDY_ONLINE", function() ns:AwardBadge("linked") end)
ns:Listen("REUNITED", function() ns:AwardBadge("reunited") end)

-- The party/raid unit token of my tjommie ("party1", "raid7"...), or nil
function ns:BuddyUnit()
  local buddy = self.db.buddy
  if not buddy then return nil end
  for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
    local unit = "party" .. i
    if ns.SameName(GetUnitName(unit, true), buddy) then return unit end
  end
  if IsInRaid and IsInRaid() then
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
      local unit = "raid" .. i
      if ns.SameName(GetUnitName(unit, true), buddy) then return unit end
    end
  end
  return nil
end

-- Party up
function ns:IsGroupedWithBuddy()
  return self:BuddyUnit() ~= nil
end
ns:On("GROUP_ROSTER_UPDATE", function()
  if ns:IsGroupedWithBuddy() then ns:AwardBadge("party") end
end)

-- Same dungeon at the same time
local function checkDungeon()
  local mine, theirs = ns.myStatus, ns.buddy.status
  if mine and theirs and mine.code == "INSTANCE" and theirs.code == "INSTANCE"
     and mine.extra ~= "" and mine.extra == theirs.extra then
    ns:AwardBadge("dungeon")
  end
end
ns:Listen("MY_STATUS", checkDungeon)
ns:Listen("BUDDY_STATUS", checkDungeon)

-- "Within N seconds of each other" moments
local myDeath, theirDeath, mySmashed, theirSmashed = 0, 0, 0, 0
ns:On("PLAYER_DEAD", function()
  myDeath = time()
  if time() - theirDeath <= 60 then ns:AwardBadge("samefate") end
end)
ns:Listen("MY_SMASHED", function()
  mySmashed = time()
  if time() - theirSmashed <= 900 then ns:AwardBadge("drinks") end
end)

-- Wrap the buddy event handlers (Tracker.lua / Fun.lua) to note their timing
local function wrap(kind, fn)
  local orig = ns.buddyEventHandlers[kind]
  ns.buddyEventHandlers[kind] = function(...)
    if orig then orig(...) end
    fn(...)
  end
end
wrap("DEAD", function()
  theirDeath = time()
  if time() - myDeath <= 60 then ns:AwardBadge("samefate") end
end)
wrap("SMASHED", function()
  theirSmashed = time()
  if time() - mySmashed <= 900 then ns:AwardBadge("drinks") end
end)

-- Badge count + race score for the UI
function ns:BadgeSummary()
  local p = self:PairData()
  local earned, total = 0, #ns.BADGES
  local me, them = 0, 0
  if p then
    for _, b in ipairs(ns.BADGES) do if p.badges[b.id] then earned = earned + 1 end end
    for _, L in ipairs(ns.RACE_LEVELS) do
      local r = p.badges["race" .. L]
      if r then
        if r.winner == UnitName("player") then me = me + 1 else them = them + 1 end
      end
    end
  end
  return earned, total, me, them
end
