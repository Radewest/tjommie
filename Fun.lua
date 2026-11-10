-- Tjommie: Fun stats
--   Drinks        - each time your drunk level goes up ("You feel tipsy/drunk/completely smashed")
--   Got smashed   - times you reached "completely smashed"
--   Time dancing  - /dance until you move, jump, cast or emote something else
--   Gees Vuur     - time spent with the "Campfire Nearby" buff, plus campfires you've lit

local _, ns = ...

local GEES_VUUR = "Gees Vuur"
local FIRE_AURAS = { "Campfire Nearby", "Welcoming Campfire" }
local FIRE_SPELLS = { [818] = true, [1283400] = true, [1291341] = true } -- Basic / Journeyman / Expert Campfire
local FIRE_ICON = "Interface\\Icons\\Spell_Fire_Fire"
local BEER_ICON = "Interface\\Icons\\INV_Drink_05"

---------------------------------------------------------------------------
-- Drinks
---------------------------------------------------------------------------
local function toPattern(fmt)
  if not fmt then return nil end
  return "^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", ".+") .. "$"
end

local drunkPatterns = {}  -- { pattern, level }
for level = 2, 4 do
  for _, g in ipairs({ _G["DRUNK_MESSAGE_SELF" .. level], _G["DRUNK_MESSAGE_ITEM_SELF" .. level] }) do
    local p = toPattern(g)
    if p then table.insert(drunkPatterns, { p, level }) end
  end
end

ns:On("CHAT_MSG_SYSTEM", function(msg)
  if not msg or ns.IsSecret(msg) then return end
  for _, d in ipairs(drunkPatterns) do
    if msg:match(d[1]) then
      local stats = ns.cdb.stats
      stats.drinks = stats.drinks + 1
      if d[2] == 4 then
        stats.smashed = stats.smashed + 1
        ns:AddFeed("You got completely smashed in " .. (GetZoneText() or "?") .. ".", false, BEER_ICON)
        ns:Send("E", "SMASHED", GetZoneText() or "")
        ns:Fire("MY_SMASHED")
      end
      return
    end
  end
end)

---------------------------------------------------------------------------
-- Dancing
---------------------------------------------------------------------------
local dancing = false
local danceStartGrace = 0

local function onEmote(token)
  if type(token) ~= "string" then return end
  if token:upper() == "DANCE" then
    dancing = true
    danceStartGrace = GetTime() + 0.5   -- ignore the first moment (you might still be sliding)
  else
    dancing = false
  end
end

if type(DoEmote) == "function" then hooksecurefunc("DoEmote", onEmote) end
if C_ChatInfo and type(C_ChatInfo.PerformEmote) == "function" then
  hooksecurefunc(C_ChatInfo, "PerformEmote", onEmote)
end
if type(JumpOrAscendStart) == "function" then
  hooksecurefunc("JumpOrAscendStart", function() dancing = false end)
end
ns:On("UNIT_SPELLCAST_START", function(unit) if unit == "player" then dancing = false end end)
ns:On("PLAYER_REGEN_DISABLED", function() dancing = false end)

---------------------------------------------------------------------------
-- Gees Vuur (campfires)
---------------------------------------------------------------------------
local function hasAura(name)
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
    if ok and data then return true end
  end
  if AuraUtil and AuraUtil.FindAuraByName then
    local ok, found = pcall(AuraUtil.FindAuraByName, name, "player", "HELPFUL")
    if ok and found then return true end
  end
  return false
end

local atFire = false
local function nearFire()
  for _, name in ipairs(FIRE_AURAS) do
    if hasAura(name) then return true end
  end
  return false
end

ns:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit ~= "player" or ns.IsSecret(spellID) or not FIRE_SPELLS[spellID] then return end
  local zone = GetZoneText() or "?"
  ns.cdb.stats.fires = ns.cdb.stats.fires + 1
  ns:AddFeed("You lit a " .. GEES_VUUR .. " in " .. zone .. ".", false, FIRE_ICON)
  ns:Send("E", "FIRE", zone)
end)

---------------------------------------------------------------------------
-- 1-second ticker for timers
---------------------------------------------------------------------------
ns:Listen("LOGIN", function()
  C_Timer.NewTicker(1, function()
    local stats = ns.cdb.stats

    if dancing then
      if GetTime() > danceStartGrace and ((GetUnitSpeed and GetUnitSpeed("player") or 0) > 0 or (IsFalling and IsFalling())) then
        dancing = false
      else
        stats.danced = stats.danced + 1
      end
    end

    local fire = nearFire()
    if fire then stats.fireTime = stats.fireTime + 1 end
    if fire and not atFire then
      ns:Send("E", "ATFIRE", GetZoneText() or "")
    end
    atFire = fire
  end)
end)

---------------------------------------------------------------------------
-- Buddy events
---------------------------------------------------------------------------
ns.buddyEventHandlers.SMASHED = function(zone)
  ns:AddFeed(ns.BuddyNameColored() .. " got |cffff8800completely smashed|r in " .. (zone or "?") .. ". Gesondheid!", true, BEER_ICON)
  ns:Toast({ cat = "fun", header = "GESONDHEID!", icon = BEER_ICON, quality = 1,
    body = ns.BuddyNameColored() .. " got completely smashed", sub = zone or "" })
end

ns.buddyEventHandlers.FIRE = function(zone)
  ns:AddFeed(ns.BuddyNameColored() .. " lit a |cffff8800" .. GEES_VUUR .. "|r in " .. (zone or "?") .. ".", true, FIRE_ICON)
  ns:Toast({ cat = "fun", header = GEES_VUUR:upper(), icon = FIRE_ICON, quality = 1,
    body = ns.BuddyNameColored() .. " lit a " .. GEES_VUUR, sub = (zone or "") .. " - pull up a chair!" })
end

ns.buddyEventHandlers.ATFIRE = function(zone)
  ns:AddFeed(ns.BuddyNameColored() .. " is chilling at a |cffff8800" .. GEES_VUUR .. "|r in " .. (zone or "?") .. ".", true, FIRE_ICON)
end

-- Read-only accessors (used by Status.lua and Badges.lua)
function ns:IsDancing() return dancing end
function ns:IsAtFire() return atFire end
