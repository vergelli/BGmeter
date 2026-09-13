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
local TAB_W, TAB_H = 22, 64
local HEAD_H = 46
local SEARCH_H = 28
local ROW_H = 26
local FOOT_H = 26
local PAD = 12
local ICON = "EsoUI/Art/Contacts/social_note_up.dds"

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

    r.pip = P.rect(r.container, K.COLOR.face_mixed)
    r.pip:SetDimensions(3, ROW_H - 10)
    r.pip:SetAnchor(LEFT, r.container, LEFT, 3, 0)

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
        if r.face and ZO_Tooltips_ShowTextTooltip then
            ZO_Tooltips_ShowTextTooltip(r.container, LEFT, BGMeter.Faces.describe(r.face))
        end
    end)
    r.container:SetHandler("OnMouseExit", function()
        r.highlight:SetHidden(true)
        if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
    end)
    rows[i] = r
    return r
end

local function visible_rows()
    if not drawer then return 0 end
    local h = drawer.list:GetHeight()
    return math.max(0, math.floor(h / (ROW_H + 2)))
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
            P.set_rect_color(r.pip, c)
            local nm = e.name
            if e.chr and e.chr ~= "" and e.chr ~= e.name then nm = nm .. "  |c" .. hexc(K.COLOR.text_dim) .. e.chr .. "|r" end
            set_text(r.name, nm)
            set_text(r.count, string.format("|c%s×%d|r", hexc(c), e.w + e.a))
        else
            r.face = nil
            r.container:SetHidden(true)
        end
    end
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

function M.is_open()
    return drawer ~= nil and not drawer.root:IsHidden()
end

local function apply_open(open, silent)
    if not drawer then return end
    drawer.root:SetHidden(not open)
    tab.icon:SetColor(1, 1, 1, open and 1 or 0.55)
    sv_menu().faces_open = open and true or false
    if open then
        offset = 0
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
    tab.icon = P.icon(tab.root, ICON)
    tab.icon:SetDimensions(16, 16)
    tab.icon:SetAnchor(CENTER, tab.root, CENTER, 1, 0)
    tab.icon:SetColor(1, 1, 1, 0.55)
    tab.root:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == (MOUSE_BUTTON_INDEX_LEFT or 1) then M.toggle() end
    end)
    tab.root:SetHandler("OnMouseEnter", function()
        tab.icon:SetColor(1, 1, 1, 1)
        if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(tab.root, RIGHT, "Familiar faces") end
    end)
    tab.root:SetHandler("OnMouseExit", function()
        tab.icon:SetColor(1, 1, 1, M.is_open() and 1 or 0.55)
        if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
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
    drawer.frame = P.frame(d)
    drawer.frame:SetAnchorFill(d)
    drawer.strip = P.rect(d, K.COLOR.accent)
    drawer.strip:SetAnchor(TOPLEFT, d, TOPLEFT, 6, 6)
    drawer.strip:SetAnchor(TOPRIGHT, d, TOPRIGHT, -6, 6)
    drawer.strip:SetHeight(3)

    drawer.icon = P.icon(d, ICON)
    drawer.icon:SetDimensions(18, 18)
    drawer.icon:SetAnchor(TOPLEFT, d, TOPLEFT, PAD + 2, 15)
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
    drawer.list:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -PAD, -FOOT_H)
    drawer.list:SetMouseEnabled(false)

    drawer.foot = P.label(d, S.FONT.small, K.COLOR.text_dim)
    drawer.foot:SetAnchor(BOTTOMLEFT, d, BOTTOMLEFT, PAD, -8)
    drawer.foot:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, -PAD, -8)
    drawer.foot:SetHeight(14)
    drawer.foot:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    U.clamp_line(drawer.foot)
end

function M.controls() return drawer, tab, rows end

BGMeter.UI.faces = M
