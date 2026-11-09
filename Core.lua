-- Tjommie: Core
-- Namespace, saved variables, event + internal callback plumbing, helpers, slash commands.

local ADDON, ns = ...
_G.Tjommie = ns -- handy for /dump Tjommie while developing

ns.PREFIX  = "Tjommie"      -- addon message prefix (max 16 chars)
ns.VERSION = "0.4.0"

---------------------------------------------------------------------------
-- API shims (Forever runs the modern client; keep fallbacks just in case)
---------------------------------------------------------------------------
ns.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
ns.GetItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
ns.GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

-- Midnight-era "secret values": some data is hidden from addons in combat/instances.
function ns.IsSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

---------------------------------------------------------------------------
-- Event plumbing
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame
local eventHandlers = {}

function ns:On(event, fn)
  if not eventHandlers[event] then
    eventHandlers[event] = {}
    eventFrame:RegisterEvent(event)
  end
  table.insert(eventHandlers[event], fn)
end

---------------------------------------------------------------------------
-- Self bug-logging: errors are saved to TjommieDB.errors (see Bugs.lua, /tj bugs)
---------------------------------------------------------------------------
local function addStack(e)
  return tostring(e) .. "\n" .. (debugstack and debugstack(2, 10, 0) or "")
end

-- Run fn safely; on error, log it and pass it on to the normal error handler (BugSack etc.)
function ns.SafeCall(fn, ...)
  local args, n = { ... }, select("#", ...)
  local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, addStack)
  if not ok then ns:ReportError(err) end
  return ok
end

function ns:ReportError(err, skipHandler)
  if self.LogError then pcall(self.LogError, self, err) end
  if not skipHandler then
    self.reporting = true   -- stops Bugs.lua's global hook logging the same error twice
    pcall(geterrorhandler(), (tostring(err):match("^[^\n]*")))
    self.reporting = false
  end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = eventHandlers[event]
  if not list then return end
  for _, fn in ipairs(list) do ns.SafeCall(fn, ...) end
end)

-- Internal callbacks (ns:Fire("BUDDY_POS") -> listeners)
local callbacks = {}
function ns:Listen(name, fn)
  callbacks[name] = callbacks[name] or {}
  table.insert(callbacks[name], fn)
end
function ns:Fire(name, ...)
  local list = callbacks[name]
  if not list then return end
  for _, fn in ipairs(list) do ns.SafeCall(fn, ...) end
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local DEFAULTS = {
  errors = {},               -- bug log (Bugs.lua)
  buddy = nil,               -- "Name-Realm"
  compassShown = true,       -- tracker bar
  barPos = nil,
  minimapAngle = 200,
  minimapHidden = false,
  tomtom = false,
  windowPos = nil,
  showMyTrail = false,
  toasts = true,
  sound = true,
  -- v0.4 settings
  chat = "important",        -- "off" | "important" | "all"
  popups = { level = true, death = true, loot = true, fun = true, online = true },
  barLocked = false,
  barScale = 1,
  barAlpha = 1,
  barHideInstance = true,    -- hide the tracker bar in dungeons/raids
  barCombatFade = true,      -- fade the tracker bar in combat
  windowScale = 1,
  windowSize = nil,          -- { w, h }
  showBuddyTrail = true,
  trailLength = 1500,        -- points kept per trail
  sharePosition = true,      -- privacy: pause sharing your position
  hideGold = false,          -- privacy: don't share your gold
  welcomed = false,
}

local CHAR_DEFAULTS = {
  stats = {
    goldEarned = 0, kills = 0, deaths = 0, quests = 0, zones = 0,
    distance = 0, rares = 0, epics = 0, played = 0,
    drinks = 0, smashed = 0, danced = 0, fireTime = 0, fires = 0,
  },
  zonesSeen = {},
  wishlist = {},             -- array of itemIDs
  myTrail = {},              -- { {c, x, y, t}, ... } world coords
  feed = {},                 -- { {t, text}, ... }
  lifetime = {},             -- whole-character stats from the game (Lifetime.lua)
  buddyData = {              -- last known data from buddy (persisted)
    info = {}, stats = {}, wishlist = {}, gear = {}, trail = {}, pos = nil,
  },
}

local function applyDefaults(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then
      if type(v) == "table" then
        dst[k] = {}
        applyDefaults(dst[k], v)
      else
        dst[k] = v
      end
    elseif type(v) == "table" and type(dst[k]) == "table" then
      applyDefaults(dst[k], v)
    end
  end
end

ns:On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  TjommieDB = TjommieDB or {}
  TjommieCharDB = TjommieCharDB or {}
  applyDefaults(TjommieDB, DEFAULTS)
  applyDefaults(TjommieCharDB, CHAR_DEFAULTS)
  ns.db = TjommieDB
  ns.cdb = TjommieCharDB
  ns.buddy = TjommieCharDB.buddyData
  ns:Fire("DB_READY")
end)

ns:On("PLAYER_LOGIN", function()
  ns:Fire("LOGIN")
  if not ns.db.buddy then
    ns:Chat("No tjommie yet: right-click your friend and choose |cff33ff99Add as Tjommie|r, or type |cffffff00/tj pick|r.")
  end
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function ns:Print(msg)
  print("|cff33ff99Tjommie|r: " .. tostring(msg))
end

-- Chat output that respects the "Chat messages" setting.
-- level "important": shown unless chat is Off. level "all": only shown when chat is set to Everything.
-- (Direct replies to slash commands use ns:Print and always show.)
function ns:Chat(msg, level)
  local setting = self.db and self.db.chat or "important"
  if setting == "off" then return end
  if level == "all" and setting ~= "all" then return end
  self:Print(msg)
end

function ns.NormRealm(realm)
  if not realm then return nil end
  return (realm:gsub("[%s%-']", ""))
end

function ns.FullName(name)
  if not name or name == "" then return nil end
  if not name:find("-", 1, true) then
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if realm then name = name .. "-" .. realm end
  end
  return name
end

function ns:BuddyShortName()
  local b = self.db and self.db.buddy
  if not b then return "Buddy" end
  return (strsplit("-", b))
end

function ns:IsBuddy(sender)
  if not sender or ns.IsSecret(sender) or not self.db.buddy then return false end
  local full = ns.FullName(sender)
  return full and full:lower() == self.db.buddy:lower()
end

function ns.ClassColor(class)
  local c = (C_ClassColor and class and C_ClassColor.GetClassColor(class))
         or (RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class])
  if c then return c.r, c.g, c.b end
  return 0.2, 1, 0.6
end

function ns.ClassColorHex(class)
  local r, g, b = ns.ClassColor(class)
  return string.format("ff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Round class portrait (falls back to the Tjommie icon for unknown classes)
function ns.SetClassIcon(tex, class)
  local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if coords then
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    tex:SetTexCoord(unpack(coords))
  else
    tex:SetTexture("Interface\\AddOns\\Tjommie\\media\\icon")
    tex:SetTexCoord(0, 1, 0, 1)
  end
end

function ns.ClassName(class)
  return class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or (class:sub(1, 1) .. class:sub(2):lower())) or ""
end

function ns.FormatMoney(copper)
  copper = math.floor(copper or 0)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  if g > 0 then return string.format("%dg %ds", g, s) end
  if s > 0 then return string.format("%ds %dc", s, c) end
  return c .. "c"
end

function ns.FormatDistance(yd)
  yd = math.floor(yd or 0)
  if yd >= 10000 then return string.format("%.1fk yd", yd / 1000) end
  return string.format("%d yd", yd)
end

function ns.FormatTime(sec)
  sec = math.floor(sec or 0)
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  if h > 0 then return string.format("%dh %dm", h, m) end
  if m > 0 then return m .. "m" end
  return sec .. "s"
end

-- Current player position: mapID, x, y, continentID, worldX, worldY (or nil in instances)
function ns.GetPlayerPos()
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return end
  local x, y = pos:GetXY()
  if not x or ns.IsSecret(x) or (x == 0 and y == 0) then return end
  local continent, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
  local wx, wy
  if world then wx, wy = world:GetXY() end
  return mapID, x, y, continent, wx, wy
end

-- Convert a zone map position to world coordinates.
function ns.MapToWorld(mapID, x, y)
  if not (mapID and x and y) then return end
  local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
  if not world then return end
  local wx, wy = world:GetXY()
  return continent, wx, wy
end

-- Project world coordinates onto a given map. Returns x, y (0..1 when on the map).
function ns.WorldToMap(continent, wx, wy, mapID)
  if not (continent and wx and mapID) then return end
  local _, pos = C_Map.GetMapPosFromWorldPos(continent, CreateVector2D(wx, wy), mapID)
  if not pos then return end
  return pos:GetXY()
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
  "|cffffff00/tj|r - open/close the Tjommie window",
  "|cffffff00/tj set|r - send a tjommie request to your target (or |cffffff00/tj set Name[-Realm]|r)",
  "|cffffff00/tj pick|r - choose a tjommie from your online friends",
  "   ...or right-click any player and choose |cff33ff99Add as Tjommie|r",
  "|cffffff00/tj bar|r - show/hide the tracker bar",
  "|cffffff00/tj tomtom|r - point TomTom's arrow at your tjommie (needs TomTom)",
  "|cffffff00/tj minimap|r - show/hide the minimap button",
  "|cffffff00/tj wish [item link or ID]|r - add to your wishlist",
  "|cffffff00/tj unwish [item link or ID]|r - remove from your wishlist",
  "|cffffff00/tj trail clear|r / |cffffff00/tj trail mine|r - clear trails / toggle your own trail",
  "|cffffff00/tj sound|r / |cffffff00/tj toasts|r - toggle alert sound / pop-ups",
  "|cffffff00/tj settings|r - open settings",
  "|cffffff00/tj welcome|r - show the welcome guide again",
  "|cffffff00/tj demo|r - simulate a buddy (for testing solo)",
  "|cffffff00/tj bugs|r - show Tjommie's bug log (copy it and send it to the developer)",
}

SLASH_TJOMMIE1 = "/tj"
SLASH_TJOMMIE2 = "/tjommie"
SlashCmdList.TJOMMIE = function(msg)
  msg = msg or ""
  local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()

  if cmd == "" then
    ns:ToggleWindow()
  elseif cmd == "set" then
    if rest == "" then
      ns:PairWithTarget()
    else
      local name = rest:gsub("^%l", string.upper)
      ns:SetBuddy(name)
      ns:RequestPair(name)
    end
  elseif cmd == "pick" then
    ns:ShowPicker()
  elseif cmd == "compass" or cmd == "bar" then
    ns.db.compassShown = not ns.db.compassShown
    ns:Fire("COMPASS_TOGGLE")
  elseif cmd == "tomtom" then
    ns:ToggleTomTom()
  elseif cmd == "minimap" then
    ns.db.minimapHidden = not ns.db.minimapHidden
    ns:Fire("MINIMAP_TOGGLE")
  elseif cmd == "wish" then
    ns:AddWish(rest)
  elseif cmd == "unwish" then
    ns:RemoveWish(rest)
  elseif cmd == "trail" then
    if rest == "clear" then
      ns.buddy.trail = {}
      ns.cdb.myTrail = {}
      ns:Print("Trails cleared.")
    elseif rest == "mine" then
      ns.db.showMyTrail = not ns.db.showMyTrail
      ns:Print("Your own trail: " .. (ns.db.showMyTrail and "shown" or "hidden"))
    end
    ns:Fire("TRAIL_CHANGED")
  elseif cmd == "sound" then
    ns.db.sound = not ns.db.sound
    ns:Print("Sound " .. (ns.db.sound and "on" or "off"))
  elseif cmd == "toasts" then
    ns.db.toasts = not ns.db.toasts
    ns:Print("Pop-ups " .. (ns.db.toasts and "on" or "off"))
  elseif cmd == "bugs" then
    if rest == "clear" then ns:ClearErrors() else ns:ShowBugs() end
  elseif cmd == "settings" or cmd == "options" or cmd == "config" then
    ns:OpenSettings()
  elseif cmd == "welcome" then
    ns:ShowWelcome()
  elseif cmd == "demo" then
    ns:ToggleDemo()
  else
    for _, line in ipairs(HELP) do print(line) end
  end
end
