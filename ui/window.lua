-- bgmeter :: ui/window.lua
-- The result window. Two faces of one battle:
--   left  -- THE BATTLE: every player's combat as a meter table (sortable,
--            selectable rows, class icons, MVP crown, column-leader highlights)
--   right -- THE HAUL:    your progression earned this match (veterancy season
--            track, AP/XP/CP with the real in-game currency icons, medals,
--            competitive standing, personal-best markers, AP efficiency)
-- Bordered + resizable (the battle table reflows from the window width), with a
-- VICTORY/DEFEAT banner, textured chrome buttons, history nav, settings overlay,
-- sounds, tooltips and animated bars/counters. Built with CreateTopLevelWindow.

BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local W = {}
local built = false
local current_index = 1
local selected_row = nil
local settings_open = false
local C, K, L, F, P, S, Bar, Icons, Awards, Prefs, Anim, Sound

-- Numeric columns, anchored from the RIGHT edge of each row so the table reflows
-- when the window is resized. `right` = distance of the column's right edge from
-- the row's right edge; `w` = column width.
local COLS = {
    { key = "damage",  right = 230, w = 56, label = "DMG"  },
    { key = "healing", right = 170, w = 50, label = "HEAL" },
    { key = "kills",   right = 122, w = 22, label = "K"    },
    { key = "deaths",  right = 94,  w = 22, label = "D"    },
    { key = "assists", right = 66,  w = 22, label = "A"    },
    { key = "score",   right = 10,  w = 50, label = "PTS"  },
}
local INDEX_X, ICON_X, NAME_X = 6, 24, 50
local NAME_RIGHT = 296   -- name's right edge offset (clears the damage column)
local BAR_X, BAR_RIGHT = 50, 6

-- inline-icon textures (real art instead of unicode glyphs that box out)
local ICON_STAR  = "EsoUI/Art/Collections/favorite_starOnly.dds"          -- MVP marker
local ICON_SORTUP = "EsoUI/Art/Miscellaneous/list_sortUp.dds"             -- sort ascending
local ICON_SORTDN = "EsoUI/Art/Miscellaneous/list_sortDown.dds"           -- sort descending

-- chrome button textures (copied from the sibling Verditer's proven set)
local TX = {
    close = { n = "EsoUI/Art/Buttons/decline_up.dds",   p = "EsoUI/Art/Buttons/decline_down.dds",   o = "EsoUI/Art/Buttons/decline_over.dds" },
    gear  = { n = "EsoUI/Art/MenuBar/menuBar_mainMenu_over.dds", p = "EsoUI/Art/MenuBar/menuBar_mainMenu_down.dds", o = "EsoUI/Art/MenuBar/menuBar_mainMenu_over.dds" },
    prev  = { n = "EsoUI/Art/Buttons/large_leftArrow_up.dds",  p = "EsoUI/Art/Buttons/large_leftArrow_down.dds",  o = "EsoUI/Art/Buttons/large_leftArrow_over.dds" },
    nextb = { n = "EsoUI/Art/Buttons/large_rightArrow_up.dds", p = "EsoUI/Art/Buttons/large_rightArrow_down.dds", o = "EsoUI/Art/Buttons/large_rightArrow_over.dds" },
}

-- ── helpers ─────────────────────────────────────────────────────────────────

local function set_text(label, text) if label then label:SetText(text or "") end end

local function make_clickable(control, fn)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then fn() end end)
end

W.tips = {}
function W.tip_dynamic(control)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function()
        local t = W.tips[control]
        if t and t ~= "" and ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(control, BOTTOM, t) end
    end)
    control:SetHandler("OnMouseExit", function()
        if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
    end)
end
function W.tip_static(control, text) W.tips[control] = text; W.tip_dynamic(control) end

local function mk_button(parent, tx, size, onclick, tipText)
    local b = P.button(parent, tx.n, tx.p, tx.o)
    b:SetDimensions(size, size)
    b:SetHandler("OnClicked", function() onclick() end)
    if tipText then
        b:SetHandler("OnMouseEnter", function() if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(b, BOTTOM, tipText) end end)
        b:SetHandler("OnMouseExit", function() if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end end)
    end
    return b
end

local function anim_on(want) return want and Prefs.get("animate") end

local function set_count(label, value, prefix, animate)
    value = value or 0; prefix = prefix or ""
    if anim_on(animate) and value ~= 0 then
        Anim.value(0, value, 520, function(v) set_text(label, prefix .. F.commas(math.floor(v + 0.5))) end)
    else
        set_text(label, prefix .. F.commas(value))
    end
end

local function set_bar(bar, pct, color, width, animate)
    if anim_on(animate) then Anim.value(0, pct, 450, function(v) Bar.set(bar, v, color, width) end)
    else Bar.set(bar, pct, color, width) end
end

-- A short celebratory "pop": the control swells then settles. Used on personal
-- bests so a record visibly jumps when the window opens.
local function pop(control)
    if not control or not Prefs.get("animate") then return end
    Anim.start(460, function(t)
        control:SetScale(1 + math.sin(t * math.pi) * 0.22)
    end, function() control:SetScale(1) end)
end

local function team_name(team)
    if team == C.BATTLEGROUND_TEAM_FIRE_DRAKES then return "Fire Drakes" end
    if team == C.BATTLEGROUND_TEAM_PIT_DAEMONS then return "Pit Daemons" end
    if team == C.BATTLEGROUND_TEAM_STORM_LORDS then return "Storm Lords" end
    return ""
end

local function hide_all(list, hidden) for _, c in ipairs(list) do c:SetHidden(hidden) end end

local function list_width() return W.cur_w - 2 * L.margin - L.haul_w - L.gap end

-- ── build: header ───────────────────────────────────────────────────────────

local function build_header(win)
    local h = {}
    h.emblem = P.rect(win, K.COLOR.accent)
    h.emblem:SetDimensions(16, 16)
    h.emblem:SetAnchor(TOPLEFT, win, TOPLEFT, L.margin + 2, 16)

    h.title = P.label(win, S.FONT.title, K.COLOR.text)
    h.title:SetText("bgmeter")
    h.title:SetAnchor(LEFT, h.emblem, RIGHT, 8, 0)

    h.subtitle = P.label(win, S.FONT.small, K.COLOR.text_dim)
    h.subtitle:SetAnchor(TOPLEFT, h.emblem, BOTTOMLEFT, 0, 8)

    -- soft additive glow behind the result banner (created first = drawn under),
    -- tinted by the result colour for a sense of "moment"
    h.bannerGlow = P.icon(win, "EsoUI/Art/Crafting/crafting_tooltip_glow_center.dds")
    h.bannerGlow:SetAnchor(TOP, win, TOP, 0, 6)
    h.bannerGlow:SetDimensions(440, 76)
    if h.bannerGlow.SetBlendMode then h.bannerGlow:SetBlendMode(TEX_BLEND_MODE_ADD) end
    h.bannerGlow:SetHidden(true)

    h.banner = P.label(win, S.FONT.banner, K.COLOR.text)
    h.banner:SetAnchor(TOP, win, TOP, 0, 14)
    h.banner:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- top-right cluster, anchored by absolute offset-from-right so it never drifts
    h.close = mk_button(win, TX.close, 22, function() W.hide() end, "Close")
    h.close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -L.margin, 14)

    h.gear = mk_button(win, TX.gear, 28, function() W.toggle_settings() end, "Settings")
    h.gear:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 30), 11)

    h.next = mk_button(win, TX.nextb, 26, function() W.step(1) end, "Newer match")
    h.next:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 68), 13)

    h.counter = P.label(win, S.FONT.small, K.COLOR.text_dim)
    h.counter:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 100), 17)
    h.counter:SetDimensions(48, 18)
    h.counter:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    h.prev = mk_button(win, TX.prev, 26, function() W.step(-1) end, "Older match")
    h.prev:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 152), 13)

    return h
end

-- ── build: battle table ─────────────────────────────────────────────────────

local function build_battle(win)
    local b = {}
    b.container = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    b.container:SetAnchor(TOPLEFT, win, TOPLEFT, L.margin, L.header_h)
    b.container:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(L.haul_w + L.gap + L.margin), -L.footer_h)

    -- header row, columns anchored from the right (so they reflow on resize)
    b.headers = {}
    local nameH = P.label(b.container, S.FONT.small, K.COLOR.text_dim)
    nameH:SetText("PLAYER")
    nameH:SetAnchor(TOPLEFT, b.container, TOPLEFT, NAME_X, 0)
    make_clickable(nameH, function() W.sort_by("name") end)
    b.headers.name = nameH

    for _, col in ipairs(COLS) do
        local lbl = P.label(b.container, S.FONT.small, K.COLOR.text_dim)
        lbl:SetText(col.label)
        -- single TOPRIGHT anchor (RIGHT+TOP together conflict and mis-stretch)
        lbl:SetAnchor(TOPRIGHT, b.container, TOPRIGHT, -col.right, 0)
        lbl:SetDimensions(col.w, 16)
        lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        make_clickable(lbl, function() W.sort_by(col.key) end)
        b.headers[col.key] = lbl
    end

    -- header underline
    b.rule = P.rect(b.container, { 1, 1, 1, 0.10 })
    b.rule:SetAnchor(TOPLEFT, b.container, TOPLEFT, 0, 18)
    b.rule:SetAnchor(TOPRIGHT, b.container, TOPRIGHT, 0, 18)
    b.rule:SetHeight(1)

    b.row_pool = BGMeter.Plot.pool.new(function() return W._make_row(b.container) end,
        function(row) row.container:SetHidden(true) end)
    return b
end

function W._make_row(parent)
    local row = { cells = {} }
    row.container = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL)
    row.container:SetHeight(L.row_h)
    row.container:SetMouseEnabled(true)

    row.highlight = P.rect(row.container, { 1, 1, 1, 0 })
    row.highlight:SetAnchorFill(row.container)

    -- a slim team-coloured strip down the left edge, so you can scan teams at a
    -- glance even though the table is sorted by performance
    row.teamStrip = P.rect(row.container, { 0, 0, 0, 0 })
    row.teamStrip:SetDimensions(3, L.row_h - 8)
    row.teamStrip:SetAnchor(LEFT, row.container, LEFT, 1, 0)

    row.bar = Bar.create(row.container)
    row.bar.container:SetAnchor(TOPLEFT, row.container, TOPLEFT, BAR_X, 3)
    row.bar.container:SetAnchor(BOTTOMRIGHT, row.container, BOTTOMRIGHT, -BAR_RIGHT, -3)

    row.index = P.label(row.container, S.FONT.small, K.COLOR.text_dim)
    row.index:SetAnchor(LEFT, row.container, LEFT, INDEX_X, 0)
    row.index:SetDimensions(16, L.row_h)

    row.classIcon = P.icon(row.container)
    row.classIcon:SetDimensions(20, 20)
    row.classIcon:SetAnchor(LEFT, row.container, LEFT, ICON_X, 0)

    row.name = P.label(row.container, S.FONT.row, K.COLOR.text)
    row.name:SetAnchor(LEFT, row.container, LEFT, NAME_X, 0)
    row.name:SetAnchor(RIGHT, row.container, RIGHT, -NAME_RIGHT, 0)
    row.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    for _, col in ipairs(COLS) do
        local lbl = P.label(row.container, S.FONT.row, K.COLOR.text)
        lbl:SetAnchor(RIGHT, row.container, RIGHT, -col.right, 0)
        lbl:SetDimensions(col.w, L.row_h)
        lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.cells[col.key] = lbl
    end

    row.container:SetHandler("OnMouseEnter", function() P.set_rect_color(row.highlight, { 1, 1, 1, 0.16 }) end)
    row.container:SetHandler("OnMouseExit", function() P.set_rect_color(row.highlight, row.baseHL or { 0, 0, 0, 0 }) end)
    return row
end

-- ── build: haul panel ───────────────────────────────────────────────────────

local MEDAL_PERROW, MEDAL_STEP, MEDAL_CAP = 7, 24, 14

local function build_haul(win)
    local p = {}
    local PAD = 16
    local INNER = L.haul_w - 2 * PAD

    p.container = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    p.container:SetAnchor(TOPRIGHT, win, TOPRIGHT, -L.margin, L.header_h)
    p.container:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -L.margin, -L.footer_h)
    p.container:SetWidth(L.haul_w)

    P.backdrop(p.container):SetAnchorFill(p.container)
    P.frame(p.container):SetAnchorFill(p.container)

    p.heading = P.label(p.container, S.FONT.header, K.COLOR.gold)
    p.heading:SetText("YOUR HAUL")
    p.heading:SetAnchor(TOP, p.container, TOP, 0, 14)

    -- ── veterancy: medallion on the left, rank + tier each on its own row ──
    p.vetIcon = P.icon(p.container)
    p.vetIcon:SetDimensions(52, 52)
    p.vetIcon:SetAnchor(TOPLEFT, p.container, TOPLEFT, PAD, 44)

    p.vetTitle = P.label(p.container, S.FONT.row, K.COLOR.veterancy)
    p.vetTitle:SetAnchor(TOPLEFT, p.vetIcon, TOPRIGHT, 12, 6)
    p.vetTitle:SetDimensions(INNER - 64, 22)
    p.vetTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    p.vetTier = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    p.vetTier:SetAnchor(TOPLEFT, p.vetTitle, BOTTOMLEFT, 0, 8)
    p.vetTier:SetDimensions(INNER - 64, 18)

    p.track = Bar.create(p.container)
    p.track.container:SetAnchor(TOPLEFT, p.vetIcon, BOTTOMLEFT, 0, 14)
    p.track.container:SetDimensions(INNER, 12)

    p.vetDelta = P.label(p.container, S.FONT.small, K.COLOR.veterancy)
    p.vetDelta:SetAnchor(TOPLEFT, p.track.container, BOTTOMLEFT, 0, 8)
    p.vetDelta:SetDimensions(INNER, 16)

    p.season = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    p.season:SetAnchor(TOPLEFT, p.vetDelta, BOTTOMLEFT, 0, 4)
    p.season:SetDimensions(INNER, 16)

    p.div1 = P.rect(p.container, { 1, 1, 1, 0.10 })
    p.div1:SetAnchor(TOPLEFT, p.season, BOTTOMLEFT, 0, 12)
    p.div1:SetDimensions(INNER, 1)

    -- ── receipt: AP / XP / CP, each a clear row with its real icon ──
    -- [icon] name (fixed-width, left) ......... value (right). The value box
    -- starts AFTER the name box, so the two never overlap.
    local VAL_W = 74
    local NAME_W = INNER - 22 - 8 - VAL_W - 4   -- icon + gap + name + gap + value = INNER
    local function receipt_line(anchorTo, dy, iconTex)
        local icon = P.icon(p.container, iconTex)
        icon:SetDimensions(22, 22)
        icon:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, 0, dy)
        local name = P.label(p.container, S.FONT.row, K.COLOR.text_dim)
        name:SetAnchor(LEFT, icon, RIGHT, 8, 0)
        name:SetDimensions(NAME_W, 22)
        name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local val = P.label(p.container, S.FONT.row, K.COLOR.gold)
        -- single LEFT anchor + fixed width (a second RIGHT->container anchor
        -- pulled every value to the panel's vertical centre, overlapping them)
        val:SetAnchor(LEFT, name, RIGHT, 4, 0)
        val:SetDimensions(VAL_W, 22)
        val:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        val:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return { icon = icon, name = name, val = val }
    end
    p.ap = receipt_line(p.div1, 12, Icons.ap()); p.ap.name:SetText("Alliance Pts")
    p.xp = receipt_line(p.ap.icon, 10, Icons.XP); p.xp.name:SetText("Experience")
    p.cp = receipt_line(p.xp.icon, 10, Icons.CP); p.cp.name:SetText("Champion Pts")

    -- ── medals: label on its own row, icons wrap into a grid below it ──
    p.medalLabel = P.label(p.container, S.FONT.row, K.COLOR.text_dim)
    p.medalLabel:SetText("Medals")
    p.medalLabel:SetAnchor(TOPLEFT, p.cp.icon, BOTTOMLEFT, 0, 12)
    p.medalLabel:SetDimensions(INNER, 18)
    p.medalIcons = {}
    for i = 1, MEDAL_CAP do
        local col = (i - 1) % MEDAL_PERROW
        local rowN = math.floor((i - 1) / MEDAL_PERROW)
        local mi = P.icon(p.container)
        mi:SetDimensions(22, 22)
        mi:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, col * MEDAL_STEP, 6 + rowN * MEDAL_STEP)
        mi:SetHidden(true)
        p.medalIcons[i] = mi
    end
    p.medalMore = P.label(p.container, S.FONT.small, K.COLOR.medal)
    p.medalMore:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, 0, 6 + 2 * MEDAL_STEP)

    -- efficiency, anchored below a reserved two-row medal grid
    p.eff = P.label(p.container, S.FONT.small, K.COLOR.accent)
    p.eff:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, 0, 8 + 2 * MEDAL_STEP)
    p.eff:SetDimensions(INNER, 16)
    p.eff:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    p.sep = P.rect(p.container, { 1, 1, 1, 0.10 })
    p.sep:SetAnchor(TOPLEFT, p.eff, BOTTOMLEFT, 0, 14)
    p.sep:SetDimensions(INNER, 1)

    p.standHeading = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    p.standHeading:SetText("COMPETITIVE STANDING")
    p.standHeading:SetAnchor(TOPLEFT, p.sep, BOTTOMLEFT, 0, 12)
    p.standHeading:SetDimensions(INNER, 16)
    p.standHeading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    p.standRank = P.label(p.container, S.FONT.big, K.COLOR.text)
    p.standRank:SetAnchor(TOP, p.standHeading, BOTTOM, 0, 6)
    p.standRank:SetDimensions(INNER, 30)
    p.standRank:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    p.standSub = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    p.standSub:SetAnchor(TOP, p.standRank, BOTTOM, 0, 4)
    p.standSub:SetDimensions(INNER, 18)
    p.standSub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    W.tip_static(p.ap.icon, "Alliance Points earned this match")
    W.tip_static(p.xp.icon, "Experience earned this match")
    W.tip_static(p.cp.icon, "Champion Points earned this match")
    W.tip_dynamic(p.vetIcon)
    W.tip_dynamic(p.standRank)
    for i = 1, #p.medalIcons do W.tip_dynamic(p.medalIcons[i]) end
    return p
end

-- ── build: settings overlay ──────────────────────────────────────────────────

local TOGGLES = {
    { key = "auto_open",      label = "Auto-open after a match" },
    { key = "sounds",         label = "Sound cues" },
    { key = "animate",        label = "Animations" },
    { key = "show_haul",      label = "Show the haul panel" },
    { key = "show_veterancy", label = "Show veterancy" },
    { key = "show_standing",  label = "Show competitive standing" },
    { key = "show_awards",    label = "Show MVP / column leaders" },
    { key = "show_vanguard",  label = "Veterancy/AP bar (HUD)" },
    { key = "vanguard_dock",  label = "Bar: dock to the XP bar" },
    { key = "vanguard_fade",  label = "Bar: auto-fade when idle" },
}

-- A separate, movable settings window (the Verditer pattern) -- NOT an overlay
-- on top of the main window. Clear rows: a label on the left, an ON/OFF button
-- on the right; action buttons across the bottom.
local function text_button(parent, label)
    local b = BGMeter.zenimax.ui.create_from_virtual(nil, parent, "ZO_DefaultButton")
    b:SetText(label)
    return b
end

local function build_settings()
    local s = {}
    local win = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterSettingsWindow")
    win:SetDimensions(324, 452)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    s.window = win

    local bg = P.rect(win, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.98 })
    bg:SetAnchorFill(win)
    P.frame(win):SetAnchorFill(win)

    local strip = P.rect(win, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    local emblem = P.rect(win, K.COLOR.accent)
    emblem:SetDimensions(14, 14)
    emblem:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 16)
    local title = P.label(win, S.FONT.title, K.COLOR.text)
    title:SetText("bgmeter  ·  Settings")
    title:SetAnchor(LEFT, emblem, RIGHT, 8, 0)

    s.close = mk_button(win, TX.close, 20, function() W.toggle_settings() end, "Close")
    s.close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -14, 15)

    s.rows = {}
    local y = 52
    for _, t in ipairs(TOGGLES) do
        local name = P.label(win, S.FONT.row, K.COLOR.text)
        name:SetText(t.label)
        name:SetAnchor(TOPLEFT, win, TOPLEFT, 22, y)
        name:SetDimensions(214, 26)
        name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local btn = text_button(win, "")
        btn:SetDimensions(60, 26)
        btn:SetAnchor(TOPRIGHT, win, TOPRIGHT, -20, y - 1)
        local key = t.key
        local function paint() btn:SetText(Prefs.get(key) and "ON" or "OFF") end
        btn:SetHandler("OnClicked", function()
            local on = Prefs.toggle(key)
            -- The vanguard HUD is a separate window, so toggling any vanguard_*
            -- pref must re-apply to it (the other toggles only affect W.render).
            if BGMeter.UI.vanguard then
                if key == "show_vanguard" then
                    if on then BGMeter.UI.vanguard.show() else BGMeter.UI.vanguard.hide() end
                elseif key == "vanguard_dock" or key == "vanguard_fade" then
                    BGMeter.UI.vanguard.sync()
                end
            end
            paint(); Sound.play("nav"); W.render(false)
        end)
        s.rows[key] = paint
        y = y + 30
    end

    local clear = text_button(win, "Clear match history")
    clear:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 18, -52)
    clear:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -18, -52)
    clear:SetHeight(28)
    clear:SetHandler("OnClicked", function() BGMeter.History.clear(); current_index = 1; W.toggle_settings(); W.render(false) end)

    local reset = text_button(win, "Reset window size & position")
    reset:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 18, -16)
    reset:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -18, -16)
    reset:SetHeight(28)
    reset:SetHandler("OnClicked", function()
        local sv = BGMeter.zenimax.savedvars.get()
        if sv then sv.window.x, sv.window.y, sv.window.w, sv.window.h = 0, 0, 0, 0 end
        W.cur_w, W.cur_h = L.window_w, L.window_h
        W.win:SetDimensions(W.cur_w, W.cur_h)
        W.win:ClearAnchors(); W.win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        W.render(false)
    end)

    s.repaint = function() for _, paint in pairs(s.rows) do paint() end end
    return s
end

-- ── build ─────────────────────────────────────────────────────────────────

local function build()
    if built then return end
    C, K, L, F = BGMeter.zenimax.constants, BGMeter.Constants, BGMeter.Constants.LAYOUT, BGMeter.Format
    P, S, Bar = BGMeter.Plot.primitives, BGMeter.Plot.style, BGMeter.Plot.bar
    Icons, Awards, Prefs = BGMeter.Icons, BGMeter.Awards, BGMeter.Prefs
    Anim, Sound = BGMeter.Anim, BGMeter.Sound

    local sv = BGMeter.zenimax.savedvars.get()
    W.cur_w = (sv and sv.window and sv.window.w and sv.window.w > 0) and sv.window.w or L.window_w
    W.cur_h = (sv and sv.window and sv.window.h and sv.window.h > 0) and sv.window.h or L.window_h

    local win = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterWindow")
    win:SetDimensions(W.cur_w, W.cur_h)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetResizeHandleSize(L.resize_h)
    win:SetDimensionConstraints(L.min_w, L.min_h, L.max_w, L.max_h)
    win:SetHandler("OnMoveStop", function() W.on_move_stop() end)
    win:SetHandler("OnResizeStop", function() W.on_resize_stop() end)

    W.bg = P.rect(win, K.COLOR.bg)
    W.bg:SetAnchorFill(win)
    P.frame(win):SetAnchorFill(win)

    local strip = P.rect(win, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    W.detail = P.label(win, S.FONT.small, K.COLOR.text_dim)
    W.detail:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, L.margin, -10)
    W.detail:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -L.margin, -10)
    W.detail:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    W.win      = win
    W.header   = build_header(win)
    W.battle   = build_battle(win)
    W.haul     = build_haul(win)
    W.settings = build_settings()

    -- empty-state emblem (crossed swords), shown only when there's no match yet
    W.emptyIcon = P.icon(win, "EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds")
    W.emptyIcon:SetDimensions(72, 72)
    W.emptyIcon:SetAnchor(CENTER, win, CENTER, -(L.haul_w + L.gap) / 2, -30)
    W.emptyIcon:SetColor(1, 1, 1, 0.18)
    W.emptyIcon:SetHidden(true)

    if sv and sv.window then
        if not (sv.window.x == 0 and sv.window.y == 0) then
            win:ClearAnchors()
            win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.window.x, sv.window.y)
        end
        if sv.window.scale and sv.window.scale > 0 then win:SetScale(sv.window.scale) end
    end

    built = true
end

-- ── visual prefs ────────────────────────────────────────────────────────────

local function apply_visual_prefs()
    local op = Prefs.get("opacity") or 0.97
    P.set_rect_color(W.bg, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], op })
    W.haul.container:SetHidden(not Prefs.get("show_haul"))
end

-- ── render ────────────────────────────────────────────────────────────────

local function render_header(m)
    local total = BGMeter.History.count()
    local dur = (m.durationMs and m.durationMs > 0) and ("  ·  " .. F.duration(m.durationMs)) or ""
    local when = ""
    if m.capturedAt and type(GetTimeStamp) == "function" then
        local ago = GetTimeStamp() - m.capturedAt
        if ago >= 0 then when = "  ·  " .. (ago < 60 and "just now" or (F.countdown(ago) .. " ago")) end
    end
    set_text(W.header.subtitle, (m.name or "Battleground") .. dur .. when)
    set_text(W.header.counter, string.format("%d / %d", current_index, math.max(total, 1)))
    local glow = W.header.bannerGlow
    local function set_banner(text, col, glowCol)
        set_text(W.header.banner, text); S.color(W.header.banner, col)
        if glow then
            if glowCol then glow:SetColor(glowCol[1], glowCol[2], glowCol[3], 0.45); glow:SetHidden(false)
            else glow:SetHidden(true) end
        end
    end
    if m.result == "WIN" then set_banner("VICTORY", K.COLOR.heal, K.COLOR.heal)
    elseif m.result == "LOSS" then set_banner("DEFEAT", K.COLOR.accent, K.COLOR.accent)
    elseif m.result == "TIE" then set_banner("DRAW", K.COLOR.gold, K.COLOR.gold)
    else set_banner("MATCH RESULTS", K.COLOR.text_dim, nil) end
end

local function render_battle(m, animate)
    local b = W.battle
    b.row_pool:release_all()

    local key = Prefs.get("sort_key") or "damage"
    if key == "name" then
        table.sort(m.battle, function(a, z) return (a.displayName or a.charName or "") < (z.displayName or z.charName or "") end)
    else
        BGMeter.Match.sort(m, key, Prefs.get("sort_desc"))
    end

    for ckey, lbl in pairs(b.headers) do
        local base = (ckey == "name") and "PLAYER" or ckey
        for _, col in ipairs(COLS) do if col.key == ckey then base = col.label end end
        if ckey == key then
            S.color(lbl, K.COLOR.text)
            set_text(lbl, base .. " " .. F.icon(Prefs.get("sort_desc") and ICON_SORTDN or ICON_SORTUP, 16))
        else
            S.color(lbl, K.COLOR.text_dim); set_text(lbl, base)
        end
    end

    local awards = Prefs.get("show_awards") and Awards.compute(m) or { leaders = {}, mvp = nil }
    local barKey = (key == "name" or key == "deaths") and "damage" or key
    local maxVal = BGMeter.Match.column_max(m, barKey)
    local barBase = (barKey == "healing") and K.COLOR.heal or K.COLOR.accent
    local listW = list_width()
    local y = 24

    for i, prow in ipairs(m.battle) do
        local row = b.row_pool:acquire()
        row.prow = prow
        row.container:SetHidden(false)
        row.container:ClearAnchors()
        row.container:SetAnchor(TOPLEFT, b.container, TOPLEFT, 0, y)
        row.container:SetAnchor(TOPRIGHT, b.container, TOPRIGHT, 0, y)

        set_text(row.index, tostring(i))
        local cicon = Icons.class(prow.classId)
        if cicon then row.classIcon:SetTexture(cicon); row.classIcon:SetHidden(false) else row.classIcon:SetHidden(true) end

        local nm = prow.displayName or prow.charName or "?"
        if awards.mvp == prow then nm = F.icon(ICON_STAR, 20) .. " " .. nm end
        set_text(row.name, nm)
        S.color(row.name, prow.isLocal and K.COLOR.you or S.team_color(prow.team))

        if prow.team then
            local tc = S.team_color(prow.team)
            P.set_rect_color(row.teamStrip, { tc[1], tc[2], tc[3], 0.85 })
        else
            P.set_rect_color(row.teamStrip, { 0, 0, 0, 0 })
        end

        for _, col in ipairs(COLS) do
            local cell, v = row.cells[col.key], prow[col.key] or 0
            set_text(cell, (col.key == "damage" or col.key == "healing" or col.key == "score") and F.abbrev(v) or tostring(v))
            if awards.leaders[col.key] == prow and v > 0 then S.color(cell, K.COLOR.gold)
            elseif v == 0 then S.color(cell, K.COLOR.text_dim)
            else S.color(cell, K.COLOR.text) end
        end

        local pct = (maxVal > 0) and ((prow[barKey] or 0) / maxVal) or 0
        local bc = prow.isLocal and K.COLOR.you or barBase
        set_bar(row.bar, pct, { bc[1], bc[2], bc[3], 0.20 }, listW - BAR_X - BAR_RIGHT, animate)

        local hl = { 0, 0, 0, 0 }
        if awards.mvp == prow then hl = { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.08 } end
        if prow.isLocal then hl = { K.COLOR.you[1], K.COLOR.you[2], K.COLOR.you[3], 0.07 } end
        if selected_row == prow then hl = { 1, 1, 1, 0.13 } end
        row.baseHL = hl
        P.set_rect_color(row.highlight, hl)
        row.container:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then W.select(prow) end end)

        y = y + L.row_h
    end
end

local function render_haul(m, animate)
    local p, h = W.haul, m.haul
    local rec = m.records or {}
    local vet = h.vetEnd or h.vetStart
    local vetControls = { p.vetIcon, p.vetTitle, p.vetTier, p.track.container, p.vetDelta, p.season }

    if not Prefs.get("show_veterancy") then
        hide_all(vetControls, true)
    elseif vet and vet.rank then
        hide_all(vetControls, false)
        if vet.rankIcon then p.vetIcon:SetTexture(vet.rankIcon); p.vetIcon:SetHidden(false) else p.vetIcon:SetHidden(true) end
        set_text(p.vetTitle, vet.rankTitle or ("Veteran Rank " .. tostring(vet.rank)))
        set_text(p.vetTier, vet.tier and string.format("Tier %d", vet.tier) or "")
        local hasPct = vet.percent ~= nil
        Bar.set_hidden(p.track, not hasPct)
        if hasPct then set_bar(p.track, vet.percent, K.COLOR.veterancy, L.haul_w - 32, animate) end
        if h.vetRankUp then
            set_text(p.vetDelta, "RANK UP this match!"); S.color(p.vetDelta, K.COLOR.gold)
        elseif hasPct then
            local txt
            if vet.tierTotal and vet.tierTotal > 0 then
                txt = string.format("%s / %s to next rank", F.commas(vet.progressToNext or 0), F.commas(vet.tierTotal))
            else
                txt = "max rank reached"
            end
            set_text(p.vetDelta, txt); S.color(p.vetDelta, K.COLOR.veterancy)
        else
            set_text(p.vetDelta, "")
        end
        set_text(p.season, vet.seasonName or "")
        local endsTxt = (vet.secondsLeft and vet.secondsLeft > 0)
            and ("\nseason ends in " .. F.countdown(vet.secondsLeft)) or ""
        W.tips[p.vetIcon] = string.format("%s%s\n%s%s",
            vet.rankTitle or ("Veteran Rank " .. tostring(vet.rank)),
            vet.tier and ("  ·  Tier " .. vet.tier) or "",
            vet.seasonName or "Veterancy season", endsTxt)
    else
        hide_all(vetControls, false)
        p.vetIcon:SetHidden(true)
        set_text(p.vetTitle, "Veterancy"); set_text(p.vetTier, "(no season data)")
        Bar.set_hidden(p.track, true); set_text(p.vetDelta, ""); set_text(p.season, "")
        W.tips[p.vetIcon] = nil
    end

    set_count(p.ap.val, h.apGained, "+", animate)
    set_count(p.xp.val, h.xpGained, "+", animate)
    set_text(p.cp.val, h.cpGained > 0 and F.signed(h.cpGained) or "+0")
    S.color(p.ap.val, rec.ap and K.COLOR.you or K.COLOR.gold)
    if rec.ap and animate then pop(p.ap.val) end

    local lr = BGMeter.Match.local_row(m)
    local ids = lr and lr.medalIds or {}
    for i = 1, #p.medalIcons do
        local mi, id = p.medalIcons[i], ids[i]
        local tex = id and Icons.medal(id) or nil
        if tex then
            mi:SetTexture(tex); mi:SetHidden(false)
            local ok, nm, _ic, cond = pcall(GetMedalInfo, id)
            W.tips[mi] = ok and ((nm or "Medal") .. (cond and ("\n" .. cond) or "")) or nil
        else mi:SetHidden(true); W.tips[mi] = nil end
    end
    set_text(p.medalMore, (#ids > #p.medalIcons) and ("+" .. (#ids - #p.medalIcons)) or "")

    set_text(p.eff, string.format("%s AP/min  ·  %s AP/kill", F.commas(h.apPerMin), F.commas(h.apPerKill)))

    local standControls = { p.sep, p.standHeading, p.standRank, p.standSub }
    if not Prefs.get("show_standing") then hide_all(standControls, true); return end
    hide_all(standControls, false)

    -- The big rank font lacks the movement glyphs, so the indicator lives on the
    -- small sub-line as a real inline arrow texture (unicode ▲/▼ box out in
    -- several fonts) plus a colour-coded count; the big number stays clean.
    local st = m.standing
    if not st then
        set_text(p.standRank, "..."); S.color(p.standRank, K.COLOR.text_dim)
        set_text(p.standSub, "loading leaderboard...")
        W.tips[p.standRank] = "Competitive leaderboard standing"
    elseif st.rank and st.rank > 0 then
        -- big rank font lacks the ★ glyph (it renders as a box) -> keep the
        -- number clean, signal a personal best with gold colour + a sub badge.
        set_text(p.standRank, "#" .. F.commas(st.rank))
        local rankCol, move = K.COLOR.text, ""
        if st.rankDelta > 0 then rankCol = K.COLOR.heal; move = F.icon(ICON_SORTUP, 16) .. string.format(" |c5cc85f%d up|r   ", st.rankDelta)
        elseif st.rankDelta < 0 then rankCol = K.COLOR.accent; move = F.icon(ICON_SORTDN, 16) .. string.format(" |ce34234%d down|r   ", -st.rankDelta)
        elseif st.prevRank == 0 then rankCol = K.COLOR.gold; move = "|cf2cc55NEW|r   "
        else move = "|c8a8a8ano change|r   " end
        if rec.rank then move = F.icon(ICON_STAR, 16) .. " |cf2cc55best!|r   " .. move end
        S.color(p.standRank, rec.rank and K.COLOR.gold or rankCol)
        if rec.rank and animate then pop(p.standRank) end
        local sub = move .. "rating " .. F.commas(st.score)
        if st.scoreDelta and st.scoreDelta ~= 0 then
            sub = sub .. string.format(" (%s%s)", st.scoreDelta > 0 and "+" or "", F.commas(st.scoreDelta))
        end
        set_text(p.standSub, sub)
        local tip = "Competitive leaderboard standing\n"
        if st.rankDelta > 0 then tip = tip .. string.format("up %d since your last match", st.rankDelta)
        elseif st.rankDelta < 0 then tip = tip .. string.format("down %d since your last match", -st.rankDelta)
        elseif st.prevRank == 0 then tip = tip .. "your first ranked match"
        else tip = tip .. "no change since your last match" end
        if st.mmr then tip = tip .. "\nhidden MMR: " .. F.commas(st.mmr) end
        if not st.impacts then tip = tip .. "\n(this match did not affect rank)" end
        W.tips[p.standRank] = tip
    else
        set_text(p.standRank, "unranked"); S.color(p.standRank, K.COLOR.text_dim)
        set_text(p.standSub, st.impacts and "no leaderboard entry yet" or "this match did not affect rank")
        W.tips[p.standRank] = "Competitive leaderboard standing\nplay a ranked battleground to appear"
    end
end

function W.render(animate)
    if not built then return end
    if Anim then Anim.clear() end
    apply_visual_prefs()
    if W.settings then W.settings.repaint() end

    local m = BGMeter.History.get(current_index)
    if W.emptyIcon then W.emptyIcon:SetHidden(m ~= nil) end
    if not m then
        set_text(W.header.banner, "NO MATCHES YET"); S.color(W.header.banner, K.COLOR.text_dim)
        if W.header.bannerGlow then W.header.bannerGlow:SetHidden(true) end
        set_text(W.header.subtitle, "finish a battleground, or try  /bgmeter demo")
        set_text(W.header.counter, "0 / 0")
        W.battle.row_pool:release_all()
        set_text(W.detail, "")
        return
    end
    render_header(m)
    render_battle(m, animate)
    render_haul(m, animate)
    W.render_detail(m)
end

function W.render_detail(m)
    if selected_row then
        local r = selected_row
        set_text(W.detail, string.format("%s  ·  %s  --  %s dmg  ·  %s heal  ·  %d kills  %d deaths  %d assists  ·  %d medals",
            r.displayName or r.charName or "?", team_name(r.team),
            F.commas(r.damage), F.commas(r.healing), r.kills, r.deaths, r.assists, r.medals or 0))
        S.color(W.detail, K.COLOR.text_dim)
    else
        local session = BGMeter.Session and BGMeter.Session.summary()
        set_text(W.detail, session or "click a row for detail  ·  click a column header to sort  ·  drag an edge to resize")
        S.color(W.detail, session and K.COLOR.gold or K.COLOR.text_dim)
    end
end

-- ── controller actions ──────────────────────────────────────────────────────

function W.sort_by(key)
    if Prefs.get("sort_key") == key then Prefs.set("sort_desc", not Prefs.get("sort_desc"))
    else Prefs.set("sort_key", key); Prefs.set("sort_desc", true) end
    Sound.play("nav"); W.render(false)
end

function W.select(prow)
    selected_row = (selected_row == prow) and nil or prow
    W.render(false)
end

function W.step(dir)
    local total = BGMeter.History.count()
    if total == 0 then return end
    current_index = math.max(1, math.min(total, current_index + dir))
    selected_row = nil
    Sound.play("nav"); W.render(true)
end

function W.toggle_settings()
    if not built then return end
    settings_open = not settings_open
    W.settings.window:SetHidden(not settings_open)
    if settings_open then
        W.settings.repaint()
        Sound.play("open")
    end
end

function W.show_match(index)
    build()
    current_index = index or 1
    selected_row = nil
    settings_open = false
    W.settings.window:SetHidden(true)
    W.win:SetHidden(false)
    W.render(true)
    if Prefs.get("animate") then W.win:SetAlpha(0); Anim.value(0, 1, 220, function(v) W.win:SetAlpha(v) end)
    else W.win:SetAlpha(1) end
    W._persist_hidden(false)
end

function W.show() W.show_match(current_index); Sound.play("open") end

function W.refresh_if_visible()
    if not built or W.win:IsHidden() then return end
    if current_index == 1 then W.render(false) end
end

function W.hide()
    if not built then return end
    settings_open = false
    W.settings.window:SetHidden(true)
    W.win:SetHidden(true); W._persist_hidden(true)
end

function W.toggle()
    build()
    if W.win:IsHidden() then W.show() else W.hide() end
end

function W.on_move_stop()
    if not built then return end
    local sv = BGMeter.zenimax.savedvars.get()
    if sv then sv.window = sv.window or {}; sv.window.x = W.win:GetLeft(); sv.window.y = W.win:GetTop() end
end

function W.on_resize_stop()
    if not built then return end
    W.cur_w, W.cur_h = W.win:GetWidth(), W.win:GetHeight()
    local sv = BGMeter.zenimax.savedvars.get()
    if sv then sv.window = sv.window or {}; sv.window.w = W.cur_w; sv.window.h = W.cur_h end
    W.render(false)
end

function W._persist_hidden(hidden)
    local sv = BGMeter.zenimax.savedvars.get()
    if sv then sv.window = sv.window or {}; sv.window.hidden = hidden end
end

function W.init() BGMeter.Log.debug("window ready") end

BGMeter.UI.window = W
