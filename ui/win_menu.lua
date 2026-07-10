BGMeter = BGMeter or {}
local BGMeter = BGMeter

local U = BGMeter.UI._win
local W = U.W
local set_text, mk_button, hide_all = U.set_text, U.mk_button, U.hide_all
local TX = U.TX

local K = BGMeter.Constants
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prefs = BGMeter.Prefs
local Sound = BGMeter.Sound

local M = {}

local LAUNCHER_TX = {
    n = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_up.dds",
    p = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_down.dds",
    o = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_over.dds",
}

local MODE_SHORT = {
    deathmatch = "DM", domination = "DOM", crazy_king = "CK",
    king_of_the_hill = "KOTH", capture_the_flag = "CTF", murderball = "BALL",
}

local MENU_W = 336
local ROW_H = 26
local MAX_VIS = 12

local built = false
local launcher = nil
local panel = nil
local rows = {}
local offset = 0
local on_hud = true

local function sv_launcher()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return { x = 0, y = 0 } end
    sv.launcher = sv.launcher or { x = 0, y = 0 }
    return sv.launcher
end

local function ago_label(capturedAt)
    local A = BGMeter.zenimax.api
    local now = (type(A.get_timestamp) == "function") and A.get_timestamp() or nil
    if not capturedAt or not now or now <= capturedAt then return "" end
    local s = now - capturedAt
    if s < 3600 then return math.floor(s / 60) .. "m ago" end
    if s < 86400 then return math.floor(s / 3600) .. "h ago" end
    return math.floor(s / 86400) .. "d ago"
end

local function result_color(res)
    if res == "WIN" then return K.COLOR.heal end
    if res == "LOSS" then return K.COLOR.accent end
    if res == "TIE" then return K.COLOR.gold end
    return K.COLOR.text_dim
end

local function mode_tag(m)
    local C = BGMeter.zenimax.constants
    local gt = C.GAME_TYPE_LABEL[m.gameType]
    local tag = MODE_SHORT[gt] or "?"
    if m.teamSize then tag = tag .. "  " .. m.teamSize .. "v" .. m.teamSize end
    return tag
end

local function make_row(i)
    local r = {}
    r.container = BGMeter.zenimax.ui.create_control(nil, panel.win, CT_CONTROL)
    r.container:SetDimensions(MENU_W - 24, ROW_H)
    r.container:SetMouseEnabled(true)

    r.highlight = P.rect(r.container, { 1, 1, 1, K.ALPHA.row_hover })
    r.highlight:SetAnchorFill(r.container)
    r.highlight:SetHidden(true)

    r.pip = P.rect(r.container, K.COLOR.text_dim)
    r.pip:SetDimensions(3, ROW_H - 10)
    r.pip:SetAnchor(LEFT, r.container, LEFT, 2, 0)

    r.name = P.label(r.container, S.FONT.row, K.COLOR.text)
    r.name:SetAnchor(LEFT, r.container, LEFT, 12, 0)
    r.name:SetDimensions(150, ROW_H)

    r.mode = P.label(r.container, S.FONT.small, K.COLOR.text_dim)
    r.mode:SetAnchor(LEFT, r.container, LEFT, 166, 0)
    r.mode:SetDimensions(64, ROW_H)

    r.ago = P.label(r.container, S.FONT.small, K.COLOR.text_dim)
    r.ago:SetAnchor(RIGHT, r.container, RIGHT, -24, 0)
    r.ago:SetDimensions(56, ROW_H)
    r.ago:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    r.del = mk_button(r.container, TX.close, 14, function()
        M.delete(r.index)
    end, "Delete this match")
    r.del:SetAnchor(RIGHT, r.container, RIGHT, -4, 0)

    r.container:SetHandler("OnMouseEnter", function() r.highlight:SetHidden(false) end)
    r.container:SetHandler("OnMouseExit", function() r.highlight:SetHidden(true) end)
    r.container:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside and r.index then
            Sound.play("open")
            BGMeter.UI.window.show_match(r.index)
        end
    end)
    return r
end

local function build()
    if built then return end

    local g = sv_launcher()
    local win = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterLauncher")
    win:SetDimensions(40, 40)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    if g.x == 0 and g.y == 0 then
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 24, 240)
    else
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, g.x, g.y)
    end
    win:SetHandler("OnMoveStop", function()
        g = sv_launcher()
        g.x, g.y = win:GetLeft(), win:GetTop()
    end)
    win:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside then M.toggle() end
    end)
    launcher = { win = win }

    launcher.icon = P.icon(win, LAUNCHER_TX.n)
    launcher.icon:SetAnchorFill(win)
    win:SetHandler("OnMouseEnter", function()
        launcher.icon:SetTexture(LAUNCHER_TX.o)
        if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(win, RIGHT, "bgmeter  ·  battle registry") end
    end)
    win:SetHandler("OnMouseExit", function()
        launcher.icon:SetTexture(LAUNCHER_TX.n)
        if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
    end)

    local pw = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterMenu")
    pw:SetDimensions(MENU_W, 120)
    pw:SetMouseEnabled(true)
    pw:SetMovable(true)
    pw:SetClampedToScreen(true)
    pw:SetHidden(true)
    pw:SetDrawTier(DT_HIGH)
    pw:SetHandler("OnMouseWheel", function(_, delta)
        local count = BGMeter.History.count()
        local maxOff = math.max(0, count - MAX_VIS)
        local want = math.max(0, math.min(offset - delta, maxOff))
        if want ~= offset then
            offset = want
            M.refresh()
        end
    end)
    panel = { win = pw }

    local bg = P.rect(pw, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.98 })
    bg:SetAnchorFill(pw)
    P.frame(pw):SetAnchorFill(pw)

    local strip = P.rect(pw, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, pw, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, pw, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    panel.title = P.label(pw, S.FONT.title, K.COLOR.text)
    panel.title:SetText("bgmeter  ·  Registry")
    panel.title:SetAnchor(TOPLEFT, pw, TOPLEFT, 16, 15)

    panel.close = mk_button(pw, TX.close, 20, function() M.hide_menu() end, "Close")
    panel.close:SetAnchor(TOPRIGHT, pw, TOPRIGHT, -14, 15)

    panel.gear = mk_button(pw, TX.gear, 22, function() W.toggle_settings() end, "Settings")
    panel.gear:SetAnchor(RIGHT, panel.close, LEFT, -8, 0)

    panel.empty = P.label(pw, S.FONT.small, K.COLOR.text_dim)
    panel.empty:SetText("no battlegrounds recorded yet")
    panel.empty:SetAnchor(TOP, pw, TOP, 0, 52)
    panel.empty:SetHidden(true)

    panel.footer = P.label(pw, S.FONT.small, K.COLOR.text_dim)
    panel.footer:SetAnchor(BOTTOM, pw, BOTTOM, 0, -10)
    panel.footer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    built = true
end

function M.refresh()
    if not built or panel.win:IsHidden() then return end
    local H = BGMeter.History
    local count = H.count()
    local maxOff = math.max(0, count - MAX_VIS)
    if offset > maxOff then offset = maxOff end
    local vis = math.min(count, MAX_VIS)

    panel.win:SetHeight(48 + math.max(vis * ROW_H, 34) + 30)
    panel.empty:SetHidden(count > 0)

    for i = 1, vis do
        local r = rows[i]
        if not r then
            r = make_row(i)
            rows[i] = r
        end
        local idx = offset + i
        local m = H.get(idx)
        r.index = idx
        r.container:ClearAnchors()
        r.container:SetAnchor(TOPLEFT, panel.win, TOPLEFT, 12, 44 + (i - 1) * ROW_H)
        r.container:SetHidden(false)
        r.highlight:SetHidden(true)
        local rc = result_color(m.result)
        P.set_rect_color(r.pip, rc)
        set_text(r.name, m.name or "Battleground")
        S.color(r.name, (BGMeter.UI.window.current() == idx and not BGMeter.UI.window.is_hidden()) and K.COLOR.you or K.COLOR.text)
        set_text(r.mode, mode_tag(m))
        set_text(r.ago, ago_label(m.capturedAt))
    end
    for i = vis + 1, #rows do
        rows[i].container:SetHidden(true)
        rows[i].index = nil
    end

    if count > MAX_VIS then
        set_text(panel.footer, string.format("%d-%d of %d  ·  scroll for more", offset + 1, offset + vis, count))
    else
        set_text(panel.footer, count > 0 and (count .. (count == 1 and " battleground" or " battlegrounds")) or "")
    end
end

function M.delete(index)
    if not BGMeter.History.delete(index) then return end
    Sound.play("nav")
    W.on_history_changed(index)
    M.refresh()
end

function M.show_menu()
    if not built then return end
    panel.win:ClearAnchors()
    panel.win:SetAnchor(TOPLEFT, launcher.win, BOTTOMRIGHT, 2, 2)
    panel.win:SetHidden(false)
    offset = 0
    M.refresh()
    Sound.play("open")
end

function M.hide_menu()
    if built then panel.win:SetHidden(true) end
end

function M.toggle()
    if not built then return end
    if panel.win:IsHidden() then M.show_menu() else M.hide_menu() end
end

function M.refresh_if_visible()
    if built and not panel.win:IsHidden() then M.refresh() end
end

function M.sync()
    if not built then return end
    local vis = Prefs.get("show_launcher") and on_hud
    launcher.win:SetHidden(not vis)
    if not vis then M.hide_menu() end
end

function M.on_scene(hud)
    on_hud = hud
    M.sync()
end

function M.init()
    build()
    if SCENE_MANAGER then
        local function handler(_, newState)
            if newState == SCENE_SHOWN then M.on_scene(true)
            elseif newState == SCENE_HIDDEN then M.on_scene(false) end
        end
        for _, name in ipairs({ "hud", "hudui" }) do
            local ok, sc = pcall(function() return SCENE_MANAGER:GetScene(name) end)
            if ok and sc and type(sc.RegisterCallback) == "function" then
                pcall(function() sc:RegisterCallback("StateChange", handler) end)
            end
        end
    end
    on_hud = (BGMeter.zenimax.scene and BGMeter.zenimax.scene.is_hud_scene()) and true or false
    M.sync()
    BGMeter.Log.debug("menu ready (launcher %s)", Prefs.get("show_launcher") and "shown" or "hidden")
end

BGMeter.UI.menu = M
