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
