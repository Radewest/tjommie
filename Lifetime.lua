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
-- Never replace the game's chat functions (that taints chat and gets add-ons "blocked from an
-- action" on Forever). Instead, chat windows briefly stop listening for this one reply.
local muted = {}

local function muteChat()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local cf = _G["ChatFrame" .. i]
    if cf and cf.IsEventRegistered and cf:IsEventRegistered("TIME_PLAYED_MSG") then
      if pcall(cf.UnregisterEvent, cf, "TIME_PLAYED_MSG") then table.insert(muted, cf) end
    end
  end
end

local function unmuteChat()
  for _, cf in ipairs(muted) do pcall(cf.RegisterEvent, cf, "TIME_PLAYED_MSG") end
  wipe(muted)
end

local lastPlayed = 0
function ns:RequestPlayed(force)
  if type(RequestTimePlayed) ~= "function" then return end
  if InCombatLockdown and InCombatLockdown() then return end
  if not force and GetTime() - lastPlayed < 300 then return end
  lastPlayed = GetTime()
  if #muted == 0 then muteChat() end
  RequestTimePlayed()
  C_Timer.After(5, unmuteChat)  -- safety net if the reply never comes
end

ns:On("TIME_PLAYED_MSG", function(total)
  C_Timer.After(0.5, unmuteChat)
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
