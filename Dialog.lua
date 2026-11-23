-- Tjommie: Dialog
-- Our own Yes/No pop-up. Forever's client distrusts the game's own pop-ups (and then item use
-- and spells) once an add-on writes to StaticPopupDialogs ("blocked from an action"), so
-- Tjommie never touches StaticPopup. Learned the hard way in Lantern v0.3.
--
-- ns:Confirm({
--   text = "...", accept = "Yes", cancel = "No",
--   onAccept = function() end,
--   onCancel = function() end,     -- only when the player clicks the cancel button
--   timeout = 120,                 -- seconds; closes quietly (no onCancel)
--   sound = true,                  -- ready-check sound if sounds are on
-- })
-- Only one dialog shows at a time; others wait their turn.

local _, ns = ...

local frame
local queue = {}
local current

local function create()
  local f = CreateFrame("Frame", "TjommieDialog", UIParent, "BackdropTemplate")
  f:SetSize(340, 140)
  f:SetPoint("TOP", UIParent, "TOP", 0, -135)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
  f:SetBackdropBorderColor(0.2, 1, 0.6, 0.9)

  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.text:SetPoint("TOPLEFT", 16, -16)
  f.text:SetPoint("TOPRIGHT", -16, -16)
  f.text:SetJustifyH("CENTER")
  f.text:SetSpacing(2)

  local function button(label, x)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(130, 24)
    b:SetPoint("BOTTOM", x, 14)
    b:SetText(label)
    return b
  end
  f.accept = button("Yes", -70)
  f.cancel = button("No", 70)

  f.accept:SetScript("OnClick", function() ns:CloseDialog("accept") end)
  f.cancel:SetScript("OnClick", function() ns:CloseDialog("cancel") end)
  f:SetScript("OnHide", function()
    -- Escape (UISpecialFrames) or anything else hiding us: treat as "decide later"
    if current then ns:CloseDialog("hidden") end
  end)
  f:SetScript("OnUpdate", function(self, dt)
    if not current or not current.timeout then return end
    current.left = (current.left or current.timeout) - dt
    if current.left <= 0 then ns:CloseDialog("timeout") end
  end)
  table.insert(UISpecialFrames, "TjommieDialog") -- Escape closes it
  f:Hide()
  return f
end

local function showNext()
  current = table.remove(queue, 1)
  if not current then return end
  frame = frame or create()
  frame.text:SetText(current.text or "")
  frame.accept:SetText(current.accept or "Yes")
  frame.cancel:SetText(current.cancel or "No")
  frame:SetHeight(math.max(110, (frame.text:GetStringHeight() or 40) + 64))
  frame:Show()
  if current.sound and ns.db and ns.db.sound and SOUNDKIT and SOUNDKIT.READY_CHECK then
    PlaySound(SOUNDKIT.READY_CHECK, "Master")
  end
end

-- how: "accept", "cancel", "timeout" or "hidden"
function ns:CloseDialog(how)
  local d = current
  current = nil
  if frame and frame:IsShown() then frame:Hide() end
  if d then
    if how == "accept" and d.onAccept then ns.SafeCall(d.onAccept)
    elseif how == "cancel" and d.onCancel then ns.SafeCall(d.onCancel) end
  end
  C_Timer.After(0.2, function() if not current then showNext() end end)
end

function ns:Confirm(opts)
  if type(opts) ~= "table" then return end
  -- A newer request with the same key replaces a waiting one (e.g. two pairing requests)
  if opts.key then
    for i = #queue, 1, -1 do if queue[i].key == opts.key then table.remove(queue, i) end end
  end
  table.insert(queue, opts)
  if not current then showNext() end
end

function ns:DialogShown() return current end
