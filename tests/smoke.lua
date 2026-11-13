-- Tjommie smoke tests: run the whole add-on against stubbed WoW APIs.
-- Usage: python3 tests/run_tests.py   (loads files in TOC order, fires events, simulates a buddy)
-- Not a replacement for in-game testing: the stubs are deliberately simple.

local root = arg[1]
dofile(root .. "/tests/stubs.lua")

local failures, checks = 0, 0
local function check(cond, label)
  checks = checks + 1
  if cond then
    print("  ok   " .. label)
  else
    failures = failures + 1
    print("  FAIL " .. label)
  end
end

-- Count errors that reach the error handler (expected ones are subtracted below)
local handlerErrors = 0
geterrorhandler = function() return function(e) handlerErrors = handlerErrors + 1; print("  (error) " .. tostring(e)) end end

-- Load files in TOC order
local ns = {}
for line in io.lines(root .. "/Tjommie.toc") do
  local file = line:match("^([%w_]+%.lua)%s*$")
  if file then assert(loadfile(root .. "/" .. file))("Tjommie", ns) end
end

local function fire(e, ...) assert(events[e], "event not registered: " .. e)._OnEvent(events[e], e, ...) end
local function runTimers() for i = 1, #timers do pcall(timers[i]) end end
local function recv(m, from) fire("CHAT_MSG_ADDON", "Tjommie", m, "WHISPER", from or "Sam-Realm") end

print("Loading")
fire("ADDON_LOADED", "Tjommie")
fire("PLAYER_LOGIN")
check(ns.db and ns.cdb, "saved variables initialised")

print("Pairing")
StaticPopup_Show = function(_, _, _, data) popupData = data end
recv("PAIRQ~MAGE~19~0.3.2", "Sam-Realm")
check(popupData == "Sam-Realm", "pair request shows a popup")
StaticPopupDialogs.TJOMMIE_PAIR_REQUEST.OnAccept(nil, popupData)
check(ns.db.buddy == "Sam-Realm", "accepting links the buddy")
recv("PAIRQ~ROGUE~10~0.3.2", "Stranger-Realm")
check(ns.db.buddy == "Sam-Realm", "a stranger's request doesn't change the buddy by itself")
recv("HI~MAGE~19~0.3.2~0", "Stranger-Realm")
check(ns.buddy.info.level == nil or ns.buddy.info.class == "MAGE", "non-pairing messages from strangers are ignored")
runTimers()

print("Buddy messages")
recv("HI~MAGE~19~0.3.2~1")
recv("P~1429~0.6000~0.4000~Elwynn Forest~Goldshire")
recv("S~MAGE,19,500,1000,1000,0,5,0,0,0,0,0,0,0,7,1,30,60,1")
recv("W~200,300")
recv("G~1:10,5:12")
check(ns:IsBuddyOnline(), "buddy is online after messages")
check(ns.buddy.info.class == "MAGE", "HI sets class")
check(ns.buddy.pos and ns.buddy.pos.zone == "Elwynn Forest", "P sets position")
check(ns.buddy.stats.drinks == 7 and ns.buddy.stats.fires == 1 and ns.buddy.stats.xpMax == 1000, "S decodes compact stats")
check(#ns.buddy.wishlist == 2, "W sets wishlist")
check(ns.buddy.gear[5] == 12, "G sets gear")

print("Events and feed")
local feedBefore = #ns.cdb.feed
recv("E~LVL~20")
recv("E~LOOT~200")
recv("E~DEAD~Westfall")
check(#ns.cdb.feed >= feedBefore + 3, "buddy events reach the feed")
fire("CHAT_MSG_COMBAT_XP_GAIN", "Wolf dies, you gain 40 experience.")
check(ns.cdb.stats.kills == 1, "XP kill counted")
fire("PLAYER_DEAD")
check(ns.cdb.stats.deaths == 1, "death counted")

print("Loot evaluation")
check(ns:EvaluateFor(300, { class = "MAGE", level = 19, gear = { [5] = 12 } }) == true, "cloth INT robe is an upgrade for a mage")
check(ns:EvaluateFor(300, ns:Me()) == false, "cloth robe is not an upgrade for a warrior")
check(ns:EvaluateFor(200, ns:Me()) == true, "mail helm is an upgrade for a level 20 warrior")

print("Navigation")
ns:UpdateNav()
check(ns.nav.status == "ok" and ns.nav.dist and ns.nav.heading, "nav gives distance and heading")
local t0 = 1000
GetTime = function() return t0 end
for i = 0, 8 do
  t0 = 1000 + i
  ns.buddyLastSeen = t0
  ns.buddy.pos.wx = 2400 - i * 7; ns.buddy.pos.wy = 1500
  ns:UpdateNav()
end
check(ns.nav.eta and ns.nav.eta > 30 and ns.nav.eta < 80, "ETA estimated while closing in")

print("Fun stats")
fire("CHAT_MSG_SYSTEM", "You feel tipsy.")
fire("CHAT_MSG_SYSTEM", "You feel completely smashed.")
fire("CHAT_MSG_SYSTEM", "You drink the Cheap Beer and feel drunk.")
check(ns.cdb.stats.drinks == 3 and ns.cdb.stats.smashed == 1, "drinks and smashed counted")
local worst = "S~" .. ns.EncodeStats({ class = "WARRIOR", level = 60, xp = 999999, xpMax = 999999, gold = 99999999,
  goldEarned = 999999999, kills = 99999, deaths = 9999, quests = 9999, zones = 99, distance = 9999999, rares = 999,
  epics = 999, played = 9999999, drinks = 9999, smashed = 999, danced = 999999, fireTime = 999999, fires = 999,
  playedTotal = 99999999, questsTotal = 9999, killsTotal = 999999, deathsTotal = 99999, drinksTotal = 99999 })
check(#worst < 250, "worst-case stats message fits (" .. #worst .. " bytes)")

print("Upgrade finder")
GetTime = function() return 99999 end
C_QuestLog = {
  GetNumQuestLogEntries = function() return 2 end,
  GetInfo = function(i) if i == 1 then return { isHeader = true, title = "Westfall" } end return { questID = 55, title = "The Defias" } end,
  GetSelectedQuest = function() return 0 end, SetSelectedQuest = function() end,
  GetTitleForQuestID = function() return "q" end,
}
GetNumQuestLogChoices = function() return 2 end
GetNumQuestLogRewards = function() return 0 end
GetQuestLogItemLink = function(_, j) return j == 1 and "|Hitem:200|h" or "|Hitem:300|h" end
ns:ScanQuestLog()
local list = ns:GetUpgradeList()
check(#list == 2, "quest scan finds one upgrade for me and one for the buddy")
recv("U~200~Kill Hogger~Elwynn Forest~+5 item level")
check(#ns:GetUpgradeList() == 3, "buddy's upgrade lead is added")

print("UI and misc")
ns:ToggleWindow()
check(TjommieFrame ~= nil, "main window builds")
ns:ShowPicker()
check(TjommiePicker ~= nil, "friend picker builds")
ns:Toast({ header = "X", body = "y", quality = 4, sound = "WISH" })
SlashCmdList.TJOMMIE("demo"); runTimers(); SlashCmdList.TJOMMIE("demo")
check(ns.db.buddy == "Sam-Realm", "demo restores the real buddy")

print("v0.4: chat, settings, privacy, lifetime, version, welcome")
-- Pop-ups must not echo to chat unless chat = Everything
local printed = {}
local realPrint = print
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
ns.db.chat = "important"
ns:Toast({ header = "X", body = "toast-body-check", sound = "WISH" })
ns.db.chat = "all"
ns:Toast({ header = "X", body = "toast-body-check-2", sound = "WISH" })
print = realPrint
local sawFirst, sawSecond = false, false
for _, line in ipairs(printed) do
  if line:find("toast-body-check", 1, true) and not line:find("check-2", 1, true) then sawFirst = true end
  if line:find("toast-body-check-2", 1, true) then sawSecond = true end
end
check(not sawFirst and sawSecond, "pop-ups only echo to chat when chat is set to Everything")
ns.db.chat = "important"

ns.buddyLastSeen = GetTime()
recv("P~0")
ns:UpdateNav()
check(ns.nav.status == "private", "paused position shows as private")
recv("P~1429~0.6000~0.4000~Elwynn Forest~Goldshire")

check(ns.CompareVersions("0.4.0", "0.3.2") == 1 and ns.CompareVersions("0.3.2", "0.4.0") == -1
  and ns.CompareVersions("0.4.0", "0.4.0") == 0, "version comparison")
recv("HI~MAGE~19~0.3.2~0")
check(ns.buddy.info.version == "0.3.2", "buddy version recorded")

ns:UpdateLifetime()
check(ns.cdb.lifetime.deathsTotal == 12, "lifetime deaths read from Statistics when available")
check(ns.cdb.lifetime.killsTotal == nil, "unavailable Statistics stay empty")
fire("TIME_PLAYED_MSG", 123456, 3600)
check(ns.cdb.lifetime.playedTotal == 123456, "time played captured")
local enc = ns.EncodeStats(ns:GetMyStats())
recv("S~" .. enc)
check(ns.buddy.stats.playedTotal == 123456, "lifetime stats travel in the stats message")

ns.db.hideGold = true
sent = {}
ns:SendStats()
check(sent[#sent] and not sent[#sent]:find(",5000,", 1, true), "hide gold leaves gold out of stats")
ns.db.hideGold = false

ns:OpenSettings()
check(true, "settings tab opens")
ns:Fire("SETTINGS_CHANGED")
ns:ShowWelcome()
check(TjommieWelcome ~= nil, "welcome guide builds")

print("v0.5: grey fix, status, meet, invite, dungeons, badges")
check(ns:EvaluateFor(500, ns:Me()) == false, "grey items are never upgrades")
check(ns:EvaluateFor(600, ns:Me()) == false, "a white item is not an upgrade over an equipped green")
check(ns:EvaluateFor(700, ns:Me()) == true, "a white item is an upgrade over an empty slot")
recv("G~1:10:2,16:12:1")
check(ns.buddy.gearQ[1] == 2 and ns.buddy.gearQ[16] == 1 and ns.buddy.gear[16] == 12, "gear message carries quality")
recv("G~1:10,5:12")
check(ns.buddy.gear[5] == 12, "old gear format still parses")

ns.buddyLastSeen = GetTime()
recv("ST~TAXI~Stormwind")
check(ns:BuddyStatusText() == "On a flight to Stormwind", "status: flight with destination")
recv("ST~INSTANCE~")
check(ns:BuddyStatusText() == "In a dungeon", "status: instance without a name")
recv("ST~~")
check(ns:BuddyStatusText() == nil, "status: nothing to show")

GetTime = function() return 50000 end
ns.buddyLastSeen = 50000
recv("P~1429~0.5100~0.5000~Elwynn Forest~Goldshire")
ns:UpdateNav()
check(ns.nav.buddyDist and ns.nav.buddyDist < 100, "buddy distance tracked for the invite button")
check(ns:IsGroupedWithBuddy() == false, "not grouped yet")
ns:InviteBuddy()
check(invited[1] == "Sam-Realm", "invite goes to the tjommie")

sent = {}
ns:SetMeet(1429, 0.70, 0.50, false)
ns:UpdateNav()
check(ns.nav.target == "meet" and ns:NavText():find("Meet:", 1, true), "arrow switches to the meeting point")
check(sent[#sent] and sent[#sent]:find("^M~1429~"), "meeting point sent to the tjommie")
recv("MC")
ns:UpdateNav()
check(ns.meet == nil and ns.nav.target == "buddy", "tjommie can clear the meeting point")
recv("M~1429~0.3000~0.3000~Westfall")
check(ns.meet and ns.meet.zone == "Westfall" and ns.meet.by == "buddy", "tjommie's meeting point received")
ns:ClearMeet(false, true)

local both = ns:GetDungeonSuggestions(20, 20)
local dmBoth = false
for _, d in ipairs(both) do if d.name == "The Deadmines" and d.state == "both" then dmBoth = true end end
check(both[1].state == "both" and dmBoth, "level 20 duo: both ready for Deadmines (and listed first)")
local split = ns:GetDungeonSuggestions(20, 16)
local foundYou = false
for _, d in ipairs(split) do if d.name == "The Deadmines" and d.state == "you" then foundYou = true end end
check(foundYou, "one ready, the other close")

sent = {}
recv("B~met~")
check(ns:HasBadge("met"), "badge from the tjommie is unlocked")
check(not (sent[#sent] or ""):find("^B~met"), "badges from the wire aren't echoed back")
ns.buddy.info.level = 19
UnitLevel = function() return 20 end
fire("PLAYER_LEVEL_UP", 20)
for i = 1, #timers do pcall(timers[i]) end
check(ns:HasBadge("race20") and ns:PairData().badges.race20.winner == "Harry", "level race won")
local t0 = os.time()
recv("E~DEAD~Westfall")
fire("PLAYER_DEAD")
check(ns:HasBadge("samefate"), "both died within a minute: Same Fate")
local earned, total = ns:BadgeSummary()
check(earned >= 2 and total == #ns.BADGES, "badge summary")
UnitLevel = function() return 20 end

print("v0.5.1: meeting point clearing")
local refreshed = 0
local realRefresh = ns.RefreshMap
ns.RefreshMap = function(...) refreshed = refreshed + 1; return realRefresh(...) end
ns:SetMeet(1429, 0.60, 0.60, false)
ns:ClearMeet()
check(ns.meet == nil and refreshed >= 1, "clearing a meeting point refreshes the map immediately")
refreshed = 0
ns:ClearMeet()
check(refreshed >= 1, "clearing with nothing set still refreshes (no stuck pins)")
ns.RefreshMap = realRefresh
ns:ResetMeetButton()
check(ns.db.meetButtonPos == nil, "reset positions also resets the Meet here button")

print("v0.6: badges fix, dungeon ask, professions, routes")
check(ns.SameName("Ravandil Glaivestorm-Some Realm", "ravandil glaivestorm-SomeRealm"), "names match across realm spelling")
check(ns.SameName("Sam", "Sam-Realm") and not ns.SameName("Sam-Realm", "Sam-Other"), "realm only compared when both have one")

-- Party unit detection (works in dungeons where positions/messages are blocked)
GetNumSubgroupMembers = function() return 1 end
GetUnitName = function(unit) if unit == "party1" then return "Sam-Realm" end return "Koos" end
check(ns:BuddyUnit() == "party1" and ns:IsGroupedWithBuddy(), "finds the tjommie in the party")
local near, close = ns.Togetherness()
check(near and close, "party unit in sight counts as together")
IsInInstance = function() return true, "party" end
ns:PairData().badges.dungeon = nil
ns:PairData().badges.met = nil
for i = 1, #timers do pcall(timers[i]) end
check(ns:HasBadge("dungeon") and ns:HasBadge("met"), "Dungeon Duo and Finally Met work inside a dungeon")
IsInInstance = function() return false, "none" end
GetNumSubgroupMembers = function() return 0 end

-- Badge sync
sent = {}
ns:SendBadgeList()
check(sent[#sent] and sent[#sent]:find("^BL~") and sent[#sent]:find("race20:Harry", 1, true), "badge list sent with race winners")
ns:PairData().badges.party = nil
recv("BL~party,race30:Sam")
check(ns:HasBadge("party") and ns:PairData().badges.race30.winner == "Sam", "badge list from tjommie fills in missing badges")

-- Keen for this dungeon?
popups = {}
StaticPopup_Show = function(which, text, _, data) popups[#popups + 1] = { which, text, data } end
sent = {}
ns:AskDungeon("The Deadmines")
check(sent[#sent] == "DQ~The Deadmines", "dungeon request sent")
recv("DQ~Shadowfang Keep")
check(popups[#popups] and popups[#popups][1] == "TJOMMIE_DUNGEON_ASK" and popups[#popups][3] == "Shadowfang Keep", "dungeon request shows a pop-up")
StaticPopupDialogs.TJOMMIE_DUNGEON_ASK.OnAccept(nil, "Shadowfang Keep")
check(sent[#sent] == "DA~Shadowfang Keep~1", "saying yes answers the tjommie")
recv("DA~The Deadmines~1")
check(popups[#popups][1] == "TJOMMIE_DUNGEON_YES", "a yes offers to invite")

-- Professions & recipes
sent = {}
ns:UpdateProfessions(true)
check(sent[#sent] == "PF~Enchanting:120:150,Tailoring:95:150", "professions shared with skill levels")
recv("PF~Alchemy:200:225,Herbalism:210:225")
check(ns.buddy.professions.Alchemy.rank == 200, "tjommie's professions received")
local big = {}
for i = 1, 90 do big[#big + 1] = "s" .. (10000 + i) end
ns.cdb.recipes = { Enchanting = big }
sent = {}
ns:SendRecipes("Enchanting")
for i = 1, #timers do pcall(timers[i]) end
local chunks = 0
for _, m in ipairs(sent) do if m:find("^RC~") then chunks = chunks + 1; check(#m < 250, "recipe chunk fits (" .. #m .. " bytes)") end end
check(chunks >= 2, "big recipe lists are split into chunks (" .. chunks .. ")")
for _, m in ipairs(sent) do if m:find("^RC~") then recv(m) end end
check(ns.buddy.recipes and ns.buddy.recipes.Enchanting and #ns.buddy.recipes.Enchanting == 90, "chunks reassembled on the other side")
check(ns.RecipeInfo("s10001") == "Enchant 10001", "spell recipes resolve to names")
sent = {}
ns:AskCraft("s10001")
check(sent[#sent] == "CR~s10001", "craft request sent")
recv("CR~i200")
check(popups[#popups][1] == "TJOMMIE_CRAFT_ASK", "craft request shows a pop-up")

-- Routes
ns.cdb.flightNodes = {
  A = { name = "Goldshire", c = 0, x = 2000, y = 1500 },
  B = { name = "Lakeshire", c = 0, x = 3900, y = 2900 },
}
local plan = ns:PlanRoute(0, 3950, 2950)
check(plan.kind == "fly" and plan.from.name == "Goldshire" and plan.to.name == "Lakeshire", "long trip suggests a flight")
local short = ns:PlanRoute(0, 2050, 1520)
check(short.kind == "walk", "short trip: run straight there")
check(#ns:RouteText(plan) >= 2, "route text explains the flight")
check(ns:PlanRoute(1, 10, 10).kind == "continent", "other continent detected")

-- Blizzard waypoint mirrors the meeting point
ns:SetMeet(1429, 0.4, 0.4, false)
check(waypointSet and superTracked, "meeting point placed as a Blizzard waypoint")
ns:ClearMeet()
check(waypointCleared, "and cleared again")

print("Bug log")
local before = handlerErrors
ns:On("TJ_TEST_ERROR", function() local x; return x.y end)
fire("TJ_TEST_ERROR"); fire("TJ_TEST_ERROR")
local last = ns.db.errors[#ns.db.errors]
check(last and last.count == 2, "errors are logged and de-duplicated")
handlerErrors = handlerErrors - 2 -- the two deliberate ones
ns:ShowBugs()

check(handlerErrors == 0, "no unexpected errors (" .. handlerErrors .. ")")
print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then error("tests failed") end
