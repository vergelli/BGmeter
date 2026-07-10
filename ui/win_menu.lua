BGMeter = BGMeter or {}
local BGMeter = BGMeter

local U = BGMeter.UI._win
local W = U.W
local set_text, mk_button = U.set_text, U.mk_button
local TX = U.TX

local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prefs = BGMeter.Prefs
local Sound = BGMeter.Sound

local M = {}

local LAUNCHER_ICON = "bgmeter/assets/launcher.dds"
local LAUNCHER_IDLE = 0.90

local MENU_ART = "esoui/art/loadingscreens/loadscreen_battleground_ularra_01.dds"
local MENU_ART_ALPHA = 0.30

local ROW_BASE      = "EsoUI/Art/Miscellaneous/listItem_backdrop.dds"
local ROW_HIGHLIGHT = "EsoUI/Art/Miscellaneous/listItem_highlight.dds"

local MODE_SHORT = {
    deathmatch = "DM", domination = "DOM", crazy_king = "CK",
    king_of_the_hill = "KOTH", capture_the_flag = "CTF", murderball = "BALL",
}

local MENU_W = 372
local MENU_H = 470
local ROW_H = 28
local HEAD_H = 46
local PANEL_H = 102
local FOOT_H = 34
local INSET_PAD = 20
local MIN_H, MAX_AUTO_H = 330, 700

local TELVAR = CURT_TELVAR_STONES

local built = false
local launcher = nil
local panel = nil
local rows = {}
local offset = 0
local on_hud = true

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function clean(s)
    if not s or s == "" then return nil end
    return (tostring(s):gsub("%^.*$", ""))
end

local function sv_launcher()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return { x = 0, y = 0 } end
    sv.launcher = sv.launcher or { x = 0, y = 0 }
    return sv.launcher
end

local function sv_menu()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return { x = 0, y = 0, w = 0, h = 0 } end
    sv.menu = sv.menu or { x = 0, y = 0, w = 0, h = 0 }
    return sv.menu
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

local art_tries = 0

local function apply_art_cover()
    if not built then return end
    local art = panel.art
    local w = panel.win:GetWidth() - 4
    local h = panel.win:GetHeight() - 4
    if w <= 0 or h <= 0 then return end
    local tw, th
    pcall(function() tw, th = art:GetTextureFileDimensions() end)
    if not tw or tw <= 0 or not th or th <= 0 then
        art:SetTextureCoords(0, 1, 0, 1)
        if art_tries < 3 and type(zo_callLater) == "function" then
            art_tries = art_tries + 1
            zo_callLater(apply_art_cover, 350)
        end
        return
    end
    art_tries = 0
    local ca = w / h
    local ta = tw / th
    if ta > ca then
        local uw = ca / ta
        local u0 = (1 - uw) / 2
        art:SetTextureCoords(u0, u0 + uw, 0, 1)
    else
        local vh = ta / ca
        local v0 = (1 - vh) / 2
        art:SetTextureCoords(0, 1, v0, v0 + vh)
    end
end

local function auto_height()
    local mg = sv_menu()
    if (mg.h or 0) > 0 then return end
    local count = BGMeter.History.count()
    local want = HEAD_H + PANEL_H + FOOT_H + 18 + math.max(count, 1) * ROW_H
    panel.win:SetHeight(math.max(MIN_H, math.min(want, MAX_AUTO_H)))
end

local function refresh_panel()
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants

    local st = panel.stats.ava
    local rank = safe(A.get_ava_rank)
    if rank and rank > 0 then
        st.c:SetHidden(false)
        local gender = safe(A.get_gender) or 1
        local rname = clean(safe(A.get_ava_rank_name, gender, rank)) or "?"
        if st.icon then st.icon:SetTexture(safe(A.get_ava_rank_icon, rank) or "") end
        set_text(st.label, string.format("%s  %d", rname, rank))
        local pts = safe(A.get_ava_rank_points) or 0
        local nextNeed = safe(A.get_ava_points_needed, rank + 1)
        if nextNeed and nextNeed > pts then
            st.tip = string.format("Alliance War rank %d\n%s AP to the next rank", rank, F.commas(nextNeed - pts))
        else
            st.tip = string.format("Alliance War rank %d", rank)
        end
    else
        st.c:SetHidden(true)
    end

    st = panel.stats.vet
    local snap = BGMeter.Veterancy and BGMeter.Veterancy.snapshot()
    if snap and snap.rank then
        st.c:SetHidden(false)
        if st.icon then st.icon:SetTexture(snap.rankIcon or "") end
        set_text(st.label, string.format("%s  %d", clean(snap.rankTitle) or "Veterancy", snap.rank))
        local season = clean(snap.seasonName)
        local seasonLine = season and ("\n" .. season) or ""
        if snap.tierTotal and snap.tierTotal > 0 then
            st.tip = string.format("Veterancy rank %d\n%s / %s to the next rank%s",
                snap.rank, F.commas(snap.progressToNext or 0), F.commas(snap.tierTotal), seasonLine)
        else
            st.tip = string.format("Veterancy rank %d%s", snap.rank, seasonLine)
        end
    else
        st.c:SetHidden(true)
    end

    st = panel.stats.stand
    local sv = BGMeter.zenimax.savedvars.get()
    local standing = sv and sv.standing
    st.c:SetHidden(false)
    if standing and (standing.rank or 0) > 0 then
        local top = standing.rank <= 100
        if st.icon then
            st.icon:SetTexture(top and "EsoUI/Art/Inventory/inventory_tabIcon_trophy_up.dds"
                or "EsoUI/Art/Journal/journal_tabIcon_leaderboard_up.dds")
            if top then st.icon:SetColor(0.72, 0.53, 0.98, 1) else st.icon:SetColor(1, 1, 1, 1) end
        end
        set_text(st.label, "rank #" .. F.commas(standing.rank) .. (top and "  ·  top 100" or ""))
        S.color(st.label, K.COLOR.gold)
        st.tip = string.format("Competitive standing\nrating %s%s", F.commas(standing.score or 0),
            top and "\nwithin reward range (top 100)" or "")
    else
        if st.icon then
            st.icon:SetTexture("EsoUI/Art/Journal/journal_tabIcon_leaderboard_up.dds")
            st.icon:SetColor(1, 1, 1, 1)
        end
        set_text(st.label, "unranked")
        S.color(st.label, K.COLOR.text_dim)
        st.tip = "Competitive standing\nplay a ranked battleground to appear"
    end

    st = panel.stats.ap
    st.c:SetHidden(false)
    if st.icon then st.icon:SetTexture(safe(A.get_currency_icon, C.CURT_ALLIANCE_POINTS) or "") end
    set_text(st.label, F.commas(safe(A.get_alliance_points) or 0))
    st.tip = "Alliance Points"

    st = panel.stats.telvar
    if TELVAR then
        st.c:SetHidden(false)
        if st.icon then st.icon:SetTexture(safe(A.get_currency_icon, TELVAR) or "") end
        set_text(st.label, F.commas(safe(A.get_currency, TELVAR, C.CURRENCY_LOCATION_CHARACTER) or 0))
        st.tip = "Tel Var Stones"
    else
        st.c:SetHidden(true)
    end

    st = panel.stats.session
    local sess = BGMeter.Session
    if sess and sess.matches > 0 then
        set_text(st.label, string.format("%dW-%dL tonight", sess.wins, sess.losses))
        local col = K.COLOR.text_dim
        if sess.wins > sess.losses then col = K.COLOR.heal
        elseif sess.losses > sess.wins then col = K.COLOR.accent end
        S.color(st.label, col)
        st.tip = string.format("This play session\n%d battlegrounds\n%s AP  ·  %s XP earned",
            sess.matches, F.commas(sess.ap), F.commas(sess.xp))
    else
        set_text(st.label, "no battles yet")
        S.color(st.label, K.COLOR.text_dim)
        st.tip = "This play session (since login)"
    end
    st.c:SetHidden(false)
end

local function make_row(i)
    local r = {}
    r.container = BGMeter.zenimax.ui.create_control(nil, panel.inset, CT_CONTROL)
    r.container:SetMouseEnabled(true)

    r.base = P.icon(r.container, ROW_BASE)
    r.base:SetAnchorFill(r.container)
    r.base:SetColor(1, 1, 1, 0.9)

    r.highlight = P.icon(r.container, ROW_HIGHLIGHT)
    r.highlight:SetAnchorFill(r.container)
    r.highlight:SetColor(1, 1, 1, 0.55)
    r.highlight:SetHidden(true)

    r.pip = P.rect(r.container, K.COLOR.text_dim)
    r.pip:SetDimensions(3, ROW_H - 12)
    r.pip:SetAnchor(LEFT, r.container, LEFT, 4, 0)

    r.name = P.label(r.container, S.FONT.row, K.COLOR.text)
    r.name:SetAnchor(LEFT, r.container, LEFT, 14, 0)
    r.name:SetHeight(ROW_H)

    r.mode = P.label(r.container, S.FONT.small, K.COLOR.text_dim)
    r.mode:SetAnchor(RIGHT, r.container, RIGHT, -88, 0)
    r.mode:SetDimensions(62, ROW_H)
    r.mode:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    r.ago = P.label(r.container, S.FONT.small, K.COLOR.text_dim)
    r.ago:SetAnchor(RIGHT, r.container, RIGHT, -26, 0)
    r.ago:SetDimensions(56, ROW_H)
    r.ago:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    r.del = mk_button(r.container, TX.close, 14, function()
        M.delete(r.index)
    end, "Delete this match")
    r.del:SetAnchor(RIGHT, r.container, RIGHT, -6, 0)

    r.container:SetHandler("OnMouseEnter", function() r.highlight:SetHidden(false) end)
    r.container:SetHandler("OnMouseExit", function() r.highlight:SetHidden(true) end)
    r.container:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside and r.index then
            Sound.play("open")
            BGMeter.UI.window.show_match(r.index)
            M.refresh()
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

    launcher.icon = P.icon(win, LAUNCHER_ICON)
    launcher.icon:SetAnchorFill(win)
    launcher.icon:SetColor(1, 1, 1, LAUNCHER_IDLE)
    win:SetHandler("OnMouseEnter", function()
        launcher.icon:SetColor(1, 1, 1, 1)
        if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(win, RIGHT, "bgmeter  ·  battle registry") end
    end)
    win:SetHandler("OnMouseExit", function()
        launcher.icon:SetColor(1, 1, 1, LAUNCHER_IDLE)
        if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
    end)

    local mg = sv_menu()
    local pw = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterMenu")
    pw:SetDimensions((mg.w and mg.w > 0) and mg.w or MENU_W, (mg.h and mg.h > 0) and mg.h or MENU_H)
    pw:SetMouseEnabled(true)
    pw:SetMovable(true)
    pw:SetClampedToScreen(true)
    pw:SetHidden(true)
    pw:SetDrawTier(DT_HIGH)
    pw:SetResizeHandleSize(L.resize_h)
    pw:SetDimensionConstraints(360, 280, 560, 780)
    pw:SetHandler("OnMoveStop", function()
        mg = sv_menu()
        mg.x, mg.y = pw:GetLeft(), pw:GetTop()
    end)
    pw:SetHandler("OnResizeStop", function()
        mg = sv_menu()
        mg.w, mg.h = pw:GetWidth(), pw:GetHeight()
        apply_art_cover()
        M.refresh()
    end)
    pw:SetHandler("OnMouseWheel", function(_, delta)
        local count = BGMeter.History.count()
        local maxOff = math.max(0, count - (panel.vis or 1))
        local want = math.max(0, math.min(offset - delta, maxOff))
        if want ~= offset then
            offset = want
            M.refresh()
        end
    end)
    panel = { win = pw }

    local bg = P.rect(pw, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.97 })
    bg:SetAnchorFill(pw)

    panel.art = P.icon(pw, MENU_ART)
    panel.art:SetAnchor(TOPLEFT, pw, TOPLEFT, 2, 2)
    panel.art:SetAnchor(BOTTOMRIGHT, pw, BOTTOMRIGHT, -2, -2)
    panel.art:SetColor(1, 1, 1, MENU_ART_ALPHA)

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

    local function make_stat(rowi, right, withIcon)
        local c = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL)
        local rowH = right and 24 or 30
        local iconS = right and 22 or 30
        c:SetHeight(rowH)
        c:SetMouseEnabled(true)
        local y = HEAD_H + (rowi - 1) * (right and 26 or 32)
        if right then
            c:SetAnchor(TOPRIGHT, pw, TOPRIGHT, -(INSET_PAD + 2), y)
            c:SetWidth(126)
        else
            c:SetAnchor(TOPLEFT, pw, TOPLEFT, INSET_PAD + 2, y)
            c:SetWidth(196)
        end
        local st = { c = c }
        if withIcon then
            st.icon = P.icon(c)
            st.icon:SetDimensions(iconS, iconS)
            st.icon:SetAnchor(LEFT, c, LEFT, 0, 0)
        end
        st.label = P.label(c, right and S.FONT.small or S.FONT.row, K.COLOR.text)
        st.label:SetAnchor(LEFT, c, LEFT, withIcon and (iconS + 6) or 2, 0)
        st.label:SetAnchor(RIGHT, c, RIGHT, 0, 0)
        st.label:SetHeight(rowH)
        c:SetHandler("OnMouseEnter", function()
            if st.tip and ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(c, BOTTOM, st.tip) end
        end)
        c:SetHandler("OnMouseExit", function()
            if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
        end)
        return st
    end

    panel.stats = {
        ava     = make_stat(1, false, true),
        vet     = make_stat(2, false, true),
        stand   = make_stat(3, false, true),
        ap      = make_stat(1, true, true),
        telvar  = make_stat(2, true, true),
        session = make_stat(3, true, false),
    }

    panel.inset = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL)
    panel.inset:SetAnchor(TOPLEFT, pw, TOPLEFT, INSET_PAD, HEAD_H + PANEL_H)
    panel.inset:SetAnchor(BOTTOMRIGHT, pw, BOTTOMRIGHT, -INSET_PAD, -FOOT_H)
    panel.inset:SetMouseEnabled(false)

    panel.insetBg = P.rect(panel.inset, { 0, 0, 0, 0.45 })
    panel.insetBg:SetAnchorFill(panel.inset)
    P.frame(panel.inset):SetAnchorFill(panel.inset)

    panel.empty = P.label(panel.inset, S.FONT.small, K.COLOR.text_dim)
    panel.empty:SetText("no battlegrounds recorded yet")
    panel.empty:SetAnchor(CENTER, panel.inset, CENTER, 0, 0)
    panel.empty:SetHidden(true)

    panel.footer = P.label(pw, S.FONT.small, K.COLOR.text_dim)
    panel.footer:SetAnchor(BOTTOM, pw, BOTTOM, 0, -9)
    panel.footer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    built = true
end

function M.refresh()
    if not built or panel.win:IsHidden() then return end
    local H = BGMeter.History
    local count = H.count()

    refresh_panel()

    local w = panel.win:GetWidth()
    local h = panel.win:GetHeight()
    local insetH = h - HEAD_H - PANEL_H - FOOT_H - 10
    panel.vis = math.max(1, math.floor(insetH / ROW_H))

    local maxOff = math.max(0, count - panel.vis)
    if offset > maxOff then offset = maxOff end
    local vis = math.min(count - offset, panel.vis)

    local roww = w - 2 * INSET_PAD - 10
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
        r.container:SetAnchor(TOPLEFT, panel.inset, TOPLEFT, 5, 5 + (i - 1) * ROW_H)
        r.container:SetDimensions(roww, ROW_H - 2)
        r.container:SetHidden(false)
        r.highlight:SetHidden(true)
        r.name:SetWidth(math.max(80, roww - 176))
        P.set_rect_color(r.pip, result_color(m.result))
        set_text(r.name, m.name or "Battleground")
        S.color(r.name, (BGMeter.UI.window.current() == idx and not BGMeter.UI.window.is_hidden()) and K.COLOR.you or K.COLOR.text)
        set_text(r.mode, mode_tag(m))
        set_text(r.ago, ago_label(m.capturedAt))
    end
    for i = vis + 1, #rows do
        rows[i].container:SetHidden(true)
        rows[i].index = nil
    end

    if count > panel.vis then
        set_text(panel.footer, string.format("%d-%d of %d  ·  scroll for more", offset + 1, offset + vis, count))
    else
        set_text(panel.footer, count > 0 and (count .. (count == 1 and " battleground" or " battlegrounds")) or "")
    end
end

function M.delete(index)
    if not BGMeter.History.delete(index) then return end
    Sound.play("nav")
    W.on_history_changed(index)
    auto_height()
    apply_art_cover()
    M.refresh()
end

function M.show_menu()
    if not built then return end
    local mg = sv_menu()
    panel.win:ClearAnchors()
    if (mg.x or 0) ~= 0 or (mg.y or 0) ~= 0 then
        panel.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, mg.x, mg.y)
    else
        panel.win:SetAnchor(TOPLEFT, launcher.win, BOTTOMRIGHT, 2, 2)
    end
    panel.win:SetHidden(false)
    offset = 0
    auto_height()
    apply_art_cover()
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
    if built and not panel.win:IsHidden() then
        auto_height()
        M.refresh()
    end
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
