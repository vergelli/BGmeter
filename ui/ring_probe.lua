
BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local R = {}
local win = nil

local VALUES = { 50, 30, 20 }
local COLORS = { { 0.42, 0.78, 0.50, 1 }, { 0.95, 0.80, 0.35, 1 }, { 0.64, 0.66, 0.58, 1 } }

local function build()
    if win then return end
    local ui = BGMeter.zenimax.ui
    local K = BGMeter.Constants
    local P = BGMeter.Plot.primitives
    local S = BGMeter.Plot.style
    local Donut = BGMeter.Plot.donut

    win = ui.wm:CreateTopLevelWindow("BGMeterRingProbe")
    win:SetDimensions(360, 190)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -160)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)

    local bg = P.rect(win, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.96 })
    bg:SetAnchorFill(win)
    P.frame(win):SetAnchorFill(win)

    local title = P.label(win, S.FONT.small, K.COLOR.text_dim)
    title:SetText("ring probe  ·  A: 96px 50/30/20   B: 34px haul colors   C: 96px plain texture")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 8)
    title:SetDimensions(340, 14)

    local a = Donut.new("BGMeterRingProbeA", win, 96)
    a:control():SetAnchor(TOPLEFT, win, TOPLEFT, 24, 40)
    a:set(VALUES, COLORS)

    local b = Donut.new("BGMeterRingProbeB", win, 34)
    b:control():SetAnchor(TOPLEFT, win, TOPLEFT, 150, 70)
    b:set({ 34, 66 }, { K.COLOR.you, { 1, 1, 1, 0.12 } })

    local c = P.icon(win, "bgmeter/assets/ring.dds")
    c:SetDimensions(96, 96)
    c:SetAnchor(TOPLEFT, win, TOPLEFT, 230, 40)

    local close = P.button(win, "EsoUI/Art/Buttons/decline_up.dds", "EsoUI/Art/Buttons/decline_down.dds", "EsoUI/Art/Buttons/decline_over.dds")
    close:SetDimensions(20, 20)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 8)
    close:SetHandler("OnClicked", function() win:SetHidden(true) end)

    R.a, R.b, R.c = a, b, c
end

function R.toggle()
    build()
    win:SetHidden(not win:IsHidden())
end

BGMeter.UI.ring_probe = R
