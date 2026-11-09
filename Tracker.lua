-- Tjommie: Tracker
-- Tracks your position, trail, stats and milestones, shares them with your buddy,
-- and stores what your buddy shares back. Also owns the activity feed data.

local _, ns = ...

local POS_INTERVAL   = 2      -- seconds between position samples
local TRAIL_STEP     = 20     -- yards moved before a new trail point is stored
local TRAIL_MAX      = 1500   -- points kept per trail
local FEED_MAX       = 200
local MAX_JUMP       = 120    -- ignore distance jumps larger than this per sample (hearth/teleport)

-- Feed / toast icons (all present since the original game)
local ICONS = {
  LEVEL  = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
  ZONE   = "Interface\\Icons\\INV_Misc_Map_01",
  QUEST  = "Interface\\Icons\\INV_Misc_Note_01",
  DEATH  = "Interface\\Icons\\Spell_Shadow_DeathScream",
  ONLINE = "Interface\\FriendsFrame\\StatusIcon-Online",
}
ns.ICONS = ICONS

---------------------------------------------------------------------------
-- Activity feed
---------------------------------------------------------------------------
function ns:AddFeed(text, fromBuddy, icon)
  local feed = self.cdb.feed
  table.insert(feed, { t = time(), text = text, b = fromBuddy and true or false, icon = icon })
  while #feed > FEED_MAX do table.remove(feed, 1) end
  self:Fire("FEED_ADDED", feed[#feed])
end

local function buddyName()
  local class = ns.buddy.info.class
  return "|c" .. ns.ClassColorHex(class) .. ns:BuddyShortName() .. "|r"
end
ns.BuddyNameColored = buddyName

---------------------------------------------------------------------------
-- Trails
---------------------------------------------------------------------------
local function yardsBetween(c1, x1, y1, c2, x2, y2)
  if not (c1 and c2 and x1 and x2) or c1 ~= c2 then return nil end
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end
ns.YardsBetween = yardsBetween

local function addTrailPoint(trail, c, wx, wy)
  local last = trail[#trail]
  if last then
    local d = yardsBetween(last.c, last.x, last.y, c, wx, wy)
    if d and d < TRAIL_STEP then return false end
  end
  table.insert(trail, { c = c, x = wx, y = wy, t = time() })
  local max = (ns.db and ns.db.trailLength) or TRAIL_MAX
  while #trail > max do table.remove(trail, 1) end
  return true
end

---------------------------------------------------------------------------
-- My position loop
---------------------------------------------------------------------------
local lastSample = nil  -- {c, wx, wy}
local lastSentAt = 0
local lastSentKey = nil

local function positionTick()
  local stats = ns.cdb.stats
  stats.played = stats.played + POS_INTERVAL

  local mapID, x, y, c, wx, wy = ns.GetPlayerPos()
  if not mapID then return end

  -- Distance travelled
  if lastSample and wx then
    local d = yardsBetween(lastSample.c, lastSample.wx, lastSample.wy, c, wx, wy)
    if d and d < MAX_JUMP then stats.distance = stats.distance + d end
  end
  lastSample = { c = c, wx = wx, wy = wy }

  if wx and addTrailPoint(ns.cdb.myTrail, c, wx, wy) and ns.db.showMyTrail then
    ns:Fire("TRAIL_CHANGED")
  end

  -- Share position: when moved, or every 10s as a heartbeat
  if ns.db.buddy and not ns.db.sharePosition then
    -- Privacy: position paused. Keep a heartbeat so we still show as online.
    if GetTime() - lastSentAt > 10 then
      ns:Send("P", 0)
      lastSentKey, lastSentAt = nil, GetTime()
    end
  elseif ns.db.buddy then
    local key = string.format("%d:%.3f:%.3f", mapID, x, y)
    local now = GetTime()
    if key ~= lastSentKey or now - lastSentAt > 10 then
      ns:Send("P", mapID, string.format("%.4f", x), string.format("%.4f", y),
              GetZoneText() or "", GetSubZoneText() or "")
      lastSentKey, lastSentAt = key, now
    end
  end
end

ns:Listen("LOGIN", function()
  ns.lastMoney = GetMoney()
  ns.lastZone = GetZoneText()
  C_Timer.NewTicker(POS_INTERVAL, positionTick)
  C_Timer.NewTicker(60, function() ns:SendStats() end)
end)

---------------------------------------------------------------------------
-- Buddy position
---------------------------------------------------------------------------
ns.msgHandlers.P = function(mapID, x, y, zone, subzone)
  if mapID == "0" then
    -- Tjommie paused sharing their position
    ns.buddy.pos = { hidden = true, zone = ns.buddy.pos and ns.buddy.pos.zone, t = time() }
    ns:Fire("BUDDY_POS")
    return
  end
  mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
  if not (mapID and x and y) then return end
  local c, wx, wy = ns.MapToWorld(mapID, x, y)
  ns.buddy.pos = {
    mapID = mapID, x = x, y = y, zone = zone, subzone = subzone,
    c = c, wx = wx, wy = wy, t = time(),
  }
  if wx and addTrailPoint(ns.buddy.trail, c, wx, wy) then
    ns:Fire("TRAIL_CHANGED")
  end
  ns:Fire("BUDDY_POS")
end

---------------------------------------------------------------------------
-- Stats
---------------------------------------------------------------------------
local STAT_KEYS = {
  "goldEarned", "kills", "deaths", "quests", "zones", "distance", "rares", "epics", "played",
  "drinks", "smashed", "danced", "fireTime", "fires",
}

function ns:GetMyStats()
  local s = {}
  for _, k in ipairs(STAT_KEYS) do s[k] = math.floor(self.cdb.stats[k] or 0) end
  s.level = UnitLevel("player")
  s.gold = GetMoney()
  local _, class = UnitClass("player")
  s.class = class
  s.zone = GetZoneText()
  s.xp = UnitXP("player")
  s.xpMax = UnitXPMax("player")
  for k, v in pairs(self.cdb.lifetime or {}) do s[k] = v end
  return s
end

-- Compact wire format: values in a fixed order (keeps us under the 255-byte message limit)
local WIRE = { "class", "level", "xp", "xpMax", "gold",
  "goldEarned", "kills", "deaths", "quests", "zones", "distance", "rares", "epics", "played",
  "drinks", "smashed", "danced", "fireTime", "fires",
  -- v0.4: lifetime stats from the game (appended, so older versions still read the fields above)
  "playedTotal", "questsTotal", "killsTotal", "deathsTotal", "drinksTotal" }

function ns.EncodeStats(s)
  local out = {}
  for i, k in ipairs(WIRE) do out[i] = tostring(s[k] or "") end
  return table.concat(out, ",")
end

function ns:SendStats()
  if not self.db.buddy then return end
  local s = self:GetMyStats()
  if self.db.hideGold then s.gold, s.goldEarned = nil, nil end
  self:Send("S", ns.EncodeStats(s))
end

ns.msgHandlers.S = function(payload)
  if not payload then return end
  local stats, i = {}, 0
  for v in (payload .. ","):gmatch("([^,]*),") do
    i = i + 1
    local k = WIRE[i]
    if k and v ~= "" then stats[k] = tonumber(v) or v end
  end
  ns.buddy.stats = stats
  if stats.class then ns.buddy.info.class = stats.class end
  if stats.level then ns.buddy.info.level = stats.level end
  ns:Fire("BUDDY_STATS")
end

ns:Listen("SYNC_REQUEST", function()
  ns:SendStats()
end)

---------------------------------------------------------------------------
-- My milestones -> stats + feed + buddy
---------------------------------------------------------------------------
-- Share XP changes (throttled) so the XP bars stay live
local xpPending = false
ns:On("PLAYER_XP_UPDATE", function()
  if xpPending then return end
  xpPending = true
  C_Timer.After(8, function() xpPending = false; ns:SendStats() end)
end)

ns:On("PLAYER_LEVEL_UP", function(level)
  ns:AddFeed("You reached level " .. level .. "!", false, ICONS.LEVEL)
  ns:Send("E", "LVL", level)
  C_Timer.After(1, function() ns:SendStats() end)
end)

ns:On("ZONE_CHANGED_NEW_AREA", function()
  local zone = GetZoneText()
  if not zone or zone == "" or zone == ns.lastZone then return end
  ns.lastZone = zone
  local isNew = not ns.cdb.zonesSeen[zone]
  if isNew then
    ns.cdb.zonesSeen[zone] = true
    ns.cdb.stats.zones = ns.cdb.stats.zones + 1
  end
  ns:Send("E", "ZONE", zone, isNew and 1 or 0)
end)

ns:On("PLAYER_DEAD", function()
  ns.cdb.stats.deaths = ns.cdb.stats.deaths + 1
  local zone = GetZoneText() or ""
  ns:AddFeed("You died in " .. zone .. ".", false, ICONS.DEATH)
  ns:Send("E", "DEAD", zone)
end)

ns:On("QUEST_TURNED_IN", function(questID)
  ns.cdb.stats.quests = ns.cdb.stats.quests + 1
  local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
  ns:Send("E", "QUEST", title or ("Quest " .. tostring(questID)))
end)

ns:On("PLAYER_MONEY", function()
  local now = GetMoney()
  local delta = now - (ns.lastMoney or now)
  if delta > 0 then ns.cdb.stats.goldEarned = ns.cdb.stats.goldEarned + delta end
  ns.lastMoney = now
end)

-- "X dies, you gain N experience." -> counts as a kill
local killPattern
if COMBATLOG_XPGAIN_FIRSTPERSON then
  killPattern = "^" .. COMBATLOG_XPGAIN_FIRSTPERSON
    :gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    :gsub("%%s", "(.+)")
    :gsub("%%d", "(%%d+)")
end

ns:On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  if not killPattern or not msg or ns.IsSecret(msg) then return end
  if msg:match(killPattern) then
    ns.cdb.stats.kills = ns.cdb.stats.kills + 1
  end
end)

---------------------------------------------------------------------------
-- Buddy milestones -> feed + toasts
---------------------------------------------------------------------------
local eventHandlers = {}

eventHandlers.LVL = function(level)
  ns.buddy.info.level = tonumber(level)
  ns:AddFeed(buddyName() .. " reached |cffffff00level " .. level .. "|r!", true, ICONS.LEVEL)
  ns:Toast({ header = "LEVEL UP", icon = ICONS.LEVEL, quality = 1, sound = "LEVELUP",
    body = buddyName() .. " hit |cffffff00level " .. level .. "|r!", sub = "Ding! Time to catch up." })
end

eventHandlers.ZONE = function(zone, isNew)
  if isNew == "1" then
    ns:AddFeed(buddyName() .. " discovered |cff88ccff" .. zone .. "|r.", true, ICONS.ZONE)
  else
    ns:AddFeed(buddyName() .. " entered |cff88ccff" .. zone .. "|r.", true, ICONS.ZONE)
  end
end

eventHandlers.DEAD = function(zone)
  ns:AddFeed(buddyName() .. " died in " .. (zone or "?") .. ".", true, ICONS.DEATH)
  ns:Toast({ header = "RIP", icon = ICONS.DEATH, quality = 0, sound = "DEATH",
    body = buddyName() .. " died in " .. (zone or "?"), sub = "|cffaaaaaaPour one out.|r" })
end

eventHandlers.QUEST = function(title)
  ns:AddFeed(buddyName() .. " completed |cffffd100" .. (title or "a quest") .. "|r.", true, ICONS.QUEST)
end

ns.buddyEventHandlers = eventHandlers  -- Loot.lua adds LOOT

ns.msgHandlers.E = function(kind, ...)
  local fn = eventHandlers[kind]
  if fn then fn(...) end
end
