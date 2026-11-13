-- Tjommie: Demo mode (/tj demo)
-- Simulates a buddy walking circles around you and doing things, so you can test
-- the compass, map trail, feed, toasts and stats without a second player.
-- Your real buddy data is set aside during the demo and restored afterwards.

local _, ns = ...

local ticker, eventTicker
local saved
local angle = 0
local center

local function itemsFromBags()
  local ids = {}
  local getID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
  local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
  for bag = 0, 4 do
    for slot = 1, (getSlots(bag) or 0) do
      local id = getID(bag, slot)
      if id then table.insert(ids, id) end
    end
  end
  for slot = 1, 18 do
    local id = GetInventoryItemID("player", slot)
    if id then table.insert(ids, id) end
  end
  return ids
end

local function fake(...) ns:HandleMessage(table.concat({ ... }, "~")) end

local function demoMove()
  local mapID = center.mapID
  local w, h = C_Map.GetMapWorldSize(mapID)
  if not w or w == 0 then return end
  angle = angle + 0.05
  local r = 60 + 340 * (0.5 + 0.5 * math.cos(angle * 0.5)) -- drifts in and out so ETA shows
  local x = center.x + math.cos(angle) * r / w
  local y = center.y + math.sin(angle) * r / h
  fake("P", mapID, string.format("%.4f", x), string.format("%.4f", y), GetZoneText(), "Demo Hill")
end

local demoEvents = {
  function() fake("ST", "TAXI", "Stormwind") end,
  function() fake("ST", "FIRE", "") end,
  function() fake("ST", "", "") end,
  function() fake("E", "LVL", UnitLevel("player") + 1) end,
  function() fake("E", "ZONE", "The Barrens", 1) end,
  function() fake("E", "QUEST", "Demo quest: Wolves Across the Border") end,
  function() fake("E", "DEAD", "Demo Hill") end,
  function()
    local ids = itemsFromBags()
    if #ids > 0 then fake("E", "LOOT", ids[math.random(#ids)]) end
  end,
}

local function startDemo()
  local mapID, x, y = ns.GetPlayerPos()
  if not mapID then ns:Print("Demo needs a normal outdoor zone.") return end
  center = { mapID = mapID, x = x, y = y }

  saved = { buddy = ns.db.buddy, data = ns.buddy }
  ns.db.buddy = "Demobuddy-Demo"
  ns.buddy = { info = {}, stats = {}, wishlist = {}, gear = {}, trail = {}, pos = nil }
  ns.cdb.buddyData = ns.buddy
  ns.demoActive = true

  fake("HI", "MAGE", UnitLevel("player"), ns.VERSION, 0)
  fake("S", ns.EncodeStats({ class = "MAGE", level = UnitLevel("player"), xp = 4200, xpMax = 7000, gold = 123456,
    goldEarned = 234567, kills = 321, deaths = 4, quests = 55, zones = 7, distance = 45678, rares = 3, epics = 0,
    played = 36000, drinks = 12, smashed = 2, danced = 640, fireTime = 1500, fires = 3,
    playedTotal = 412000, questsTotal = 187 }))
  local ids = itemsFromBags()
  fake("W", table.concat({ ids[1] or "", ids[2] or "" }, ","))
  fake("PF", "Enchanting:142:150,Tailoring:150:150")
  fake("RC", "Tailoring", 1, 1, table.concat({ "i" .. (ids[1] or 2589), "i" .. (ids[2] or 2996) }, ","))

  ticker = C_Timer.NewTicker(1, demoMove)
  local i = 0
  eventTicker = C_Timer.NewTicker(7, function()
    i = i % #demoEvents + 1
    demoEvents[i]()
  end)
  ns:Print("Demo started: a fake buddy is walking circles around you. Open your map, and /tj demo again to stop.")
end

local function stopDemo()
  if ticker then ticker:Cancel() end
  if eventTicker then eventTicker:Cancel() end
  ticker, eventTicker = nil, nil
  ns.demoActive = false
  if saved then
    ns.db.buddy = saved.buddy
    ns.buddy = saved.data
    ns.cdb.buddyData = saved.data
    saved = nil
  end
  ns.buddyLastSeen = 0
  ns:Fire("BUDDY_CHANGED")
  ns:Fire("TRAIL_CHANGED")
  ns:Print("Demo stopped.")
end

function ns:ToggleDemo()
  if self.demoActive then stopDemo() else startDemo() end
end

-- Never save demo data
ns:On("PLAYER_LOGOUT", function()
  if ns.demoActive and saved then
    ns.db.buddy = saved.buddy
    ns.cdb.buddyData = saved.data
  end
end)
