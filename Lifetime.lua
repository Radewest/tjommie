-- Tjommie: Lifetime stats
-- Whole-character numbers the game itself keeps (not just since Tjommie was installed):
--   * total time played      (RequestTimePlayed, with the chat print-out suppressed)
--   * total quests completed (completed quest IDs)
--   * kills / deaths / drinks from Blizzard's Statistics, IF Forever has them (GetStatistic)
-- Stored in TjommieCharDB.lifetime and shared with your tjommie in the stats message.

local _, ns = ...

-- Blizzard Statistic IDs (only used when the client supports GetStatistic and returns a number)
local STATISTICS = {
  killsTotal  = 1197,  -- Total kills
  deathsTotal = 60,    -- Total deaths
  drinksTotal = 346,   -- Beverages consumed
}

local function statNumber(id)
  if type(GetStatistic) ~= "function" then return nil end
  local ok, value = pcall(GetStatistic, id)
  if not ok or type(value) ~= "string" or ns.IsSecret(value) then return nil end
  return tonumber((value:gsub("[^%d]", "")))
end

local function completedQuestCount()
  if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
    local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
    if ok and type(ids) == "table" then return #ids end
  end
  if type(GetQuestsCompleted) == "function" then
    local ok, t = pcall(GetQuestsCompleted)
    if ok and type(t) == "table" then
      local n = 0
      for _ in pairs(t) do n = n + 1 end
      return n
    end
  end
end

function ns:UpdateLifetime()
  local life = self.cdb.lifetime
  life.questsTotal = completedQuestCount() or life.questsTotal
  for key, id in pairs(STATISTICS) do
    local v = statNumber(id)
    if v then life[key] = v end
  end
  self:Fire("LIFETIME_UPDATED")
end

---------------------------------------------------------------------------
-- /played without the chat spam
---------------------------------------------------------------------------
local suppressing = false
local hooked = {}

local function suppress(tbl, name)
  if type(tbl[name]) ~= "function" or hooked[name] then return end
  local original = tbl[name]
  hooked[name] = true
  tbl[name] = function(...)
    if suppressing then return end
    return original(...)
  end
end

function ns:RequestPlayed()
  if type(RequestTimePlayed) ~= "function" then return end
  suppress(_G, "ChatFrame_DisplayTimePlayed")
  if ChatFrameUtil then suppress(ChatFrameUtil, "DisplayTimePlayed") end
  suppressing = true
  RequestTimePlayed()
  C_Timer.After(5, function() suppressing = false end)  -- safety net
end

ns:On("TIME_PLAYED_MSG", function(total)
  suppressing = false
  if total and not ns.IsSecret(total) then
    ns.cdb.lifetime.playedTotal = math.floor(total)
    ns:Fire("LIFETIME_UPDATED")
  end
end)

ns:On("QUEST_TURNED_IN", function() C_Timer.After(2, function() ns:UpdateLifetime() end) end)

ns:Listen("LOGIN", function()
  C_Timer.After(10, function()
    ns:UpdateLifetime()
    ns:RequestPlayed()
  end)
  C_Timer.NewTicker(900, function() ns:RequestPlayed() end)  -- every 15 minutes
  C_Timer.NewTicker(120, function() ns:UpdateLifetime() end)
end)
