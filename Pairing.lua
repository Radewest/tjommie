-- Tjommie: Pairing
-- Link up without typing names:
--   * right-click a player (chat name, friends list, party frame, target) -> "Add as Tjommie"
--   * "Choose tjommie" picker in the window (online friends / party)
--   * target them and type /tj set
-- Each sends a request; the other player gets an Accept/Decline pop-up and both sides link automatically.

local _, ns = ...

local pending = {}        -- fullName(lower) -> time we asked
local lastAsked = {}      -- fullName(lower) -> time they asked us (spam guard)

local function myFullName()
  return ns.FullName(UnitName("player"))
end

function ns:SetBuddy(fullName, quiet)
  fullName = ns.FullName(fullName)
  if not fullName then return end
  if self.db.buddy and self.db.buddy:lower() == fullName:lower() then return end
  self.db.buddy = fullName
  self.buddy.trail = {}
  self.buddy.info = {}
  self.buddy.stats = {}
  self.buddy.pos = nil
  if not quiet then self:Print("Your tjommie is now |cffffff00" .. fullName .. "|r.") end
  self:Fire("BUDDY_CHANGED")
end

-- Ask someone to be my tjommie
function ns:RequestPair(fullName)
  fullName = ns.FullName(fullName)
  if not fullName then return end
  if fullName:lower() == (myFullName() or ""):lower() then
    self:Print("That's you, boet.")
    return
  end
  local key = fullName:lower()
  pending[key] = GetTime()
  local _, class = UnitClass("player")
  self:SendTo(fullName, "PAIRQ", class, UnitLevel("player"), ns.VERSION)
  self:Print("Request sent to |cffffff00" .. fullName .. "|r - waiting for them to accept...")
  C_Timer.After(20, function()
    if pending[key] then
      pending[key] = nil
      self:Chat("No answer from " .. fullName .. ". Do they have Tjommie v0.3.2 or newer installed?")
    end
  end)
end

local function acceptPair(sender)
  ns:SetBuddy(sender, true)
  ns:SendTo(sender, "PAIRA")
  ns:Toast({ cat = "other", header = "TJOMMIES", body = "You and |cffffff00" .. (strsplit("-", sender)) .. "|r are now tjommies!",
    sub = "Lekker. The tracker bar will light up in a moment.", quality = 2, sound = "LEVELUP" })
  ns:SendHello(true)
end

StaticPopupDialogs["TJOMMIE_PAIR_REQUEST"] = {
  text = "%s",
  button1 = ACCEPT or "Accept",
  button2 = DECLINE or "Decline",
  OnAccept = function(_, data) if data then acceptPair(data) end end,
  OnCancel = function(_, data, reason)
    if data and reason == "clicked" then ns:SendTo(data, "PAIRN") end
  end,
  timeout = 60,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- Messages from players who aren't my tjommie (yet)
function ns:HandleStranger(sender, text)
  if not sender or not text or ns.IsSecret(text) then return end
  local kind, class, level = strsplit("~", text)
  local key = sender:lower()

  if kind == "PAIRQ" then
    if lastAsked[key] and GetTime() - lastAsked[key] < 30 then return end
    lastAsked[key] = GetTime()
    local short = strsplit("-", sender)
    local who = "|c" .. ns.ClassColorHex(class) .. short .. "|r" .. (level and level ~= "" and (" (Lv " .. level .. ")") or "")
    local msg = "|cff33ff99Tjommie|r\n\n" .. who .. " wants to be your tjommie.\n"
    if self.db.buddy then msg = msg .. "\n|cffaaaaaaThis replaces " .. self:BuddyShortName() .. ".|r\n" end
    StaticPopup_Show("TJOMMIE_PAIR_REQUEST", msg, nil, sender)
    if self.db.sound and SOUNDKIT and SOUNDKIT.READY_CHECK then PlaySound(SOUNDKIT.READY_CHECK, "Master") end

  elseif kind == "PAIRA" then
    if pending[key] then
      pending[key] = nil
      acceptPair(sender)  -- link on my side too (sends a harmless PAIRA back)
    end

  elseif kind == "PAIRN" then
    if pending[key] then
      pending[key] = nil
      self:Chat((strsplit("-", sender)) .. " declined the tjommie request.")
    end
  end
end

-- Already-paired players re-sending requests: just confirm
ns.msgHandlers.PAIRQ = function() ns:SendTo(ns.db.buddy, "PAIRA") end
ns.msgHandlers.PAIRA = function()
  if ns.db.buddy then pending[ns.db.buddy:lower()] = nil end
end

---------------------------------------------------------------------------
-- /tj set with a target
---------------------------------------------------------------------------
function ns:PairWithTarget()
  if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsUnit("target", "player") then
    self:Print("Target your friend first, or right-click their name and choose |cffffff00Add as Tjommie|r.")
    return
  end
  self:RequestPair(GetUnitName("target", true))
end

---------------------------------------------------------------------------
-- Right-click menus
---------------------------------------------------------------------------
local MENU_TAGS = {
  "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_TARGET",
  "MENU_UNIT_FRIEND", "MENU_UNIT_BN_FRIEND", "MENU_UNIT_GUILD", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
  "MENU_UNIT_COMMUNITIES_MEMBER", "MENU_UNIT_CHAT_ROSTER",
}

local function nameFromContext(ctx)
  if not ctx then return nil end
  if ctx.unit and UnitIsPlayer(ctx.unit) and not UnitIsUnit(ctx.unit, "player") then
    return GetUnitName(ctx.unit, true)
  end
  if ctx.bnetIDAccount and C_BattleNet and C_BattleNet.GetAccountInfoByID then
    local acc = C_BattleNet.GetAccountInfoByID(ctx.bnetIDAccount)
    local g = acc and acc.gameAccountInfo
    if g and g.characterName and g.clientProgram == BNET_CLIENT_WOW then
      return g.characterName .. (g.realmName and ("-" .. ns.NormRealm(g.realmName)) or "")
    end
    return nil
  end
  if ctx.name then
    return ctx.server and ctx.server ~= "" and (ctx.name .. "-" .. ns.NormRealm(ctx.server)) or ctx.name
  end
end

local function addMenuButtons()
  if not (Menu and Menu.ModifyMenu) then return end
  for _, tag in ipairs(MENU_TAGS) do
    pcall(Menu.ModifyMenu, tag, function(_, root, ctx)
      local name = nameFromContext(ctx)
      if not name or ns.FullName(name):lower() == (myFullName() or ""):lower() then return end
      root:CreateDivider()
      local isCurrent = ns.db.buddy and ns.FullName(name):lower() == ns.db.buddy:lower()
      root:CreateButton(isCurrent and "|cff33ff99Tjommie|r (already linked)" or "|cff33ff99Add as Tjommie|r", function()
        if not isCurrent then ns:RequestPair(name) end
      end)
    end)
  end
end

ns:Listen("LOGIN", addMenuButtons)

---------------------------------------------------------------------------
-- Friend picker data: online friends (Battle.net + character) and group members
---------------------------------------------------------------------------
function ns:GetPairCandidates()
  local out, seen = {}, {}
  local me = (myFullName() or ""):lower()
  local function add(name, class, level, zone, note)
    local full = ns.FullName(name)
    if not full or seen[full:lower()] or full:lower() == me then return end
    seen[full:lower()] = true
    table.insert(out, { name = full, class = class, level = level, zone = zone, note = note })
  end

  -- Battle.net friends in WoW (same game flavour when the client tells us)
  if BNGetNumFriends and C_BattleNet then
    for i = 1, (BNGetNumFriends() or 0) do
      local acc = C_BattleNet.GetFriendAccountInfo(i)
      for j = 1, (C_BattleNet.GetFriendNumGameAccounts(i) or 0) do
        local g = C_BattleNet.GetFriendGameAccountInfo(i, j)
        if g and g.isOnline and g.clientProgram == BNET_CLIENT_WOW and g.characterName
           and (not g.wowProjectID or not WOW_PROJECT_ID or g.wowProjectID == WOW_PROJECT_ID) then
          local classFile
          if g.className and LOCALIZED_CLASS_NAMES_MALE then
            for file, loc in pairs(LOCALIZED_CLASS_NAMES_MALE) do if loc == g.className then classFile = file end end
          end
          add(g.characterName .. (g.realmName and ("-" .. ns.NormRealm(g.realmName)) or ""), classFile,
              g.characterLevel, g.areaName, acc and acc.accountName)
        end
      end
    end
  end

  -- Character friends
  if C_FriendList and C_FriendList.GetNumFriends then
    for i = 1, (C_FriendList.GetNumFriends() or 0) do
      local f = C_FriendList.GetFriendInfoByIndex(i)
      if f and f.connected and f.name then
        local classFile
        if f.className and LOCALIZED_CLASS_NAMES_MALE then
          for file, loc in pairs(LOCALIZED_CLASS_NAMES_MALE) do if loc == f.className then classFile = file end end
        end
        add(f.name, classFile, f.level, f.area, "Friend")
      end
    end
  end

  -- Party members
  for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
    local unit = "party" .. i
    if UnitIsPlayer(unit) then
      local _, class = UnitClass(unit)
      add(GetUnitName(unit, true), class, UnitLevel(unit), nil, "Party")
    end
  end

  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end
