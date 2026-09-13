BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local K = BGMeter.Constants
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Sound = BGMeter.Sound
local set_text = U.set_text

local M = {}

local DRAWER_W = 236
local TAB_W, TAB_H = 26, 64
local HEAD_H = 46
local SEARCH_H = 28
local ROW_H = 26
local FOOT_H = 26
local PAD = 12
local ICON = "EsoUI/Art/Help/help_tabIcon_emotes_up.dds"
local ICON_DOWN = "EsoUI/Art/Help/help_tabIcon_emotes_down.dds"
local ICON_OVER = "EsoUI/Art/Help/help_tabIcon_emotes_over.dds"
local DRAG_NAME = "BGMeterFacesDrag"
local ART = "esoui/art/loadingscreens/loadscreen_battleground_ularra_01.dds"
local ART_ALPHA = 0.30
local SCROLL_W = 8
local ARROW = 16
local drag = { on = false, y0 = 0, off0 = 0 }

local drawer, tab, rows, offset = nil, nil, {}, 0
local host = nil
local list_cache, cache_key = {}, nil

local function sv_menu()
    local data = BGMeter.zenimax.savedvars.get()
    data.menu = data.menu or {}
    return data.menu
end

local function hexc(c)
    return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function lean_color(e)
    local lean = BGMeter.Faces.lean(e)
    if lean == "with" then return K.COLOR.face_with end
    if lean == "against" then return K.COLOR.face_vs end
    return K.COLOR.face_mixed
end

local function query()
    if not drawer or not drawer.edit then return "" end
    return drawer.edit:GetText() or ""
end

local function fetch()
    local q = query()
    local key = q .. "|" .. tostring(BGMeter.Faces.count())
    if key ~= cache_key then
        list_cache = BGMeter.Faces.list(q, 400)
        cache_key = key
    end
    return list_cache
end

function M.invalidate() cache_key = nil end

local function make_row(i)
    local r = {}
    r.container = BGMeter.zenimax.ui.create_control(nil, drawer.list, CT_CONTROL)
    r.container:SetHeight(ROW_H)
    r.container:SetMouseEnabled(true)
    r.base, r.highlight = U.row_chrome(r.container)

    r.pipW = P.rect(r.container, K.COLOR.face_with)
    r.pipW:SetWidth(3)
    r.pipW:SetAnchor(TOPLEFT, r.container, TOPLEFT, 3, 5)
    r.pipA = P.rect(r.container, K.COLOR.face_vs)
    r.pipA:SetWidth(3)
    r.pipA:SetAnchor(BOTTOMLEFT, r.container, BOTTOMLEFT, 3, -5)

    r.name = P.label(r.container, S.FONT.row, K.COLOR.text)
    r.name:SetAnchor(LEFT, r.container, LEFT, 12, 0)
    r.name:SetAnchor(RIGHT, r.container, RIGHT, -54, 0)
    r.name:SetHeight(ROW_H)
    r.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    U.clamp_line(r.name)

    r.count = P.label(r.container, S.FONT.row, K.COLOR.text)
    r.count:SetAnchor(RIGHT, r.container, RIGHT, -6, 0)
    r.count:SetDimensions(46, ROW_H)
    r.count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    r.container:SetHandler("OnMouseEnter", function()
        r.highlight:SetHidden(false)
        if r.face and U.card_show then
            U.card_show(r.container, LEFT, BGMeter.Faces.describe(r.face))
        end
    end)
    r.container:SetHandler("OnMouseExit", function()
        r.highlight:SetHidden(true)
        if U.card_hide then U.card_hide() end
    end)
    rows[i] = r
    return r
end

local function visible_rows()
    if not drawer then return 0 end
    local h = drawer.list:GetHeight()
    return math.max(0, math.floor(h / (ROW_H + 2)))
end

local last_count, last_vis = 0, 0

local function max_offset()
    return math.max(0, last_count - last_vis)
end

local function layout_scrollbar()
    local sc = drawer.scroll
    local maxOff = max_offset()
    sc.up:SetHidden(offset <= 0)
    sc.down:SetHidden(maxOff - offset <= 0)
    if maxOff <= 0 then sc.track:SetHidden(true) return end
    local th = sc.track:GetHeight()
    if th <= 0 then sc.track:SetHidden(true) return end
    local thumbH = math.floor(th * last_vis / last_count + 0.5)
    if thumbH < 16 then thumbH = 16 end
    if thumbH > th then thumbH = th end
    local y = math.floor((th - thumbH) * offset / maxOff + 0.5)
    sc.thumb:SetHeight(thumbH)
    sc.thumb:ClearAnchors()
    sc.thumb:SetAnchor(TOPLEFT, sc.track, TOPLEFT, 0, y)
    sc.track:SetHidden(false)
end

local function apply_art()
    local art = drawer.art
    local w, h = drawer.root:GetWidth() - 4, drawer.root:GetHeight() - 4
    if w <= 0 or h <= 0 then return end
    local tw, th
    pcall(function() tw, th = art:GetTextureFileDimensions() end)
    if not tw or tw <= 0 or not th or th <= 0 then art:SetTextureCoords(0, 1, 0, 1) return end
    local ca, ta = w / h, tw / th
    if ta > ca then
        local uw = ca / ta
        local host_w, host_h = host:GetWidth() - 4, host:GetHeight() - 4
        local host_uw = (host_w > 0 and host_h > 0) and math.min(1, (host_w / host_h) / ta) or 0
        local u0 = (1 - host_uw) / 2 + host_uw
        if u0 + uw > 1 then u0 = (1 - uw) / 2 end
        art:SetTextureCoords(u0, u0 + uw, 0, 1)
    else
        local vh = ta / ca
        local v0 = (1 - vh) / 2
        art:SetTextureCoords(0, 1, v0, v0 + vh)
    end
end

function M.refresh()
    if not drawer or drawer.root:IsHidden() then return end
    local Faces = BGMeter.Faces
    local list = fetch()
    local vis = visible_rows()
    local max_off = math.max(0, #list - vis)
    if offset > max_off then offset = max_off end
    if offset < 0 then offset = 0 end
    for i = 1, math.max(#rows, vis) do
        local r = rows[i] or make_row(i)
        local e = list[i + offset]
        if i <= vis and e then
            r.face = e
            r.container:SetHidden(false)
            r.container:ClearAnchors()
            r.container:SetAnchor(TOPLEFT, drawer.list, TOPLEFT, 0, (i - 1) * (ROW_H + 2))
            r.container:SetAnchor(TOPRIGHT, drawer.list, TOPRIGHT, 0, (i - 1) * (ROW_H + 2))
            local c = lean_color(e)
            local span = ROW_H - 10
            local wh = math.floor(span * e.w / math.max(1, e.w + e.a) + 0.5)
            r.pipW:SetHeight(wh)
            r.pipW:SetHidden(wh <= 0)
            r.pipA:SetHeight(span - wh)
            r.pipA:SetHidden(span - wh <= 0)
            local nm = e.name
            if e.chr and e.chr ~= "" and e.chr ~= e.name then nm = nm .. "  |c" .. hexc(K.COLOR.text_dim) .. e.chr .. "|r" end
            set_text(r.name, nm)
            set_text(r.count, string.format("|c%s×%d|r", hexc(c), e.w + e.a))
        else
            r.face = nil
            r.container:SetHidden(true)
        end
    end
    last_count, last_vis = #list, vis
    layout_scrollbar()
    local known = Faces.count()
    if #list == 0 then
        set_text(drawer.foot, known == 0 and "no one yet  ·  faces fill in as you play" or "no match")
    elseif #list > vis then
        set_text(drawer.foot, string.format("%d-%d of %d  ·  scroll for more", offset + 1, math.min(#list, offset + vis), #list))
    else
        set_text(drawer.foot, string.format("%d known  ·  green with you, red against", known))
    end
end

function M.scroll(delta)
    offset = offset - delta
    M.refresh()
end

function M.scroll_to(want)
    offset = want
    M.refresh()
end

function M.on_track_click()
    if drag.on then return end
    local track = drawer.scroll.track
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    local th = track:GetHeight()
    if not my or th <= 0 then return end
    local rel = (my - track:GetTop()) / th
    M.scroll_to(math.floor(rel * (max_offset() + 1)))
end

local function drag_update()
    if not drag.on then return end
    local track, thumb = drawer.scroll.track, drawer.scroll.thumb
    local free = track:GetHeight() - thumb:GetHeight()
    local maxOff = max_offset()
    if free <= 0 or maxOff <= 0 then return end
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    if not my then return end
    M.scroll_to(drag.off0 + math.floor((my - drag.y0) * maxOff / free + 0.5))
end

function M.on_thumb_down()
    local _, my = BGMeter.zenimax.api.get_ui_mouse()
    drag.on, drag.y0, drag.off0 = true, my or 0, offset
    local ac = K.COLOR.accent
    P.set_rect_color(drawer.scroll.thumbTex, { ac[1], ac[2], ac[3], 0.95 })
    BGMeter.zenimax.events.register_update(DRAG_NAME, 16, drag_update)
end

function M.on_thumb_up()
    if not drag.on then return end
    drag.on = false
    BGMeter.zenimax.events.unregister_update(DRAG_NAME)
    local ac = K.COLOR.accent
    P.set_rect_color(drawer.scroll.thumbTex, { ac[1], ac[2], ac[3], 0.55 })
end

function M.drag_active() return drag.on end

function M.on_host_resized()
    if drawer then apply_art() end
end

function M.is_open()
    return drawer ~= nil and not drawer.root:IsHidden()
end

local function apply_open(open, silent)
    if not drawer then return end
    drawer.root:SetHidden(not open)
    tab.icon:SetAlpha(open and 1 or 0.7)
    sv_menu().faces_open = open and true or false
    if open then
        offset = 0
        apply_art()
        M.invalidate()
        M.refresh()
    elseif drawer.edit and drawer.edit.LoseFocus then
        drawer.edit:LoseFocus()
    end
    if not silent then Sound.play(open and "menu" or "close") end
end

function M.toggle()
    apply_open(not M.is_open())
end

function M.set_query(text)
    if not drawer then return end
    drawer.edit:SetText(text or "")
    offset = 0
    M.invalidate()
    M.refresh()
end

function M.query() return query() end

function M.on_menu_shown()
    if not drawer then return end
    apply_open(sv_menu().faces_open == true, true)
end

function M.init(pw)
    if drawer then return end
    host = pw

    tab = { root = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL) }
    tab.root:SetDimensions(TAB_W, TAB_H)
    tab.root:SetAnchor(TOPLEFT, pw, TOPRIGHT, -1, HEAD_H + 6)
    tab.root:SetMouseEnabled(true)
    tab.bg = P.rect(tab.root, { K.COLOR.panel[1], K.COLOR.panel[2], K.COLOR.panel[3], 0.97 })
    tab.bg:SetAnchorFill(tab.root)
    tab.frame = P.frame(tab.root)
    tab.frame:SetAnchorFill(tab.root)
    tab.strip = P.rect(tab.root, K.COLOR.accent)
    tab.strip:SetAnchor(TOPLEFT, tab.root, TOPLEFT, 3, 3)
    tab.strip:SetAnchor(BOTTOMLEFT, tab.root, BOTTOMLEFT, 3, -3)
    tab.strip:SetWidth(2)
    tab.icon = P.button(tab.root, ICON, ICON_DOWN, ICON_OVER)
    tab.icon:SetDimensions(22, 22)
    tab.icon:SetAnchor(CENTER, tab.root, CENTER, 1, 0)
    tab.icon:SetAlpha(0.7)
    tab.icon:SetHandler("OnClicked", function() M.toggle() end)
    tab.icon:SetHandler("OnMouseEnter", function()
        tab.icon:SetAlpha(1)
        if U.card_show then U.card_show(tab.root, RIGHT, "Familiar faces") end
    end)
    tab.icon:SetHandler("OnMouseExit", function()
        tab.icon:SetAlpha(M.is_open() and 1 or 0.7)
        if U.card_hide then U.card_hide() end
    end)
    tab.root:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == (MOUSE_BUTTON_INDEX_LEFT or 1) then M.toggle() end
    end)

    drawer = { root = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL) }
    local d = drawer.root
    d:SetWidth(DRAWER_W)
    d:SetAnchor(TOPLEFT, pw, TOPRIGHT, TAB_W - 2, 0)
    d:SetAnchor(BOTTOMLEFT, pw, BOTTOMRIGHT, TAB_W - 2, 0)
    d:SetMouseEnabled(true)
    d:SetHidden(true)
    d:SetHandler("OnMouseWheel", function(_, delta) M.scroll(delta) end)

    drawer.bg = P.rect(d, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.97 })
    drawer.bg:SetAnchorFill(d)
    drawer.art = P.icon(d, ART)
    drawer.art:SetAnchor(TOPLEFT, d, TOPLEFT, 2, 2)
    drawer.art:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -2, -2)
    drawer.art:SetColor(1, 1, 1, ART_ALPHA)
    local VP_TOP = (VERTEX_POINTS_TOPLEFT or 1) + (VERTEX_POINTS_TOPRIGHT or 2)
    local VP_BOTTOM = (VERTEX_POINTS_BOTTOMLEFT or 4) + (VERTEX_POINTS_BOTTOMRIGHT or 8)
    local bgc = K.COLOR.bg
    local vtop = P.rect(d, { bgc[1], bgc[2], bgc[3], 1 })
    vtop:SetAnchor(TOPLEFT, d, TOPLEFT, 2, 2)
    vtop:SetAnchor(TOPRIGHT, d, TOPRIGHT, -2, 2)
    vtop:SetHeight(90)
    vtop:SetVertexColors(VP_TOP, bgc[1], bgc[2], bgc[3], 0.85)
    vtop:SetVertexColors(VP_BOTTOM, bgc[1], bgc[2], bgc[3], 0)
    local vbot = P.rect(d, { bgc[1], bgc[2], bgc[3], 1 })
    vbot:SetAnchor(BOTTOMLEFT, d, BOTTOMLEFT, 2, -2)
    vbot:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -2, -2)
    vbot:SetHeight(120)
    vbot:SetVertexColors(VP_TOP, bgc[1], bgc[2], bgc[3], 0)
    vbot:SetVertexColors(VP_BOTTOM, bgc[1], bgc[2], bgc[3], 0.85)
    drawer.vignette = { vtop, vbot }
    drawer.frame = P.frame(d)
    drawer.frame:SetAnchorFill(d)
    drawer.strip = P.rect(d, K.COLOR.accent)
    drawer.strip:SetAnchor(TOPLEFT, d, TOPLEFT, 6, 6)
    drawer.strip:SetAnchor(TOPRIGHT, d, TOPRIGHT, -6, 6)
    drawer.strip:SetHeight(3)

    drawer.icon = P.icon(d, ICON)
    drawer.icon:SetDimensions(28, 28)
    drawer.icon:SetAnchor(TOPLEFT, d, TOPLEFT, PAD, 10)
    drawer.title = P.label(d, S.FONT.title, K.COLOR.text)
    drawer.title:SetAnchor(LEFT, drawer.icon, RIGHT, 8, 0)
    set_text(drawer.title, "Familiar faces")

    drawer.search = BGMeter.zenimax.ui.create_from_virtual(nil, d, "ZO_EditBackdrop")
    drawer.search:SetAnchor(TOPLEFT, d, TOPLEFT, PAD, HEAD_H)
    drawer.search:SetAnchor(TOPRIGHT, d, TOPRIGHT, -PAD, HEAD_H)
    drawer.search:SetHeight(SEARCH_H)
    drawer.edit = BGMeter.zenimax.ui.create_from_virtual(nil, drawer.search, "ZO_DefaultEditForBackdrop")
    if drawer.edit.SetDefaultText then drawer.edit:SetDefaultText("search a name") end
    if drawer.edit.SetMaxInputChars then drawer.edit:SetMaxInputChars(40) end
    drawer.edit:SetHandler("OnTextChanged", function()
        offset = 0
        M.invalidate()
        M.refresh()
    end)
    drawer.edit:SetHandler("OnEnter", function() drawer.edit:LoseFocus() end)
    drawer.edit:SetHandler("OnEscape", function() drawer.edit:LoseFocus() end)

    drawer.list = BGMeter.zenimax.ui.create_control(nil, d, CT_CONTROL)
    drawer.list:SetAnchor(TOPLEFT, d, TOPLEFT, PAD, HEAD_H + SEARCH_H + 8)
    drawer.list:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -(PAD + SCROLL_W + 6), -FOOT_H)
    drawer.list:SetMouseEnabled(false)
    d:SetHandler("OnMouseUp", function() M.on_thumb_up() end)

    drawer.scroll = {}
    local ac = K.COLOR.accent
    local up = P.button(d, "EsoUI/Art/Buttons/scrollbox_upArrow_up.dds", "EsoUI/Art/Buttons/scrollbox_upArrow_down.dds", "EsoUI/Art/Buttons/scrollbox_upArrow_over.dds")
    up:SetDimensions(ARROW, ARROW)
    up:SetAnchor(TOPRIGHT, d, TOPRIGHT, -(PAD - 4), HEAD_H + SEARCH_H + 6)
    up:SetHandler("OnClicked", function() M.scroll(1) end)
    up:SetHidden(true)
    drawer.scroll.up = up
    local down = P.button(d, "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds", "EsoUI/Art/Buttons/scrollbox_downArrow_down.dds", "EsoUI/Art/Buttons/scrollbox_downArrow_over.dds")
    down:SetDimensions(ARROW, ARROW)
    down:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -(PAD - 4), -(FOOT_H - 2))
    down:SetHandler("OnClicked", function() M.scroll(-1) end)
    down:SetHidden(true)
    drawer.scroll.down = down
    local track = BGMeter.zenimax.ui.create_control(nil, d, CT_CONTROL)
    track:SetAnchor(TOPRIGHT, d, TOPRIGHT, -PAD, HEAD_H + SEARCH_H + 8 + ARROW + 4)
    track:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -PAD, -(FOOT_H + ARROW + 2))
    track:SetWidth(SCROLL_W)
    track:SetMouseEnabled(true)
    track:SetHidden(true)
    track:SetHandler("OnMouseUp", function(_, _, upInside)
        if drag.on then M.on_thumb_up() return end
        if upInside then M.on_track_click() end
    end)
    drawer.scroll.track = track
    drawer.scroll.trackBg = P.rect(track, { ac[1], ac[2], ac[3], 0.12 })
    drawer.scroll.trackBg:SetAnchorFill(track)
    local thumb = BGMeter.zenimax.ui.create_control(nil, track, CT_CONTROL)
    thumb:SetAnchor(TOPLEFT, track, TOPLEFT, 0, 0)
    thumb:SetWidth(SCROLL_W)
    thumb:SetMouseEnabled(true)
    local thumbTex = P.rect(thumb, { ac[1], ac[2], ac[3], 0.55 })
    thumbTex:SetAnchorFill(thumb)
    thumb:SetHandler("OnMouseDown", function() M.on_thumb_down() end)
    thumb:SetHandler("OnMouseUp", function() M.on_thumb_up() end)
    thumb:SetHandler("OnMouseEnter", function() if not drag.on then P.set_rect_color(thumbTex, { ac[1], ac[2], ac[3], 0.85 }) end end)
    thumb:SetHandler("OnMouseExit", function() if not drag.on then P.set_rect_color(thumbTex, { ac[1], ac[2], ac[3], 0.55 }) end end)
    drawer.scroll.thumb = thumb
    drawer.scroll.thumbTex = thumbTex

    drawer.foot = P.label(d, S.FONT.small, K.COLOR.text_dim)
    drawer.foot:SetAnchor(BOTTOMLEFT, d, BOTTOMLEFT, PAD, -8)
    drawer.foot:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -PAD, -8)
    drawer.foot:SetHeight(14)
    drawer.foot:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    U.clamp_line(drawer.foot)
end

function M.controls() return drawer, tab, rows end

BGMeter.UI.faces = M
