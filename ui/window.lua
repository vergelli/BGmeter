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
local user_visible = false
local on_hud = true
local in_combat = false
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

local TX = {
    close  = { n = "EsoUI/Art/Buttons/decline_up.dds",   p = "EsoUI/Art/Buttons/decline_down.dds",   o = "EsoUI/Art/Buttons/decline_over.dds" },
    gear   = { n = "EsoUI/Art/MenuBar/menuBar_mainMenu_over.dds", p = "EsoUI/Art/MenuBar/menuBar_mainMenu_down.dds", o = "EsoUI/Art/MenuBar/menuBar_mainMenu_over.dds" },
    prev   = { n = "EsoUI/Art/Buttons/large_leftArrow_up.dds",  p = "EsoUI/Art/Buttons/large_leftArrow_down.dds",  o = "EsoUI/Art/Buttons/large_leftArrow_over.dds" },
    nextb  = { n = "EsoUI/Art/Buttons/large_rightArrow_up.dds", p = "EsoUI/Art/Buttons/large_rightArrow_down.dds", o = "EsoUI/Art/Buttons/large_rightArrow_over.dds" },
    export = { n = "EsoUI/Art/Bank/bank_tabIcon_withdraw_up.dds", p = "EsoUI/Art/Bank/bank_tabIcon_withdraw_down.dds", o = "EsoUI/Art/Bank/bank_tabIcon_withdraw_over.dds" },
}

local SCOREBG_L  = "EsoUI/Art/Battlegrounds/battlegrounds_scoreboardBG_left.dds"
local SCOREBG_R  = "EsoUI/Art/Battlegrounds/battlegrounds_scoreboardBG_right.dds"
local PIP_ART    = "EsoUI/Art/Battlegrounds/battleground_round_%s.dds"
local PIP_EMPTY  = "EsoUI/Art/Battlegrounds/battleground_round_empty.dds"

local MAP_ART = {
    ["temple"] = "esoui/art/loadingscreens/loadscreen_battleground_temple_01.dds",
}
local MAP_ART_ALPHA = 0.24

local TEAM_KEY

local function team_art_key(team)
    if not TEAM_KEY then
        TEAM_KEY = {}
        if C.BATTLEGROUND_TEAM_FIRE_DRAKES then TEAM_KEY[C.BATTLEGROUND_TEAM_FIRE_DRAKES] = "fire" end
        if C.BATTLEGROUND_TEAM_PIT_DAEMONS then TEAM_KEY[C.BATTLEGROUND_TEAM_PIT_DAEMONS] = "pit" end
        if C.BATTLEGROUND_TEAM_STORM_LORDS then TEAM_KEY[C.BATTLEGROUND_TEAM_STORM_LORDS] = "storm" end
    end
    return TEAM_KEY[team]
end

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
    if team == nil then return "" end
    local A = BGMeter.zenimax.api
    if type(A.get_team_name) == "function" then
        local ok, name = pcall(A.get_team_name, team)
        if ok and name and name ~= "" then return name end
    end
    if team == C.BATTLEGROUND_TEAM_FIRE_DRAKES then return "Fire Drakes" end
    if team == C.BATTLEGROUND_TEAM_PIT_DAEMONS then return "Pit Daemons" end
    if team == C.BATTLEGROUND_TEAM_STORM_LORDS then return "Storm Lords" end
    return ""
end

local function team_icon(team)
    if team == nil then return nil end
    local A = BGMeter.zenimax.api
    if type(A.get_team_icon) == "function" then
        local ok, icon = pcall(A.get_team_icon, team)
        if ok and icon and icon ~= "" then return icon end
    end
    return nil
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

    h.bannerGlow = P.icon(win, "EsoUI/Art/Crafting/crafting_tooltip_glow_center.dds")
    h.bannerGlow:SetAnchor(TOP, win, TOP, 0, 2)
    h.bannerGlow:SetDimensions(360, 64)
    if h.bannerGlow.SetBlendMode then h.bannerGlow:SetBlendMode(TEX_BLEND_MODE_ADD) end
    h.bannerGlow:SetHidden(true)

    h.banner = P.label(win, S.FONT.banner, K.COLOR.text)
    h.banner:SetAnchor(TOP, win, TOP, 0, 8)
    h.banner:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    h.chips = {}
    for i = 1, 3 do
        local chip = {}
        chip.icon = P.icon(win)
        chip.icon:SetDimensions(18, 18)
        chip.label = P.label(win, S.FONT.small, K.COLOR.text)
        chip.label:SetAnchor(LEFT, chip.icon, RIGHT, 3, 0)
        chip.label:SetHeight(18)
        chip.icon:SetHidden(true)
        chip.label:SetHidden(true)
        h.chips[i] = chip
    end

    h.close = mk_button(win, TX.close, 22, function() W.hide() end, "Close")
    h.close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -L.margin, 14)

    h.gear = mk_button(win, TX.gear, 28, function() W.toggle_settings() end, "Settings")
    h.gear:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 30), 11)

    h.export = mk_button(win, TX.export, 24, function() W.export() end, "Export match data")
    h.export:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 64), 13)

    h.next = mk_button(win, TX.nextb, 26, function() W.step(1) end, "Newer match")
    h.next:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 100), 13)

    h.counter = P.label(win, S.FONT.small, K.COLOR.text_dim)
    h.counter:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 132), 17)
    h.counter:SetDimensions(48, 18)
    h.counter:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    h.prev = mk_button(win, TX.prev, 26, function() W.step(-1) end, "Older match")
    h.prev:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin + 184), 13)

    return h
end

local function layout_chips(m)
    local h = W.header
    local teams = m and m.teams
    local n = (teams and #teams) or 0
    if n == 0 then
        for i = 1, 3 do h.chips[i].icon:SetHidden(true); h.chips[i].label:SetHidden(true) end
        return
    end
    local multi = (m.numRounds or 1) > 1
    local widths, total = {}, 0
    for i = 1, 3 do
        local chip, t = h.chips[i], teams[i]
        if t then
            local txt
            if multi then
                local pips = {}
                local key = team_art_key(t.team)
                local colorName = key and K.TEAM_ART[key] or nil
                for r = 1, math.min(m.numRounds, 5) do
                    pips[#pips + 1] = F.icon((r <= (t.roundsWon or 0)) and (colorName and PIP_ART:format(colorName) or PIP_EMPTY) or PIP_EMPTY, 12)
                end
                txt = table.concat(pips, "")
            else
                txt = F.abbrev(t.score or 0)
            end
            chip.label:SetText(txt)
            local tc = S.team_color(t.team)
            chip.label:SetColor(tc[1], tc[2], tc[3], 1)
            local ic = team_icon(t.team)
            if ic then chip.icon:SetTexture(ic); chip.icon:SetColor(1, 1, 1, 1)
            else chip.icon:SetTexture("EsoUI/Art/Collections/favorite_starOnly.dds"); chip.icon:SetColor(tc[1], tc[2], tc[3], 1) end
            local wpx = 21 + chip.label:GetTextWidth()
            widths[i] = wpx
            total = total + wpx
        end
    end
    local GAPX = 18
    total = total + GAPX * (n - 1)
    local x = -total / 2
    for i = 1, 3 do
        local chip, t = h.chips[i], teams[i]
        if t and widths[i] then
            chip.icon:ClearAnchors()
            chip.icon:SetAnchor(TOP, W.win, TOP, x + 9, 46)
            chip.icon:SetHidden(false)
            chip.label:SetHidden(false)
            x = x + widths[i] + GAPX
        else
            chip.icon:SetHidden(true)
            chip.label:SetHidden(true)
        end
    end
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

    b.chart = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
    b.chart:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, 0)
    b.chart:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, 0)
    b.chart:SetHeight(L.chart_h)
    b.chart:SetHidden(true)

    b.chartBg = P.rect(b.chart, { 1, 1, 1, 0.04 })
    b.chartBg:SetAnchorFill(b.chart)

    b.chartTitle = P.label(b.chart, S.FONT.small, K.COLOR.text_dim)
    b.chartTitle:SetText("MATCH TIMELINE")
    b.chartTitle:SetAnchor(TOPLEFT, b.chart, TOPLEFT, 4, 2)

    b.dot_pool = BGMeter.Plot.pool.new(
        function()
            local d = P.rect(b.chart, { 1, 1, 1, 1 })
            d:SetDimensions(3, 3)
            return d
        end,
        function(d) d:SetHidden(true) end)

    local probe = P.line(b.chart, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        b.lines_ok = true
        b.line_pool = BGMeter.Plot.pool.new(
            function() return P.line(b.chart, { 1, 1, 1, 1 }, 2) end,
            function(ln) ln:SetHidden(true); ln:ClearAnchors() end)
    else
        b.lines_ok = false
    end

    b.cursor = P.rect(b.chart, { 1, 1, 1, 0.30 })
    b.cursor:SetDimensions(1, L.chart_h - 4)
    b.cursor:SetHidden(true)

    b.chart:SetMouseEnabled(true)
    b.chart:SetHandler("OnMouseEnter", function() W._chart_hover_start() end)
    b.chart:SetHandler("OnMouseExit", function() W._chart_hover_stop() end)

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
    if TEXT_WRAP_MODE_ELLIPSIS and row.name.SetWrapMode then
        row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end

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
    p.medalBadges = {}
    for i = 1, MEDAL_CAP do
        local col = (i - 1) % MEDAL_PERROW
        local rowN = math.floor((i - 1) / MEDAL_PERROW)
        local mi = P.icon(p.container)
        mi:SetDimensions(22, 22)
        mi:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, col * MEDAL_STEP, 6 + rowN * MEDAL_STEP)
        mi:SetHidden(true)
        p.medalIcons[i] = mi

        local badge = P.label(p.container, S.FONT.small, K.COLOR.gold)
        badge:SetAnchor(BOTTOMRIGHT, mi, BOTTOMRIGHT, 3, 3)
        badge:SetDimensions(20, 12)
        badge:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        badge:SetDrawLevel(5)
        badge:SetHidden(true)
        p.medalBadges[i] = badge
    end
    p.medalMore = P.label(p.container, S.FONT.small, K.COLOR.medal)
    p.medalMore:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, 0, 6 + 2 * MEDAL_STEP)

    -- efficiency, anchored below a reserved two-row medal grid
    p.eff = P.label(p.container, S.FONT.small, K.COLOR.accent)
    p.eff:SetAnchor(TOPLEFT, p.medalLabel, BOTTOMLEFT, 0, 8 + 2 * MEDAL_STEP)
    p.eff:SetDimensions(INNER, 16)
    p.eff:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    p.sep = P.rect(p.container, { 1, 1, 1, 0.10 })
    p.sep:SetAnchor(BOTTOMLEFT, p.container, BOTTOMLEFT, PAD, -96)
    p.sep:SetDimensions(INNER, 1)

    p.standHeading = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    p.standHeading:SetText("COMPETITIVE STANDING")
    p.standHeading:SetAnchor(TOPLEFT, p.sep, BOTTOMLEFT, 0, 10)
    p.standHeading:SetDimensions(INNER, 16)
    p.standHeading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    p.standRank = P.label(p.container, S.FONT.big, K.COLOR.text)
    p.standRank:SetAnchor(TOP, p.standHeading, BOTTOM, 0, 4)
    p.standRank:SetDimensions(INNER, 30)
    p.standRank:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    p.standSub = P.label(p.container, S.FONT.small, K.COLOR.text_dim)
    p.standSub:SetAnchor(TOP, p.standRank, BOTTOM, 0, 2)
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

local AUTO_OPEN_STATES = { "exit", "instant", "off" }
local AUTO_OPEN_LABELS = { exit = "ON EXIT", instant = "INSTANT", off = "OFF" }

local SETTINGS_SECTIONS = {
    { title = "GENERAL", rows = {
        { kind = "cycle",  key = "auto_open_mode", label = "Auto-open results" },
        { kind = "toggle", key = "sounds",         label = "Sound cues" },
        { kind = "toggle", key = "animate",        label = "Animations" },
    } },
    { title = "RESULT WINDOW", rows = {
        { kind = "toggle", key = "show_haul",      label = "Haul panel" },
        { kind = "toggle", key = "show_veterancy", label = "Veterancy track" },
        { kind = "toggle", key = "show_standing",  label = "Competitive standing" },
        { kind = "toggle", key = "show_awards",    label = "MVP / column leaders" },
        { kind = "toggle", key = "show_timeline",  label = "Match timeline chart" },
    } },
    { title = "VANGUARD BAR", rows = {
        { kind = "toggle", key = "show_vanguard",  label = "Show the HUD bar" },
        { kind = "toggle", key = "vanguard_dock",  label = "Dock to the XP bar" },
        { kind = "toggle", key = "vanguard_fade",  label = "Auto-fade when idle" },
    } },
}

local function text_button(parent, label)
    local b = BGMeter.zenimax.ui.create_from_virtual(nil, parent, "ZO_DefaultButton")
    b:SetText(label)
    return b
end

local function on_pref_changed(key)
    if BGMeter.UI.vanguard then
        if key == "show_vanguard" then
            if Prefs.get("show_vanguard") then BGMeter.UI.vanguard.show() else BGMeter.UI.vanguard.hide() end
        elseif key == "vanguard_dock" or key == "vanguard_fade" then
            BGMeter.UI.vanguard.sync()
        end
    end
    Sound.play("nav")
    W.render(false)
end

local function build_settings()
    local s = {}
    local ROW_H, SEC_H, PADX = 28, 24, 18

    local rowsTotal = 0
    for _, sec in ipairs(SETTINGS_SECTIONS) do rowsTotal = rowsTotal + #sec.rows end
    local winH = 56 + #SETTINGS_SECTIONS * SEC_H + rowsTotal * ROW_H + 92

    local win = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterSettingsWindow")
    win:SetDimensions(324, winH)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetDrawTier(DT_HIGH)
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
    local y = 48
    for _, sec in ipairs(SETTINGS_SECTIONS) do
        local head = P.label(win, S.FONT.small, K.COLOR.gold)
        head:SetText(sec.title)
        head:SetAnchor(TOPLEFT, win, TOPLEFT, PADX, y + 6)
        head:SetDimensions(200, 14)
        local rule = P.rect(win, { 1, 1, 1, 0.08 })
        rule:SetAnchor(TOPLEFT, win, TOPLEFT, PADX, y + SEC_H - 2)
        rule:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PADX, y + SEC_H - 2)
        rule:SetHeight(1)
        y = y + SEC_H

        for _, t in ipairs(sec.rows) do
            local name = P.label(win, S.FONT.row, K.COLOR.text)
            name:SetText(t.label)
            name:SetAnchor(TOPLEFT, win, TOPLEFT, PADX + 4, y)
            name:SetDimensions(190, ROW_H - 2)
            name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            local btn = text_button(win, "")
            btn:SetDimensions(84, ROW_H - 4)
            btn:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PADX, y)
            local key, kind = t.key, t.kind
            local paint
            if kind == "cycle" then
                paint = function() btn:SetText(AUTO_OPEN_LABELS[Prefs.get(key)] or "?") end
                btn:SetHandler("OnClicked", function()
                    local cur = Prefs.get(key)
                    local idx = 1
                    for i, v in ipairs(AUTO_OPEN_STATES) do if v == cur then idx = i break end end
                    Prefs.set(key, AUTO_OPEN_STATES[(idx % #AUTO_OPEN_STATES) + 1])
                    paint(); on_pref_changed(key)
                end)
            else
                paint = function() btn:SetText(Prefs.get(key) and "ON" or "OFF") end
                btn:SetHandler("OnClicked", function()
                    Prefs.toggle(key)
                    paint(); on_pref_changed(key)
                end)
            end
            s.rows[key] = paint
            y = y + ROW_H
        end
    end

    local clear = text_button(win, "Clear match history")
    clear:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PADX, -52)
    clear:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PADX, -52)
    clear:SetHeight(28)
    clear:SetHandler("OnClicked", function() BGMeter.History.clear(); current_index = 1; W.toggle_settings(); W.render(false) end)

    local reset = text_button(win, "Reset window size & position")
    reset:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PADX, -16)
    reset:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PADX, -16)
    reset:SetHeight(28)
    reset:SetHandler("OnClicked", function()
        local sv = BGMeter.zenimax.savedvars.get()
        if sv then
            sv.window.x, sv.window.y, sv.window.w, sv.window.h = 0, 0, 0, 0
            sv.window.scale = 1.0
        end
        W.cur_w, W.cur_h = L.window_w, L.window_h
        W.win:SetDimensions(W.cur_w, W.cur_h)
        W.win:SetScale(1)
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

    W.bgMap = P.icon(win)
    W.bgMap:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
    W.bgMap:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -2, -2)
    W.bgMap:SetColor(1, 1, 1, MAP_ART_ALPHA)
    W.bgMap:SetHidden(true)

    W.bgArtL = P.icon(win, SCOREBG_L)
    W.bgArtL:SetAnchor(TOPLEFT, win, TOPLEFT, L.margin - 6, L.header_h - 4)
    W.bgArtL:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(L.haul_w + L.gap + L.margin - 6), -10)
    W.bgArtL:SetColor(1, 1, 1, 0.22)

    W.bgArtR = P.icon(win, SCOREBG_R)
    W.bgArtR:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin - 6), L.header_h - 4)
    W.bgArtR:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(L.margin - 6), -10)
    W.bgArtR:SetWidth(L.haul_w + 12)
    W.bgArtR:SetColor(1, 1, 1, 0.22)

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

    W.measure = P.label(win, S.FONT.row, K.COLOR.text)
    W.measure:SetHidden(true)

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

local function map_art_candidates(name)
    local out, seen = {}, {}
    local function add(path)
        if path and not seen[path] then seen[path] = true; out[#out + 1] = path end
    end
    local lower = name:lower()
    for key, path in pairs(MAP_ART) do
        if lower:find(key, 1, true) then add(path) end
    end
    local words = {}
    for w in lower:gmatch("[a-z]+") do words[#words + 1] = w end
    local function guess(slug)
        add(string.format("esoui/art/loadingscreens/loadscreen_battleground_%s_01.dds", slug))
    end
    if #words > 0 then
        guess(table.concat(words, "_"))
        guess(words[#words])
        guess(words[1])
    end
    return out
end

local function apply_map_art(m)
    local art = W.bgMap
    if not art then return end
    local name = (m and m.name) or ""
    if name == "" then art:SetHidden(true); return end
    local cands = map_art_candidates(name)
    if #cands == 0 then art:SetHidden(true); return end

    W.map_token = (W.map_token or 0) + 1
    local token = W.map_token
    local idx = 0
    local function try_next()
        if token ~= W.map_token then return end
        idx = idx + 1
        if idx > #cands then art:SetHidden(true); return end
        art:SetTexture(cands[idx])
        art:SetHidden(false)
        if type(zo_callLater) ~= "function" then return end
        zo_callLater(function()
            if token ~= W.map_token then return end
            local ok, loaded = pcall(function() return art:IsTextureLoaded() end)
            if ok and loaded == false then
                try_next()
            else
                BGMeter.Log.debug("map art resolved: %s", cands[idx])
            end
        end, 400)
    end
    try_next()
end

local function render_header(m)
    local total = BGMeter.History.count()
    local dur = (m.durationMs and m.durationMs > 0) and ("  ·  " .. F.duration(m.durationMs)) or ""
    local when = ""
    local A = BGMeter.zenimax.api
    if m.capturedAt and type(A.get_timestamp) == "function" then
        local ago = A.get_timestamp() - m.capturedAt
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
    apply_map_art(m)
    layout_chips(m)
end

local DYN_MIN_CAP = 940

local function apply_dynamic_min_width(m)
    if not W.measure then return end
    local maxw = 0
    for _, prow in ipairs(m.battle) do
        W.measure:SetText(prow.displayName or prow.charName or "?")
        local tw = W.measure:GetTextWidth() or 0
        if tw > maxw then maxw = tw end
    end
    if maxw <= 0 then return end
    local needed = math.ceil(maxw) + 26 + NAME_X + NAME_RIGHT + 2 * L.margin + L.haul_w + L.gap
    local dyn = math.max(L.min_w, math.min(needed, DYN_MIN_CAP))
    if dyn ~= W.dyn_min then
        W.dyn_min = dyn
        W.win:SetDimensionConstraints(dyn, L.min_h, L.max_w, L.max_h)
    end
    if W.cur_w < dyn then
        W.cur_w = dyn
        W.win:SetWidth(dyn)
        local sv = BGMeter.zenimax.savedvars.get()
        if sv then sv.window = sv.window or {}; sv.window.w = dyn end
    end
end

local function render_battle(m, animate)
    local b = W.battle
    b.row_pool:release_all()
    apply_dynamic_min_width(m)

    local key = Prefs.get("sort_key") or "damage"
    if key == "name" then
        local desc = Prefs.get("sort_desc")
        table.sort(m.battle, function(a, z)
            local an = (a.displayName or a.charName or ""):lower()
            local zn = (z.displayName or z.charName or ""):lower()
            if desc then return an > zn end
            return an < zn
        end)
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

local function timeline_ok(m)
    local tl = m.timeline
    return Prefs.get("show_timeline") and tl and tl.t and #tl.t >= 3
end

local function series_max(arr, n)
    local mx = 0
    for i = 1, n do
        local v = arr and arr[i] or 0
        if v > mx then mx = v end
    end
    return mx
end

local chart_state = nil

local function render_timeline(m)
    local b = W.battle
    b.dot_pool:release_all()
    if b.line_pool then b.line_pool:release_all() end
    chart_state = nil
    if not timeline_ok(m) then
        b.chart:SetHidden(true)
        return
    end
    local rows_h = 24 + #m.battle * L.row_h
    local cont_h = b.container:GetHeight()
    if cont_h - rows_h < L.chart_h + 8 then
        b.chart:SetHidden(true)
        return
    end
    b.chart:SetHidden(false)

    local tl = m.timeline
    local n = #tl.t
    local w = b.chart:GetWidth()
    local h = L.chart_h
    if w <= 8 then return end

    local series = { tl.s1, tl.s2, tl.s3 }
    local smax = {}
    local maxScore = 1
    for s = 1, 3 do
        smax[s] = series_max(series[s], n)
        if smax[s] > maxScore then maxScore = smax[s] end
    end

    local tspan = math.max(1, tl.t[n] or 1)
    local plot_h = h - 18
    local function px(i) return math.floor((tl.t[i] / tspan) * (w - 6) + 0.5) end
    local function py(arr, i) return 14 + math.floor((1 - (arr[i] or 0) / maxScore) * plot_h + 0.5) end

    for s = 1, 3 do
        local arr = series[s]
        local team = tl.teams and tl.teams[s]
        if arr and smax[s] > 0 and team then
            local tc = S.team_color(team)
            if b.lines_ok then
                for i = 2, n do
                    local ln = b.line_pool:acquire()
                    ln:ClearAnchors()
                    ln:SetAnchor(TOPLEFT, b.chart, TOPLEFT, px(i - 1), py(arr, i - 1))
                    ln:SetAnchor(TOPRIGHT, b.chart, TOPLEFT, px(i), py(arr, i))
                    ln:SetColor(tc[1], tc[2], tc[3], 0.95)
                    if ln.SetThickness then ln:SetThickness(2) end
                    ln:SetHidden(false)
                end
            else
                for i = 1, n do
                    local dot = b.dot_pool:acquire()
                    dot:ClearAnchors()
                    dot:SetAnchor(TOPLEFT, b.chart, TOPLEFT, px(i), py(arr, i))
                    dot:SetDimensions(3, 3)
                    P.set_rect_color(dot, { tc[1], tc[2], tc[3], 0.95 })
                    dot:SetHidden(false)
                end
            end
        end
    end

    if m.killfeed then
        for _, k in ipairs(m.killfeed) do
            local mark = b.dot_pool:acquire()
            local x = math.floor((math.min(k.t or 0, tspan) / tspan) * (w - 6) + 0.5)
            mark:ClearAnchors()
            mark:SetAnchor(BOTTOMLEFT, b.chart, BOTTOMLEFT, x, -2)
            mark:SetDimensions(2, 8)
            if k.kind == "kill" then P.set_rect_color(mark, K.COLOR.gold)
            else P.set_rect_color(mark, K.COLOR.accent) end
            mark:SetHidden(false)
        end
    end

    chart_state = { tl = tl, n = n, w = w, smax = smax }
end

local function hexc(c)
    return string.format("%02x%02x%02x",
        math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function chart_hover_poll()
    local b = W.battle
    local st = chart_state
    if not st or b.chart:IsHidden() then W._chart_hover_stop(); return end
    local A = BGMeter.zenimax.api
    if type(A.get_ui_mouse) ~= "function" then return end
    local mx = A.get_ui_mouse()
    local rel = mx - b.chart:GetLeft()
    local w = b.chart:GetWidth()
    if rel < 0 then rel = 0 elseif rel > w then rel = w end

    local tl, n = st.tl, st.n
    local tspan = math.max(1, tl.t[n] or 1)
    local want_t = (rel / math.max(1, w - 6)) * tspan
    local idx = 1
    for i = 1, n do
        if tl.t[i] <= want_t then idx = i else break end
    end

    local x = math.floor((tl.t[idx] / tspan) * (w - 6) + 0.5)
    b.cursor:ClearAnchors()
    b.cursor:SetAnchor(TOPLEFT, b.chart, TOPLEFT, x, 2)
    b.cursor:SetHidden(false)

    local parts = { "team score  ·  t " .. F.duration(tl.t[idx]) }
    local series = { tl.s1, tl.s2, tl.s3 }
    for s = 1, 3 do
        local team = tl.teams and tl.teams[s]
        if team and st.smax[s] > 0 then
            local tc = S.team_color(team)
            parts[#parts + 1] = string.format("|c%s%s  %s|r",
                hexc(tc), team_name(team), F.commas((series[s] and series[s][idx]) or 0))
        end
    end
    if ZO_Tooltips_ShowTextTooltip then
        ZO_Tooltips_ShowTextTooltip(b.chart, TOP, table.concat(parts, "\n"))
    end
end

function W._chart_hover_start()
    if not chart_state then return end
    BGMeter.zenimax.events.register_update("BGMeterChartHover", 100, chart_hover_poll)
end

function W._chart_hover_stop()
    BGMeter.zenimax.events.unregister_update("BGMeterChartHover")
    if W.battle and W.battle.cursor then W.battle.cursor:SetHidden(true) end
    if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
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
    local counts = lr and lr.medalCounts or {}
    for i = 1, #p.medalIcons do
        local mi, badge, id = p.medalIcons[i], p.medalBadges[i], ids[i]
        local tex = id and Icons.medal(id) or nil
        if tex then
            mi:SetTexture(tex); mi:SetHidden(false)
            local n = counts[id] or 1
            if n > 1 then
                set_text(badge, "x" .. n)
                badge:SetHidden(false)
            else
                badge:SetHidden(true)
            end
            local ok, nm, _ic, cond, reward = pcall(GetMedalInfo, id)
            if ok then
                local lines = { (nm and nm ~= "" and nm or "Medal") .. (n > 1 and ("  |cf2cc55x" .. n .. "|r") or "") }
                if cond and cond ~= "" then lines[#lines + 1] = "|c9a9a9a" .. cond .. "|r" end
                if reward and reward > 0 then
                    lines[#lines + 1] = string.format("|cf2cc55+%s score%s|r", F.commas(reward), n > 1 and " each" or "")
                end
                W.tips[mi] = table.concat(lines, "\n")
            else
                W.tips[mi] = nil
            end
        else
            mi:SetHidden(true); badge:SetHidden(true); W.tips[mi] = nil
        end
    end
    set_text(p.medalMore, (#ids > #p.medalIcons) and ("+" .. (#ids - #p.medalIcons)) or "")

    set_text(p.eff, string.format("%s AP/min  ·  %s AP/kill", F.commas(h.apPerMin), F.commas(h.apPerKill)))

    local standControls = { p.sep, p.standHeading, p.standRank, p.standSub }
    if not Prefs.get("show_standing") then hide_all(standControls, true); return end
    local effBottom = p.eff:GetBottom() or 0
    local sepTop = p.sep:GetTop() or 0
    if effBottom > 0 and sepTop > 0 and effBottom + 6 > sepTop then
        hide_all(standControls, true)
        return
    end
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
        if W.bgMap then W.bgMap:SetHidden(true) end
        layout_chips(nil)
        set_text(W.header.subtitle, "finish a battleground, or try  /bgmeter demo")
        set_text(W.header.counter, "0 / 0")
        W.battle.row_pool:release_all()
        W.battle.dot_pool:release_all()
        W.battle.chart:SetHidden(true)
        set_text(W.detail, "")
        return
    end
    render_header(m)
    render_battle(m, animate)
    render_timeline(m)
    render_haul(m, animate)
    W.render_detail(m)
end

function W.render_detail(m)
    if selected_row then
        local r = selected_row
        local ic = team_icon(r.team)
        local prefix = ic and (F.icon(ic, 16) .. " ") or ""
        local taken = (r.taken and r.taken > 0) and string.format("  ·  %s taken", F.abbrev(r.taken)) or ""
        set_text(W.detail, string.format("%s%s  ·  %s  --  %s dmg  ·  %s heal%s  ·  %d/%d/%d  ·  %d medals",
            prefix, r.displayName or r.charName or "?", team_name(r.team),
            F.abbrev(r.damage), F.abbrev(r.healing), taken, r.kills, r.deaths, r.assists, r.medals or 0))
        S.color(W.detail, K.COLOR.text_dim)
    else
        local session = BGMeter.Session and BGMeter.Session.summary()
        set_text(W.detail, session or "click a row for detail  ·  click a column header to sort  ·  drag an edge to resize")
        S.color(W.detail, session and K.COLOR.gold or K.COLOR.text_dim)
    end
end

-- ── controller actions ──────────────────────────────────────────────────────

function W.export()
    local m = BGMeter.History.get(current_index)
    if BGMeter.UI.export then BGMeter.UI.export.show(m) end
end

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

local function apply_visibility()
    if not built then return end
    local want = user_visible and on_hud and not in_combat
    local was_hidden = W.win:IsHidden()
    W.win:SetHidden(not want)
    if want and was_hidden then
        W.win:SetAlpha(1)
        W.render(false)
    end
    if not want and settings_open then
        settings_open = false
        W.settings.window:SetHidden(true)
    end
    if not want then W._chart_hover_stop() end
end

function W.on_scene(onHud)
    on_hud = onHud and true or false
    apply_visibility()
end

function W.on_combat(_, inCombat)
    in_combat = inCombat and true or false
    apply_visibility()
end

function W.show_match(index)
    build()
    current_index = index or 1
    selected_row = nil
    settings_open = false
    W.settings.window:SetHidden(true)
    user_visible = true
    apply_visibility()
    if W.win:IsHidden() then return end
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
    user_visible = false
    W.win:SetHidden(true); W._persist_hidden(true)
    W._chart_hover_stop()
end

function W.toggle()
    build()
    if user_visible then W.hide() else W.show() end
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

local function safe_m(obj, method, ...)
    if not obj or type(obj[method]) ~= "function" then return nil end
    local ok, a = pcall(obj[method], obj, ...)
    if not ok then return nil end
    return a
end

function W.init()
    local zc = BGMeter.zenimax.constants
    if zc.EVENT_PLAYER_COMBAT_STATE then
        BGMeter.zenimax.events.register("BGMeterWinCombat", zc.EVENT_PLAYER_COMBAT_STATE, W.on_combat)
    end
    if SCENE_MANAGER then
        local function handler(_, newState)
            if newState == SCENE_SHOWN then W.on_scene(true)
            elseif newState == SCENE_HIDDEN then W.on_scene(false) end
        end
        for _, name in ipairs({ "hud", "hudui" }) do
            local sc = safe_m(SCENE_MANAGER, "GetScene", name)
            if sc and type(sc.RegisterCallback) == "function" then
                pcall(function() sc:RegisterCallback("StateChange", handler) end)
            end
        end
    end
    on_hud = (BGMeter.zenimax.scene and BGMeter.zenimax.scene.is_hud_scene()) and true or false
    BGMeter.Log.debug("window ready")
end

BGMeter.UI.window = W
