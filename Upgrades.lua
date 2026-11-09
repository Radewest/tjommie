-- Tjommie: Upgrade finder
-- Finds gear upgrades for BOTH of you from things the game can actually see:
--   * quest rewards in your quest log ("Do X in Westfall to get Y")
--   * quests a quest-giver offers you (toast: "accept this, it rewards an upgrade")
--   * quest hand-ins (toast: "pick this reward")
--   * vendors when you open them (toast: "this vendor sells an upgrade")
-- Upgrades for your tjommie are sent to them, so each of you sees the other's leads too.
-- Uses the same class/level/gear rules as the loot alerts (Loot.lua -> ns:EvaluateFor).

local _, ns = ...

local upgrades = {}   -- key -> { itemID, who = "me"/"buddy", src, zone, why, kind, t }
ns.upgrades = upgrades
local SCAN_COOLDOWN = 10

local function itemIcon(id) return C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) end

local function add(entry)
  local key = entry.itemID .. ":" .. entry.who .. ":" .. (entry.src or "")
  local isNew = not upgrades[key]
  entry.t = entry.t or time()
  upgrades[key] = entry
  if isNew then ns:Fire("UPGRADES_CHANGED") end
  return isNew
end

local function clearKind(kind)
  for k, e in pairs(upgrades) do
    if e.kind == kind then upgrades[k] = nil end
  end
end

-- Evaluate one item for me and my buddy; cb(forMe, whyMe, forBuddy, whyBuddy) once item data is loaded
local function evaluate(itemID, cb)
  local item = Item:CreateFromItemID(itemID)
  item:ContinueOnItemLoad(function()
    local me, whyMe = ns:EvaluateFor(itemID, ns:Me())
    local bud, whyBud = false, nil
    if ns.db.buddy and ns.buddy.info.class then
      bud, whyBud = ns:EvaluateFor(itemID, ns:Buddy())
    end
    cb(me, whyMe, bud, whyBud)
  end)
end

---------------------------------------------------------------------------
-- Quest log scan
---------------------------------------------------------------------------
local scanning, lastScan = false, 0
local outgoing = {}

local function questItemLinks(questID)
  local links = {}
  local nChoices = GetNumQuestLogChoices and GetNumQuestLogChoices(questID, true) or 0
  for j = 1, nChoices do
    local link = GetQuestLogItemLink("choice", j, questID)
    if link then table.insert(links, link) end
  end
  local nRewards = GetNumQuestLogRewards and GetNumQuestLogRewards(questID) or 0
  for j = 1, nRewards do
    local link = GetQuestLogItemLink("reward", j, questID)
    if link then table.insert(links, link) end
  end
  return links
end

function ns:ScanQuestLog()
  if scanning or not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then return end
  if GetTime() - lastScan < SCAN_COOLDOWN then return end
  scanning, lastScan = true, GetTime()

  clearKind("quest")
  wipe(outgoing)
  local prevSelected = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
  local header

  local ok, err = pcall(function()
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info then
        if info.isHeader then
          header = info.title
        elseif info.questID and not info.isHidden then
          C_QuestLog.SetSelectedQuest(info.questID)
          for _, link in ipairs(questItemLinks(info.questID)) do
            local id = tonumber(link:match("item:(%d+)"))
            if id then
              local title, zone = info.title, header
              evaluate(id, function(me, whyMe, bud, whyBud)
                if me then
                  add({ itemID = id, who = "me", kind = "quest", src = "Quest: " .. title, zone = zone, why = whyMe })
                end
                if bud then
                  add({ itemID = id, who = "buddy", kind = "quest", src = "Quest: " .. title, zone = zone, why = whyBud })
                  table.insert(outgoing, { id, title, zone or "", whyBud })
                end
              end)
            end
          end
        end
      end
    end
  end)
  if prevSelected and prevSelected ~= 0 then pcall(C_QuestLog.SetSelectedQuest, prevSelected) end
  scanning = false
  if not ok then ns:ReportError(err) end

  ns:Fire("UPGRADES_CHANGED")
  -- Share leads with the buddy shortly after (item loads are async)
  C_Timer.After(2, function()
    ns:Send("UC")
    for i = 1, math.min(#outgoing, 12) do
      local o = outgoing[i]
      ns:Send("U", o[1], o[2], o[3], o[4])
    end
  end)
end

local pendingScan = false
local function queueScan()
  if pendingScan or scanning then return end
  pendingScan = true
  C_Timer.After(3, function()
    pendingScan = false
    ns:ScanQuestLog()
  end)
end

ns:On("QUEST_ACCEPTED", queueScan)
ns:On("QUEST_REMOVED", queueScan)
ns:On("PLAYER_EQUIPMENT_CHANGED", queueScan)
ns:On("PLAYER_LEVEL_UP", queueScan)
ns:Listen("LOGIN", function() C_Timer.After(8, function() ns:ScanQuestLog() end) end)
ns:Listen("BUDDY_ONLINE", queueScan)

-- Leads from my buddy's quest log
ns.msgHandlers.UC = function()
  clearKind("buddyquest")
  ns:Fire("UPGRADES_CHANGED")
end

ns.msgHandlers.U = function(itemID, title, zone, why)
  itemID = tonumber(itemID)
  if not itemID then return end
  add({ itemID = itemID, who = "me", kind = "buddyquest",
        src = ns:BuddyShortName() .. "'s quest: " .. (title or "?"),
        zone = (zone ~= "" and zone) or nil, why = why })
end

---------------------------------------------------------------------------
-- Quest giver: offering a quest / handing one in
---------------------------------------------------------------------------
local function questFrameLinks()
  local links = {}
  for j = 1, (GetNumQuestChoices and GetNumQuestChoices() or 0) do
    local link = GetQuestItemLink("choice", j)
    if link then table.insert(links, { link, j }) end
  end
  for j = 1, (GetNumQuestRewards and GetNumQuestRewards() or 0) do
    local link = GetQuestItemLink("reward", j)
    if link then table.insert(links, { link }) end
  end
  return links
end

local function checkQuestFrame(isHandIn)
  local title = GetTitleText and GetTitleText() or "this quest"
  local best, bestWhy, bestGain = nil, nil, -1
  local budHits = {}
  local remaining = 0
  local links = questFrameLinks()
  if #links == 0 then return end
  for _, l in ipairs(links) do
    local id = tonumber(l[1]:match("item:(%d+)"))
    if id then
      remaining = remaining + 1
      evaluate(id, function(me, whyMe, bud)
        if me then
          local gain = tonumber((whyMe or ""):match("%+(%d+)")) or 99
          if gain > bestGain then best, bestWhy, bestGain = l[1], whyMe, gain end
        end
        if bud then table.insert(budHits, l[1]) end
        remaining = remaining - 1
        if remaining == 0 then
          if best then
            ns:Toast({ cat = "loot", header = isHandIn and "PICK THIS REWARD" or "QUEST REWARD UPGRADE", icon = itemIcon(tonumber(best:match("item:(%d+)"))),
              quality = 3, sound = "UPGRADE", body = best, sub = bestWhy .. (isHandIn and "" or " - accept " .. title .. "!") })
          end
          if #budHits > 0 and not isHandIn then
            ns:Toast({ cat = "loot", header = "UPGRADE FOR " .. ns:BuddyShortName():upper(), icon = itemIcon(tonumber(budHits[1]:match("item:(%d+)"))),
              quality = 2, body = budHits[1], sub = "Tell " .. ns:BuddyShortName() .. " to grab " .. title .. " in " .. (GetZoneText() or "") })
          end
        end
      end)
    end
  end
end

ns:On("QUEST_DETAIL", function() checkQuestFrame(false) end)
ns:On("QUEST_COMPLETE", function() checkQuestFrame(true) end)

---------------------------------------------------------------------------
-- Vendors
---------------------------------------------------------------------------
local function merchantPrice(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(i)
    return info and info.price
  end
  if GetMerchantItemInfo then return select(3, GetMerchantItemInfo(i)) end
end

ns:On("MERCHANT_SHOW", function()
  local npc = UnitName("npc") or "Vendor"
  local zone = GetZoneText()
  local n = GetMerchantNumItems and GetMerchantNumItems() or 0
  local found = { me = {}, buddy = {} }
  local remaining = 0
  for i = 1, n do
    local link = GetMerchantItemLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then
      remaining = remaining + 1
      local price = merchantPrice(i)
      evaluate(id, function(me, whyMe, bud, whyBud)
        local src = "Vendor: " .. npc .. (price and price > 0 and (" (" .. ns.FormatMoney(price) .. ")") or "")
        if me then add({ itemID = id, who = "me", kind = "vendor", src = src, zone = zone, why = whyMe }); table.insert(found.me, link) end
        if bud then add({ itemID = id, who = "buddy", kind = "vendor", src = src, zone = zone, why = whyBud }); table.insert(found.buddy, link) end
        remaining = remaining - 1
        if remaining == 0 and (#found.me > 0 or #found.buddy > 0) then
          local parts = {}
          if #found.me > 0 then table.insert(parts, #found.me .. " for you") end
          if #found.buddy > 0 then table.insert(parts, #found.buddy .. " for " .. ns:BuddyShortName()) end
          local first = found.me[1] or found.buddy[1]
          ns:Toast({ cat = "loot", header = "VENDOR UPGRADES", icon = itemIcon(tonumber(first:match("item:(%d+)"))), quality = 2,
            sound = "UPGRADE", body = npc .. " sells upgrades: " .. table.concat(parts, ", "), sub = "See the Upgrades tab" })
        end
      end)
    end
  end
end)

---------------------------------------------------------------------------
-- Sorted list for the UI
---------------------------------------------------------------------------
function ns:GetUpgradeList()
  local list = {}
  for _, e in pairs(upgrades) do table.insert(list, e) end
  table.sort(list, function(a, b)
    if a.who ~= b.who then return a.who == "me" end
    local ga = tonumber((a.why or ""):match("%+(%d+)")) or 99
    local gb = tonumber((b.why or ""):match("%+(%d+)")) or 99
    return ga > gb
  end)
  return list
end
