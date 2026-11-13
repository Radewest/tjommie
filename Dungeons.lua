-- Tjommie: Dungeon suggestions
-- Which dungeons you and your tjommie are both the right level for, plus the next ones coming up.
-- Level ranges are the classic recommended ranges; Forever may tweak some, so treat them as a guide.

local _, ns = ...

-- name, min level, max level, where
local DUNGEONS = {
  { "Ragefire Chasm",               13, 18, "Orgrimmar" },
  { "Wailing Caverns",              15, 25, "The Barrens" },
  { "The Deadmines",                18, 23, "Westfall" },
  { "Shadowfang Keep",              22, 30, "Silverpine Forest" },
  { "The Stockade",                 22, 30, "Stormwind" },
  { "Blackfathom Deeps",            24, 32, "Ashenvale" },
  { "Scarlet Monastery: Graveyard", 26, 36, "Tirisfal Glades" },
  { "Gnomeregan",                   29, 38, "Dun Morogh" },
  { "Scarlet Monastery: Library",   29, 39, "Tirisfal Glades" },
  { "Razorfen Kraul",               30, 40, "The Barrens" },
  { "Scarlet Monastery: Armory",    32, 42, "Tirisfal Glades" },
  { "Scarlet Monastery: Cathedral", 35, 45, "Tirisfal Glades" },
  { "Razorfen Downs",               40, 50, "The Barrens" },
  { "Uldaman",                      42, 52, "Badlands" },
  { "Zul'Farrak",                   44, 54, "Tanaris" },
  { "Maraudon",                     46, 55, "Desolace" },
  { "Sunken Temple",                50, 60, "Swamp of Sorrows" },
  { "Blackrock Depths",             52, 60, "Blackrock Mountain" },
  { "Lower Blackrock Spire",        55, 60, "Blackrock Mountain" },
  { "Dire Maul",                    56, 60, "Feralas" },
  { "Scholomance",                  58, 60, "Western Plaguelands" },
  { "Stratholme",                   58, 60, "Eastern Plaguelands" },
}
ns.DUNGEONS = DUNGEONS

local SOON = 3 -- "almost ready" if within this many levels of the minimum

-- Returns a list of { name, min, max, where, state, note } sorted for display.
-- state: "both" (both ready), "you"/"them" (one ready, the other close), "soon" (both close)
function ns:GetDungeonSuggestions(myLevel, theirLevel)
  myLevel = myLevel or UnitLevel("player")
  local out = {}
  for _, d in ipairs(DUNGEONS) do
    local name, lo, hi, where = d[1], d[2], d[3], d[4]
    local meOk = myLevel >= lo and myLevel <= hi
    local themOk = theirLevel and theirLevel >= lo and theirLevel <= hi
    local meSoon = myLevel < lo and lo - myLevel <= SOON
    local themSoon = theirLevel and theirLevel < lo and lo - theirLevel <= SOON
    local entry
    if theirLevel then
      if meOk and themOk then
        entry = { state = "both", note = "You're both ready" }
      elseif meOk and themSoon then
        entry = { state = "you", note = ns:BuddyShortName() .. " needs " .. (lo - theirLevel) .. " more level(s)" }
      elseif themOk and meSoon then
        entry = { state = "them", note = "You need " .. (lo - myLevel) .. " more level(s)" }
      elseif (meSoon or meOk) and (themSoon or themOk) then
        entry = { state = "soon", note = "Coming up for both of you" }
      end
    elseif meOk then
      entry = { state = "you", note = "You're ready" }
    elseif meSoon then
      entry = { state = "soon", note = "Coming up" }
    end
    if entry then
      entry.name, entry.min, entry.max, entry.where = name, lo, hi, where
      table.insert(out, entry)
    end
  end
  local order = { both = 1, you = 2, them = 2, soon = 3 }
  table.sort(out, function(a, b)
    if order[a.state] ~= order[b.state] then return order[a.state] < order[b.state] end
    return a.min < b.min
  end)
  return out
end

-- Announce once when a dungeon becomes "both ready"
local function checkNewlyReady()
  if not ns.db.buddy then return end
  local theirs = ns.buddy.info.level
  if not theirs then return end
  ns.cdb.dungeonsAnnounced = ns.cdb.dungeonsAnnounced or {}
  local seen = ns.cdb.dungeonsAnnounced
  for _, d in ipairs(ns:GetDungeonSuggestions(UnitLevel("player"), theirs)) do
    local key = (ns.db.buddy or "") .. ":" .. d.name
    if d.state == "both" and not seen[key] then
      seen[key] = true
      ns:AddFeed("You're both ready for |cffffd100" .. d.name .. "|r (" .. d.where .. ").", false, "Interface\\Icons\\INV_Misc_Key_03")
      ns:Toast({ cat = "together", header = "DUNGEON TIME", icon = "Interface\\Icons\\INV_Misc_Key_03", quality = 3,
        body = "You and " .. ns.BuddyNameColored() .. " are ready for " .. d.name,
        sub = d.where .. " · levels " .. d.min .. "-" .. d.max })
      return -- one at a time
    end
  end
end

ns:Listen("BUDDY_STATS", checkNewlyReady)
ns:Listen("BUDDY_INFO", checkNewlyReady)
ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(2, checkNewlyReady) end)

---------------------------------------------------------------------------
-- "Keen for this dungeon?" - click a dungeon in the Together tab to ask your tjommie
-- Wire: DQ~name (ask)   DA~name~1|0 (answer)
---------------------------------------------------------------------------
local KEY_ICON = "Interface\\Icons\\INV_Misc_Key_03"

local function whereOf(name)
  for _, d in ipairs(DUNGEONS) do
    if d[1] == name then return d[4], d[2], d[3] end
  end
end

function ns:AskDungeon(name)
  if not self.db.buddy then self:Print("Link up with a tjommie first.") return end
  if not self:IsBuddyOnline() then self:Print(self:BuddyShortName() .. " is offline right now.") return end
  self:Send("DQ", name)
  self:AddFeed("You asked " .. ns.BuddyNameColored() .. " about |cffffd100" .. name .. "|r.", false, KEY_ICON)
  self:Toast({ cat = "together", header = "ASKED", icon = KEY_ICON, quality = 2,
    body = "Asked " .. ns.BuddyNameColored() .. " about " .. name, sub = "Waiting for an answer..." })
end

StaticPopupDialogs["TJOMMIE_DUNGEON_ASK"] = {
  text = "%s",
  button1 = "I'm in!",
  button2 = "Not now",
  OnAccept = function(_, data)
    if not data then return end
    ns:Send("DA", data, 1)
    ns:AddFeed("You said yes to |cffffd100" .. data .. "|r.", false, KEY_ICON)
  end,
  OnCancel = function(_, data, reason)
    if data and reason == "clicked" then ns:Send("DA", data, 0) end
  end,
  timeout = 120,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["TJOMMIE_DUNGEON_YES"] = {
  text = "%s",
  button1 = "Invite",
  button2 = "Later",
  OnAccept = function() ns:InviteBuddy() end,
  timeout = 120,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

ns.msgHandlers.DQ = function(name)
  if not name or name == "" then return end
  local where, lo, hi = whereOf(name)
  local text = "|cff33ff99Tjommie|r\n\n" .. ns.BuddyNameColored() .. " is keen for |cffffd100" .. name .. "|r!"
  if where then text = text .. "\n|cffaaaaaa" .. where .. " · levels " .. lo .. "-" .. hi .. "|r" end
  text = text .. "\n\nAre you in?"
  ns:AddFeed(ns.BuddyNameColored() .. " is keen for |cffffd100" .. name .. "|r!", true, KEY_ICON)
  StaticPopup_Show("TJOMMIE_DUNGEON_ASK", text, nil, name)
  if ns.db.sound and SOUNDKIT and SOUNDKIT.READY_CHECK then PlaySound(SOUNDKIT.READY_CHECK, "Master") end
end

ns.msgHandlers.DA = function(name, yes)
  if yes == "1" then
    ns:AddFeed(ns.BuddyNameColored() .. " is in for |cffffd100" .. (name or "?") .. "|r!", true, KEY_ICON)
    if ns:IsGroupedWithBuddy() then
      ns:Toast({ cat = "together", header = "LET'S GO", icon = KEY_ICON, quality = 3, sound = "LEVELUP",
        body = ns.BuddyNameColored() .. " is in for " .. (name or "?") .. "!", sub = "You're already grouped. Lekker!" })
    else
      StaticPopup_Show("TJOMMIE_DUNGEON_YES",
        "|cff33ff99Tjommie|r\n\n" .. ns.BuddyNameColored() .. " is in for |cffffd100" .. (name or "?") .. "|r!\n\nInvite them to your group?")
    end
  else
    ns:AddFeed(ns.BuddyNameColored() .. " can't do |cffffd100" .. (name or "?") .. "|r right now.", true, KEY_ICON)
    ns:Chat(ns:BuddyShortName() .. " can't do " .. (name or "?") .. " right now.", "important")
  end
end
