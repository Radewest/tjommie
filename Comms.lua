-- Tjommie: Comms
-- Talks to the buddy's copy of the addon. Uses a Battle.net channel when the buddy is a
-- BNet friend (works cross-realm/cross-faction), otherwise a hidden addon whisper (same realm + faction).
--
-- Wire format: TYPE~field~field...   ("~" separator; "|" is avoided because chat treats it as an escape)
--   HI~class~level~version~needReply      handshake
--   P~mapID~x~y~zone~subzone              position
--   E~kind~a~b                            activity event
--   S~k=v,k=v,...                         stats
--   W~id,id,...                           wishlist
--   G~slot:ilvl,...                       equipped item levels (for upgrade checks)

local _, ns = ...
local PREFIX = ns.PREFIX
local SEP = "~"

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

ns.msgHandlers = {}
ns.buddyLastSeen = 0
local ONLINE_TIMEOUT = 45

function ns:IsBuddyOnline()
  return self.buddyLastSeen > 0 and (GetTime() - self.buddyLastSeen) < ONLINE_TIMEOUT
end

---------------------------------------------------------------------------
-- Battle.net lookup (cached)
---------------------------------------------------------------------------
local bnetCache = {}   -- fullName(lower) -> { id, at }

-- Find the Battle.net game account currently playing this character (nil if none)
local function findBNetGameAccount(fullName)
  if not fullName or not BNGetNumFriends or not C_BattleNet then return nil end
  local key = fullName:lower()
  local c = bnetCache[key]
  if c and GetTime() - c.at < 20 then return c.id end
  c = { at = GetTime() }
  bnetCache[key] = c

  local name, realm = strsplit("-", fullName, 2)
  for i = 1, (BNGetNumFriends() or 0) do
    for j = 1, (C_BattleNet.GetFriendNumGameAccounts(i) or 0) do
      local g = C_BattleNet.GetFriendGameAccountInfo(i, j)
      if g and g.isOnline and g.clientProgram == BNET_CLIENT_WOW and g.characterName
         and g.characterName:lower() == name:lower() then
        local r = ns.NormRealm(g.realmName)
        if not realm or not r or r:lower() == realm:lower() then
          c.id = g.gameAccountID
          return c.id
        end
      end
    end
  end
  return nil
end
ns.FindBNetGameAccount = findBNetGameAccount

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
-- Send to any player (used for pairing requests)
function ns:SendTo(target, ...)
  if not target then return end
  local parts = { ... }
  for i = 1, select("#", ...) do
    parts[i] = tostring(parts[i] or ""):gsub("[~|]", "")
  end
  local msg = table.concat(parts, SEP)
  if #msg > 250 then msg = msg:sub(1, 250) end

  local gid = findBNetGameAccount(target)
  if gid and BNSendGameData then
    pcall(BNSendGameData, gid, PREFIX, msg)
  else
    -- pcall: addon comms are blocked during some instanced content in the modern client
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "WHISPER", target)
  end
end

-- Send to my tjommie
function ns:Send(...)
  local buddy = self.db and self.db.buddy
  if not buddy or self.demoActive then return end
  self:SendTo(buddy, ...)
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
function ns:HandleMessage(msg)
  if not msg or ns.IsSecret(msg) then return end
  local wasOnline = self:IsBuddyOnline()
  self.buddyLastSeen = GetTime()

  local fields = { strsplit(SEP, msg) }
  local kind = table.remove(fields, 1)
  local handler = self.msgHandlers[kind]
  if handler then handler(unpack(fields)) end

  if not wasOnline then
    self:Fire("BUDDY_ONLINE")
  end
end

ns:On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
  if prefix ~= PREFIX then return end
  if not ns:IsBuddy(sender) then
    if ns.HandleStranger then ns:HandleStranger(ns.FullName(sender), text) end
    return
  end
  ns:HandleMessage(text)
end)

ns:On("BN_CHAT_MSG_ADDON", function(prefix, text, channel, senderID)
  if prefix ~= PREFIX then return end
  local g = C_BattleNet.GetGameAccountInfoByID(senderID)
  if not (g and g.characterName) then return end
  local sender = g.characterName .. "-" .. (ns.NormRealm(g.realmName) or "")
  if not ns:IsBuddy(sender) then
    if ns.HandleStranger then ns:HandleStranger(sender, text) end
    return
  end
  ns:HandleMessage(text)
end)

---------------------------------------------------------------------------
-- Handshake + keepalive
---------------------------------------------------------------------------
function ns:SendHello(needReply)
  local _, class = UnitClass("player")
  self:Send("HI", class, UnitLevel("player"), ns.VERSION, needReply and 1 or 0)
end

-- Compare "1.2.3" style versions: -1 if a < b, 0 if equal, 1 if a > b (nil if unparseable)
function ns.CompareVersions(a, b)
  if type(a) ~= "string" or type(b) ~= "string" then return nil end
  local pa, pb = {}, {}
  for n in a:gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
  for n in b:gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
  if #pa == 0 or #pb == 0 then return nil end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x < y and -1 or 1 end
  end
  return 0
end

local versionWarned = {}
local function checkVersion(theirs)
  if not theirs or versionWarned[theirs] then return end
  local cmp = ns.CompareVersions(ns.VERSION, theirs)
  if not cmp or cmp == 0 then return end
  versionWarned[theirs] = true
  local name = ns:BuddyShortName()
  if cmp > 0 then
    ns:Toast({ cat = "other", header = "UPDATE NEEDED", quality = 1,
      body = name .. " is on Tjommie v" .. theirs .. " (you have v" .. ns.VERSION .. ")",
      sub = "Ask " .. name .. " to update so everything works." })
  else
    ns:Toast({ cat = "other", header = "UPDATE AVAILABLE", quality = 2,
      body = name .. " has Tjommie v" .. theirs .. " (you have v" .. ns.VERSION .. ")",
      sub = "Grab the new version from CurseForge." })
  end
end

ns.msgHandlers.HI = function(class, level, version, needReply)
  local info = ns.buddy.info
  info.class = class
  info.level = tonumber(level)
  info.version = version
  checkVersion(version)
  if needReply == "1" then
    ns:SendHello(false)
  end
  ns:FullSync()
  ns:Fire("BUDDY_INFO")
end

-- Sends everything the buddy needs to be up to date
function ns:FullSync()
  self:Fire("SYNC_REQUEST")
end

ns:Listen("BUDDY_ONLINE", function()
  ns:AddFeed(ns.BuddyNameColored() .. " is online.", true, ns.ICONS.ONLINE)
  ns:Toast({ cat = "online", header = "ONLINE", icon = ns.ICONS.ONLINE, quality = 2,
    body = ns.BuddyNameColored() .. " is online.", sub = ns.buddy.pos and ns.buddy.pos.zone or "" })
end)

ns:Listen("LOGIN", function()
  -- Probe for the buddy now and every 30s while they're not seen.
  C_Timer.After(5, function() ns:SendHello(true) end)
  C_Timer.NewTicker(30, function()
    if ns.db.buddy and not ns:IsBuddyOnline() then ns:SendHello(true) end
  end)
end)

ns:Listen("BUDDY_CHANGED", function()
  wipe(bnetCache)
  ns.buddyLastSeen = 0
  ns:SendHello(true)
end)

---------------------------------------------------------------------------
-- Hide "No player named X is currently playing." spam when the buddy is offline
---------------------------------------------------------------------------
local function systemFilter(_, _, msg)
  if not msg or ns.IsSecret(msg) or not ns.db or not ns.db.buddy or not ERR_CHAT_PLAYER_NOT_FOUND_S then
    return false
  end
  local short = ns:BuddyShortName()
  if msg == ERR_CHAT_PLAYER_NOT_FOUND_S:format(short) or msg == ERR_CHAT_PLAYER_NOT_FOUND_S:format(ns.db.buddy) then
    return true
  end
  return false
end

local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if addFilter then addFilter("CHAT_MSG_SYSTEM", systemFilter) end
