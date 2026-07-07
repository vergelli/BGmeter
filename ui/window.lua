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
    { key = "damage",  right = 230, w = 56, label = "DMG", shift = true },
    { key = "healing", right = 170, w = 50, label = "HEAL", shift = true },
    { key = "kills",   right = 122, w = 22, label = "K", shift = true },
    { key = "deaths",  right = 94,  w = 22, label = "D", shift = true },
    { key = "assists", right = 66,  w = 22, label = "A", shift = true },
    { key = "caps",    right = 66,  w = 34, label = "CAP", flag = true },
    { key = "score",   right = 10,  w = 50, label = "PTS"  },
}
local CAPS_SHIFT = 40
local caps_shown = false

local function col_right(col)
    if not col.flag and caps_shown and col.shift then return col.right + CAPS_SHIFT end
    return col.right
end

local function col_hidden(col)
    return (col.flag and not caps_shown) and true or false
end
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
    ["temple"]            = "esoui/art/loadingscreens/loadscreen_battleground_temple_01.dds",
    ["castle courtyard"]  = "esoui/art/loadingscreens/loadscreen_battleground_castle_courtyard_01.dds",
    ["city street"]       = "esoui/art/loadingscreens/loadscreen_battleground_city_streets_01.dds",
    ["sewer"]             = "esoui/art/loadingscreens/loadscreen_battleground_sewer_01.dds",
    ["desert"]            = "esoui/art/loadingscreens/loadscreen_battleground_alikr_desert_01.dds",
    ["alik"]              = "esoui/art/loadingscreens/loadscreen_battleground_alikr_desert_01.dds",
    ["coliseum"]          = "esoui/art/loadingscreens/loadscreen_battleground_arena_coliseum_01.dds",
    ["colosseum"]         = "esoui/art/loadingscreens/loadscreen_battleground_arena_coliseum_01.dds",
    ["forest"]            = "esoui/art/loadingscreens/loadscreen_battleground_bosmer_forest_01.dds",
    ["grove"]             = "esoui/art/loadingscreens/loadscreen_battleground_bosmer_forest_01.dds",
    ["ald carac"]         = "esoui/art/loadingscreens/loadscreen_battleground_ald_carac_01.dds",
    ["arcane university"] = "esoui/art/loadingscreens/loadscreen_battleground_arcaneuniversity_01.dds",
    ["deeping drome"]     = "esoui/art/loadingscreens/loadscreen_battleground_deepingdrome_01.dds",
    ["eld angavar"]       = "esoui/art/loadingscreens/loadscreen_battleground_eld_angavar_01.dds",
    ["foyada quarry"]     = "esoui/art/loadingscreens/loadscreen_battleground_foyadaquarry_01.dds",
    ["istirus outpost"]   = "esoui/art/loadingscreens/loadscreen_battleground_istirusoutpost_01.dds",
    ["mor khazgur"]       = "esoui/art/loadingscreens/loadscreen_battleground_morkhazgur_01.dds",
    ["ularra"]            = "esoui/art/loadingscreens/loadscreen_battleground_ularra_01.dds",
}

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

local function one_line(lbl)
    lbl:SetHeight(14)
    if TEXT_WRAP_MODE_ELLIPSIS and lbl.SetWrapMode then lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
end

local function make_clickable(control, fn)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then fn() end end)
end

W.tips = {}
function W.tip_dynamic(control)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function()
        local t = W.tips[control]
        BGMeter.Log.debug("tip enter: %s (text=%s)", tostring(control:GetName()), t and "yes" or "no")
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
        Anim.value(0, value, K.ANIM.count_ms, function(v) set_text(label, prefix .. F.commas(math.floor(v + 0.5))) end)
    else
        set_text(label, prefix .. F.commas(value))
    end
end

local function set_bar(bar, pct, color, width, animate)
    if anim_on(animate) then Anim.value(0, pct, K.ANIM.bar_ms, function(v) Bar.set(bar, v, color, width) end)
    else Bar.set(bar, pct, color, width) end
end

-- A short celebratory "pop": the control swells then settles. Used on personal
-- bests so a record visibly jumps when the window opens.
local function pop(control)
    if not control or not Prefs.get("animate") then return end
    Anim.start(K.ANIM.pop_ms, function(t)
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
        lbl:SetAnchor(TOPRIGHT, b.container, TOPRIGHT, -col_right(col), 0)
        lbl:SetDimensions(col.w, 16)
        lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        lbl:SetHidden(col_hidden(col))
        if col.key == "caps" then
            make_clickable(lbl, function() W.sort_by(W.flagcol_key or "caps") end)
            W.tip_dynamic(lbl)
        else
            make_clickable(lbl, function() W.sort_by(col.key) end)
        end
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

    b.chartBg = P.rect(b.chart, { 1, 1, 1, K.ALPHA.chart_bg })
    b.chartBg:SetAnchorFill(b.chart)

    b.chartTitle = P.label(b.chart, S.FONT.small, K.COLOR.text_dim)
    b.chartTitle:SetText("MATCH TIMELINE")
    b.chartTitle:SetAnchor(TOPLEFT, b.chart, TOPLEFT, 4, 2)
    W.tip_static(b.chartTitle,
        "Team score over time.\nGold skull = your kill  ·  red skull = your death  ·  team-color ticks = other kills\nGold band = bloodiest minute of the match")

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

    b.bloodiest = P.rect(b.chart, { 0.95, 0.80, 0.35, 0.07 })
    b.bloodiest:SetHidden(true)

    b.skull_pool = BGMeter.Plot.pool.new(
        function()
            local ic = P.icon(b.chart, "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds")
            ic:SetDimensions(14, 14)
            return ic
        end,
        function(ic) ic:SetHidden(true); ic:ClearAnchors() end)

    b.cursor = P.rect(b.chart, { 1, 1, 1, 0.30 })
    b.cursor:SetDimensions(1, L.chart_h - 4)
    b.cursor:SetHidden(true)

    b.chart:SetMouseEnabled(true)
    b.chart:SetHandler("OnMouseEnter", function() W._chart_hover_start() end)
    b.chart:SetHandler("OnMouseExit", function() W._chart_hover_stop() end)

    b.ribbon = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
    b.ribbon:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, 0)
    b.ribbon:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, 0)
    b.ribbon:SetHeight(0)
    b.ribbon:SetHidden(true)

    b.ribbonBg = P.rect(b.ribbon, { 1, 1, 1, K.ALPHA.chart_bg })
    b.ribbonBg:SetAnchorFill(b.ribbon)

    b.ribbonTitle = P.label(b.ribbon, S.FONT.small, K.COLOR.text_dim)
    b.ribbonTitle:SetText("FLAG CONTROL")
    b.ribbonTitle:SetAnchor(TOPLEFT, b.ribbon, TOPLEFT, 4, 2)
    W.tip_static(b.ribbonTitle,
        "Who held each flag over time (lane color = owning team).\nFlag pin = captured  ·  shield = attack defended\nHover any pin for the details")

    b.ribbon_pool = BGMeter.Plot.pool.new(
        function() return P.rect(b.ribbon, { 1, 1, 1, 1 }) end,
        function(r) r:SetHidden(true); r:ClearAnchors() end)

    b.ribbon_letters = {}
    b.lane_pins = {}

    b.pin_pool = BGMeter.Plot.pool.new(
        function() return P.icon(b.ribbon, "") end,
        function(ic) ic:SetHidden(true); ic:ClearAnchors() end)

    b.tick_hit_pool = BGMeter.Plot.pool.new(
        function()
            local h = BGMeter.zenimax.ui.create_control(nil, b.ribbon, CT_CONTROL)
            W.tip_dynamic(h)
            return h
        end,
        function(h) h:SetHidden(true); h:ClearAnchors(); W.tips[h] = nil end)

    b.ribbon:SetMouseEnabled(true)
    b.ribbon:SetHandler("OnMouseEnter", function() W._chart_hover_start() end)
    b.ribbon:SetHandler("OnMouseExit", function() W._chart_hover_stop() end)

    b.occ = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
    b.occ:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, 0)
    b.occ:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, 0)
    b.occ:SetHeight(0)
    b.occ:SetHidden(true)

    b.occBg = P.rect(b.occ, { 1, 1, 1, K.ALPHA.chart_bg })
    b.occBg:SetAnchorFill(b.occ)

    b.occTitle = P.label(b.occ, S.FONT.small, K.COLOR.text_dim)
    b.occTitle:SetText("FLAG OCCUPATION")
    b.occTitle:SetAnchor(TOPLEFT, b.occ, TOPLEFT, 4, 2)
    W.tip_static(b.occTitle,
        "Share of total flag-hold time per team.\nBelow: captures, successful defenses, average hold per team, first capture")

    b.occLegend = P.label(b.occ, S.FONT.small, K.COLOR.text)
    b.occLegend:SetAnchor(TOPLEFT, b.occTitle, TOPRIGHT, 10, 0)
    b.occLegend:SetAnchor(TOPRIGHT, b.occ, TOPRIGHT, -4, 2)
    b.occLegend:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    one_line(b.occLegend)

    b.occStats = P.label(b.occ, S.FONT.small, K.COLOR.text_dim)
    b.occStats:SetAnchor(TOPLEFT, b.occ, TOPLEFT, 4, 32)
    b.occStats:SetAnchor(TOPRIGHT, b.occ, TOPRIGHT, -4, 32)
    one_line(b.occStats)

    b.occ_pool = BGMeter.Plot.pool.new(
        function() return P.rect(b.occ, { 1, 1, 1, 1 }) end,
        function(r) r:SetHidden(true); r:ClearAnchors() end)

    b.mom = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
    b.mom:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, 0)
    b.mom:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, 0)
    b.mom:SetHeight(0)
    b.mom:SetHidden(true)

    b.momBg = P.rect(b.mom, { 1, 1, 1, K.ALPHA.chart_bg })
    b.momBg:SetAnchorFill(b.mom)

    b.momTitle = P.label(b.mom, S.FONT.small, K.COLOR.text_dim)
    b.momTitle:SetText("MOMENTUM")
    b.momTitle:SetAnchor(TOPLEFT, b.mom, TOPLEFT, 4, 2)
    W.tip_static(b.momTitle,
        "Who was leading, and by how much.\nColor = leading team  ·  brighter = bigger lead")

    b.momStats = P.label(b.mom, S.FONT.small, K.COLOR.text_dim)
    b.momStats:SetAnchor(TOPLEFT, b.mom, TOPLEFT, 4, 30)
    b.momStats:SetAnchor(TOPRIGHT, b.mom, TOPRIGHT, -4, 30)
    one_line(b.momStats)

    b.mom_pool = BGMeter.Plot.pool.new(
        function() return P.rect(b.mom, { 1, 1, 1, 1 }) end,
        function(r) r:SetHidden(true); r:ClearAnchors() end)

    b.mom:SetMouseEnabled(true)
    b.mom:SetHandler("OnMouseEnter", function() W._chart_hover_start() end)
    b.mom:SetHandler("OnMouseExit", function() W._chart_hover_stop() end)

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
        lbl:SetAnchor(RIGHT, row.container, RIGHT, -col_right(col), 0)
        lbl:SetDimensions(col.w, L.row_h)
        lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        lbl:SetHidden(col_hidden(col))
        row.cells[col.key] = lbl
    end
    row.capsLayout = false

    row.container:SetHandler("OnMouseEnter", function()
        if W._last_row_log ~= row then
            W._last_row_log = row
            BGMeter.Log.debug("row enter: %s", tostring(row.prow and (row.prow.displayName or row.prow.charName) or "?"))
        end
        P.set_rect_color(row.highlight, { 1, 1, 1, K.ALPHA.row_hover })
    end)
    row.container:SetHandler("OnMouseExit", function() P.set_rect_color(row.highlight, row.baseHL or { 0, 0, 0, 0 }) end)
    return row
end

-- ── build: haul panel ───────────────────────────────────────────────────────

local MEDAL_PERROW, MEDAL_STEP, MEDAL_CAP = 7, 24, 14

local function hit_proxy(target)
    local h = BGMeter.zenimax.ui.create_control(nil, target:GetParent(), CT_CONTROL)
    h:SetAnchorFill(target)
    return h
end

local medal_card = nil

local function build_medal_card()
    if medal_card then return medal_card end
    local root = BGMeter.zenimax.ui.create_control(nil, W.win, CT_CONTROL)
    root:SetDimensions(280, 96)
    root:SetDrawLevel(30)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)

    local bg = P.rect(root, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.98 })
    bg:SetAnchorFill(root)
    P.frame(root):SetAnchorFill(root)

    local strip = P.rect(root, K.COLOR.gold)
    strip:SetAnchor(TOPLEFT, root, TOPLEFT, 4, 4)
    strip:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 4, -4)
    strip:SetWidth(2)

    local icon = P.icon(root)
    icon:SetDimensions(40, 40)
    icon:SetAnchor(TOPLEFT, root, TOPLEFT, 14, 12)

    local name = P.label(root, S.FONT.header, K.COLOR.text)
    name:SetAnchor(TOPLEFT, root, TOPLEFT, 64, 12)
    name:SetDimensions(202, 20)

    local count = P.label(root, S.FONT.small, K.COLOR.gold)
    count:SetAnchor(TOPLEFT, root, TOPLEFT, 64, 34)
    count:SetDimensions(202, 14)

    local cond = P.label(root, S.FONT.small, K.COLOR.text_dim)
    cond:SetAnchor(TOPLEFT, root, TOPLEFT, 14, 60)
    cond:SetWidth(252)

    local reward = P.label(root, S.FONT.small, K.COLOR.gold)
    reward:SetDimensions(252, 14)

    medal_card = { root = root, icon = icon, name = name, count = count, cond = cond, reward = reward }
    return medal_card
end

local function hide_medal_card()
    if medal_card then medal_card.root:SetHidden(true) end
end

local function show_medal_card(mi)
    local id = mi.bgmMedalId
    local n = mi.bgmMedalCount or 1
    BGMeter.Log.debug("medal hover: id=%s x%d", tostring(id), n)
    local info = id and Icons.medal_info(id) or nil
    if not info then return end
    local c = build_medal_card()

    c.icon:SetTexture(info.icon)
    set_text(c.name, info.name)
    set_text(c.count, (n > 1) and ("earned x" .. n) or "earned this match")

    local ch = 0
    if info.condition and info.condition ~= "" then
        set_text(c.cond, info.condition)
        ch = math.max(14, c.cond:GetTextHeight() or 14)
    else
        set_text(c.cond, "")
    end
    c.cond:SetHeight(ch)

    local rtext = (info.reward and info.reward > 0)
        and string.format("+%s score%s", F.commas(info.reward), n > 1 and " each" or "") or ""
    set_text(c.reward, rtext)
    c.reward:ClearAnchors()
    c.reward:SetAnchor(TOPLEFT, c.cond, BOTTOMLEFT, 0, 4)

    c.root:SetHeight(math.max(60 + ch + ((rtext ~= "") and 22 or 6), 64))
    c.root:ClearAnchors()
    c.root:SetAnchor(TOPRIGHT, mi, TOPLEFT, -10, -6)
    c.root:SetHidden(false)
end

local function build_haul(win)
    local p = {}
    local PAD = 16
    local INNER = L.haul_w - 2 * PAD

    p.container = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    p.container:SetAnchor(TOPRIGHT, win, TOPRIGHT, -L.margin, L.header_h)
    p.container:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -L.margin, -L.footer_h)
    p.container:SetWidth(L.haul_w)

    p.bd = P.backdrop(p.container)
    p.bd:SetAnchorFill(p.container)
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

    W.tip_static(hit_proxy(p.ap.icon), "Alliance Points earned this match")
    W.tip_static(hit_proxy(p.xp.icon), "Experience earned this match")
    W.tip_static(hit_proxy(p.cp.icon), "Champion Points earned this match")
    p.vetIconHit = hit_proxy(p.vetIcon)
    W.tip_dynamic(p.vetIconHit)
    W.tip_dynamic(p.standRank)
    p.medalHits = {}
    for i = 1, #p.medalIcons do
        local mi = p.medalIcons[i]
        local hit = hit_proxy(mi)
        hit:SetMouseEnabled(true)
        hit:SetHidden(true)
        hit:SetHandler("OnMouseEnter", function() show_medal_card(mi) end)
        hit:SetHandler("OnMouseExit", hide_medal_card)
        p.medalHits[i] = hit
    end
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
    W.bgMap:SetColor(1, 1, 1, K.ALPHA.map_art)
    W.bgMap:SetHidden(true)

    W.bgArtL = P.icon(win, SCOREBG_L)
    W.bgArtL:SetAnchor(TOPLEFT, win, TOPLEFT, L.margin - 6, L.header_h - 4)
    W.bgArtL:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(L.haul_w + L.gap + L.margin - 6), -10)
    W.bgArtL:SetColor(1, 1, 1, K.ALPHA.score_art)

    W.bgArtR = P.icon(win, SCOREBG_R)
    W.bgArtR:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(L.margin - 6), L.header_h - 4)
    W.bgArtR:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(L.margin - 6), -10)
    W.bgArtR:SetWidth(L.haul_w + 12)
    W.bgArtR:SetColor(1, 1, 1, K.ALPHA.score_art)

    W.footerBd = P.rect(win, { K.COLOR.panel[1], K.COLOR.panel[2], K.COLOR.panel[3], K.ALPHA.footer_band })
    W.footerBd:SetAnchor(TOPLEFT, win, BOTTOMLEFT, 8, -(L.footer_h - 4))
    W.footerBd:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -8, -8)

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
    local lower = name:lower():gsub("%^.*$", "")
    for key, path in pairs(MAP_ART) do
        if lower:find(key, 1, true) then add(path) end
    end
    local words = {}
    for w in lower:gmatch("[a-z]+") do words[#words + 1] = w end
    local function guess(slug)
        add(string.format("esoui/art/loadingscreens/loadscreen_battleground_%s_01.dds", slug))
    end
    for k = #words, 1, -1 do
        guess(table.concat(words, "_", 1, k))
        guess(table.concat(words, "", 1, k))
        guess(table.concat(words, "_", 1, k) .. "s")
    end
    return out
end

local MAP_ART_CHECKS = 3
local MAP_ART_CHECK_MS = 350

local function apply_map_art(m)
    local art = W.bgMap
    if not art then return end
    local name = (m and m.name) or ""
    if name == "" then art:SetHidden(true); return end
    local cands = map_art_candidates(name)
    if #cands == 0 then art:SetHidden(true); return end

    W.map_token = (W.map_token or 0) + 1
    local token = W.map_token
    local idx, tries = 0, 0
    local check
    local function try_next()
        if token ~= W.map_token then return end
        idx = idx + 1
        tries = 0
        if idx > #cands then
            art:SetHidden(true)
            BGMeter.Log.debug("map art: no candidate loaded for '%s' (%d tried)", name, #cands)
            return
        end
        art:SetTexture(cands[idx])
        art:SetHidden(false)
        if type(zo_callLater) ~= "function" then return end
        zo_callLater(check, MAP_ART_CHECK_MS)
    end
    check = function()
        if token ~= W.map_token then return end
        local ok, loaded = pcall(function() return art:IsTextureLoaded() end)
        if ok and loaded == false then
            tries = tries + 1
            if tries < MAP_ART_CHECKS then
                zo_callLater(check, MAP_ART_CHECK_MS)
            else
                try_next()
            end
        else
            BGMeter.Log.debug("map art resolved: %s", cands[idx])
        end
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
            if glowCol then glow:SetColor(glowCol[1], glowCol[2], glowCol[3], K.ALPHA.banner_glow); glow:SetHidden(false)
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

local function apply_dynamic_min_width(m)
    if not W.measure then return end
    local maxw = 0
    for _, prow in ipairs(m.battle) do
        W.measure:SetText(prow.displayName or prow.charName or "?")
        local tw = W.measure:GetTextWidth() or 0
        if tw > maxw then maxw = tw end
    end
    if maxw <= 0 then return end
    local needed = math.ceil(maxw) + 26 + NAME_X + NAME_RIGHT + (caps_shown and CAPS_SHIFT or 0) + 2 * L.margin + L.haul_w + L.gap
    local dyn = math.max(L.min_w, math.min(needed, L.dyn_min_cap))

    local extra
    local nflags = m.objectives and m.objectives.list and #m.objectives.list or 0
    if nflags > 0 then
        local lanes = math.min(4, nflags)
        extra = (L.occ_h + 2) + (L.ribbon_top + lanes * (L.lane_h + L.lane_gap) + 3 + 2) + (28 + 2)
    else
        extra = 46 + 2
    end
    local needed_h = L.header_h + 24 + #m.battle * L.row_h + L.chart_h + extra + 8 + L.footer_h + 12
    local dyn_h = math.max(L.min_h, math.min(needed_h, L.max_h))

    if dyn ~= W.dyn_min or dyn_h ~= W.dyn_min_h then
        W.dyn_min = dyn
        W.dyn_min_h = dyn_h
        W.win:SetDimensionConstraints(dyn, dyn_h, L.max_w, L.max_h)
    end
    local sv = BGMeter.zenimax.savedvars.get()
    if W.cur_w < dyn then
        W.cur_w = dyn
        W.win:SetWidth(dyn)
        if sv then sv.window = sv.window or {}; sv.window.w = dyn end
    end
    if W.cur_h < dyn_h then
        W.cur_h = dyn_h
        W.win:SetHeight(dyn_h)
        if sv then sv.window = sv.window or {}; sv.window.h = dyn_h end
    end
end

local function caps_relevant(m)
    if m.objectives and m.objectives.list and #m.objectives.list > 0 then return true end
    for _, r in ipairs(m.battle) do
        if (r.caps or 0) > 0 or (r.carried or 0) > 0 then return true end
    end
    return false
end

local function flag_col_spec(m)
    local gt = C.GAME_TYPE_LABEL and C.GAME_TYPE_LABEL[m.gameType] or nil
    if gt == "murderball" then
        return "carried", "HOLD",
            "BALL POSSESSION\nTime this player spent holding a chaosball\n(the ball scores for their team while held). Click to sort."
    end
    return "caps", "CAP",
        "CAPTURES\nObjectives this player captured for their team\n(flags, capture points, relics). Click to sort."
end

local function name_right()
    return NAME_RIGHT + (caps_shown and CAPS_SHIFT or 0)
end

local function layout_headers(b)
    for _, col in ipairs(COLS) do
        local lbl = b.headers[col.key]
        if lbl then
            lbl:ClearAnchors()
            lbl:SetAnchor(TOPRIGHT, b.container, TOPRIGHT, -col_right(col), 0)
            lbl:SetHidden(col_hidden(col))
        end
    end
end

local function layout_row_cells(row)
    for _, col in ipairs(COLS) do
        local cell = row.cells[col.key]
        cell:ClearAnchors()
        cell:SetAnchor(RIGHT, row.container, RIGHT, -col_right(col), 0)
        cell:SetHidden(col_hidden(col))
    end
    row.name:ClearAnchors()
    row.name:SetAnchor(LEFT, row.container, LEFT, NAME_X, 0)
    row.name:SetAnchor(RIGHT, row.container, RIGHT, -name_right(), 0)
    row.capsLayout = caps_shown
end

local function render_battle(m, animate)
    local b = W.battle
    b.row_pool:release_all()
    local want_caps = caps_relevant(m)
    if want_caps ~= caps_shown then
        caps_shown = want_caps
        layout_headers(b)
    end
    local fkey, flabel, ftip = flag_col_spec(m)
    W.flagcol_key = fkey
    if b.headers.caps then W.tips[b.headers.caps] = ftip end
    apply_dynamic_min_width(m)

    local key = Prefs.get("sort_key") or "damage"
    if (key == "caps" or key == "carried") and not caps_shown then key = "damage" end
    if key == "caps" or key == "carried" then key = fkey end
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
        if ckey == "caps" then base = flabel end
        if (ckey == "caps" and key == fkey) or ckey == key then
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
        if row.capsLayout ~= caps_shown then layout_row_cells(row) end
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
            P.set_rect_color(row.teamStrip, { tc[1], tc[2], tc[3], K.ALPHA.team_strip })
        else
            P.set_rect_color(row.teamStrip, { 0, 0, 0, 0 })
        end

        for _, col in ipairs(COLS) do
            local ck = (col.key == "caps") and fkey or col.key
            local cell, v = row.cells[col.key], prow[ck] or 0
            local txt
            if col.key == "damage" or col.key == "healing" or col.key == "score" then
                txt = F.abbrev(v)
            elseif ck == "carried" then
                txt = (v > 0) and F.duration(v * 1000) or "0"
            else
                txt = tostring(v)
            end
            set_text(cell, txt)
            if awards.leaders[ck] == prow and v > 0 then S.color(cell, K.COLOR.gold)
            elseif v == 0 then S.color(cell, K.COLOR.text_dim)
            else S.color(cell, K.COLOR.text) end
        end

        local pct = (maxVal > 0) and ((prow[barKey] or 0) / maxVal) or 0
        local bc = prow.isLocal and K.COLOR.you or barBase
        set_bar(row.bar, pct, { bc[1], bc[2], bc[3], K.ALPHA.bar_fill }, listW - BAR_X - BAR_RIGHT, animate)

        local hl = { 0, 0, 0, 0 }
        if awards.mvp == prow then hl = { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], K.ALPHA.row_mvp } end
        if prow.isLocal then hl = { K.COLOR.you[1], K.COLOR.you[2], K.COLOR.you[3], K.ALPHA.row_you } end
        if selected_row == prow then hl = { 1, 1, 1, K.ALPHA.row_selected } end
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

local function hexc(c)
    return string.format("%02x%02x%02x",
        math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function ribbon_letter(b, i)
    local lbl = b.ribbon_letters[i]
    if not lbl then
        lbl = P.label(b.ribbon, S.FONT.small, K.COLOR.text)
        b.ribbon_letters[i] = lbl
    end
    return lbl
end

local function neutral_color()
    return { 0.55, 0.55, 0.60 }
end

local function flag_pin(gt, letter, team)
    local key = S.team_art_key(team)
    local mobile = (gt == "crazy_king" or gt == "king_of_the_hill")
    if letter and letter:match("^[ABCD]$") then
        if mobile then
            return string.format("EsoUI/Art/MapPins/battlegrounds_mobileCapturePoint_pin_%s_%s.dds", key, letter)
        end
        return string.format("EsoUI/Art/MapPins/battlegrounds_multiCapturePoint_%s_pin_%s.dds", letter, key)
    end
    if mobile then
        return string.format("EsoUI/Art/MapPins/battlegrounds_mobileCapturePoint_pin_%s.dds", key)
    end
    return string.format("EsoUI/Art/MapPins/battlegrounds_capturePoint_pin_%s.dds", key)
end

local function lane_pin(b, i)
    local ic = b.lane_pins[i]
    if not ic then
        ic = P.icon(b.ribbon, "")
        ic:SetDimensions(28, 28)
        b.lane_pins[i] = ic
    end
    return ic
end

local function render_occupation(b, occ, neutralPct, stats, w)
    b.occ:SetHeight(L.occ_h)
    b.occ:SetHidden(false)
    local bw = w - 6
    local x = 0
    local parts = {}
    for _, e in ipairs(occ) do
        local tc = S.team_color(e.team)
        local seg_w = math.floor(e.pct * bw + 0.5)
        if seg_w > 1 then
            local r = b.occ_pool:acquire()
            r:SetAnchor(TOPLEFT, b.occ, TOPLEFT, x, 18)
            r:SetDimensions(seg_w, 10)
            P.set_rect_color(r, { tc[1], tc[2], tc[3], 0.80 })
            r:SetHidden(false)
            x = x + seg_w
        end
        parts[#parts + 1] = string.format("|c%s%s %d%%|r",
            hexc(tc), team_name(e.team), math.floor(e.pct * 100 + 0.5))
    end
    if x < bw then
        local r = b.occ_pool:acquire()
        r:SetAnchor(TOPLEFT, b.occ, TOPLEFT, x, 18)
        r:SetDimensions(bw - x, 10)
        local nc = neutral_color()
        P.set_rect_color(r, { nc[1], nc[2], nc[3], K.ALPHA.ribbon_neutral })
        r:SetHidden(false)
        if neutralPct and neutralPct >= 0.005 then
            parts[#parts + 1] = string.format("|c8c8c95neutral %d%%|r",
                math.floor(neutralPct * 100 + 0.5))
        end
    end
    b.occLegend:SetText(table.concat(parts, "  ·  "))

    local sp = {}
    if stats then
        for _, e in ipairs(stats.per) do
            local tc = S.team_color(e.team)
            sp[#sp + 1] = string.format("|c%s%s  %d caps · %d defs · avg hold %s|r",
                hexc(tc), team_name(e.team), e.caps, e.defs, F.duration(e.avgHoldMs))
        end
        if stats.first then
            local tc = S.team_color(stats.first.team)
            sp[#sp + 1] = string.format("|c%sfirst %s @ %s|r",
                hexc(tc), tostring(stats.first.letter), F.duration(stats.first.t))
        end
    end
    b.occStats:SetText(table.concat(sp, "    "))
end

local function render_ribbon(b, lanes, ribbon_h, tspan, w, y_off, gt)
    b.ribbon:ClearAnchors()
    b.ribbon:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -y_off)
    b.ribbon:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -y_off)
    b.ribbon:SetHeight(ribbon_h)
    b.ribbon:SetHidden(false)
    local function rx(t) return math.floor((t / tspan) * (w - 6) + 0.5) end
    for li, lane in ipairs(lanes) do
        local y = L.ribbon_top + (li - 1) * (L.lane_h + L.lane_gap)
        for _, seg in ipairs(lane.segs) do
            local x0, x1 = rx(seg.t0), rx(seg.t1)
            if x1 > x0 then
                local r = b.ribbon_pool:acquire()
                r:SetAnchor(TOPLEFT, b.ribbon, TOPLEFT, x0, y)
                r:SetDimensions(x1 - x0, L.lane_h)
                if seg.own and seg.own ~= 0 then
                    local tc = S.team_color(seg.own)
                    P.set_rect_color(r, { tc[1], tc[2], tc[3], K.ALPHA.ribbon_fill })
                else
                    local nc = neutral_color()
                    P.set_rect_color(r, { nc[1], nc[2], nc[3], K.ALPHA.ribbon_neutral })
                end
                r:SetHidden(false)
            end
        end
        for _, tick in ipairs(lane.ticks) do
            local ic = b.pin_pool:acquire()
            local tip
            if tick.kind == "def" then
                ic:SetTexture("EsoUI/Art/WorldMap/map_AVA_tabIcon_resourceDefense_up.dds")
                ic:SetDimensions(L.pin_size - 6, L.pin_size - 6)
                local tc = S.team_color(tick.own)
                ic:SetColor(tc[1], tc[2], tc[3], 1)
                tip = string.format("%s defended %s @ %s",
                    team_name(tick.own), lane.letter, F.duration(tick.t))
            else
                ic:SetTexture(flag_pin(gt, lane.letter, tick.own))
                ic:SetDimensions(L.pin_size, L.pin_size)
                ic:SetColor(1, 1, 1, 1)
                tip = string.format("%s captured %s @ %s",
                    team_name(tick.own), lane.letter, F.duration(tick.t))
            end
            local half = math.floor(L.pin_size / 2)
            local tx = math.max(half, math.min(rx(tick.t), w - 6 - half))
            ic:SetAnchor(CENTER, b.ribbon, TOPLEFT, tx, y + math.floor(L.lane_h / 2))
            ic:SetHidden(false)
            local hit = b.tick_hit_pool:acquire()
            hit:SetAnchorFill(ic)
            hit:SetHidden(false)
            W.tips[hit] = tip
        end
        local is_letter = lane.letter and lane.letter:match("^[ABCD]$") ~= nil
        local lbl = ribbon_letter(b, li)
        local pin = lane_pin(b, li)
        if is_letter then
            pin:SetTexture(flag_pin(gt, lane.letter, 0))
            pin:ClearAnchors()
            pin:SetAnchor(LEFT, b.ribbon, TOPLEFT, 2, y + math.floor(L.lane_h / 2))
            pin:SetHidden(false)
            lbl:SetHidden(true)
        else
            lbl:SetText(lane.letter)
            lbl:ClearAnchors()
            lbl:SetAnchor(TOPRIGHT, b.ribbon, TOPLEFT, -4, y - 2)
            lbl:SetHidden(false)
            pin:SetHidden(true)
        end
    end
    for i = #lanes + 1, #b.ribbon_letters do
        b.ribbon_letters[i]:SetHidden(true)
    end
    for i = #lanes + 1, #b.lane_pins do
        b.lane_pins[i]:SetHidden(true)
    end
end

local function render_momentum(b, m, tl, n, tspan, w, mom_h, mom_off, lead, tdm_line)
    b.mom:ClearAnchors()
    b.mom:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -mom_off)
    b.mom:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -mom_off)
    b.mom:SetHeight(mom_h)
    b.mom:SetHidden(false)

    local series = { tl.s1, tl.s2, tl.s3 }
    local teams = tl.teams or {}
    local maxLead = math.max(1, (lead and lead.maxLead) or 1)
    local function mx(t) return math.floor((t / tspan) * (w - 6) + 0.5) end
    for i = 2, n do
        local best, second, bestTeam = 0, 0, nil
        for s = 1, 3 do
            local team = teams[s]
            local v = (series[s] and series[s][i]) or 0
            if team and v > best then
                second = best
                best, bestTeam = v, team
            elseif team and v > second then
                second = v
            end
        end
        local margin = best - second
        local x0, x1 = mx(tl.t[i - 1] or 0), mx(tl.t[i] or 0)
        if x1 > x0 then
            local r = b.mom_pool:acquire()
            r:SetAnchor(TOPLEFT, b.mom, TOPLEFT, x0, 15)
            r:SetDimensions(x1 - x0, 10)
            if bestTeam and margin > 0 then
                local tc = S.team_color(bestTeam)
                local a = 0.15 + 0.60 * math.min(1, margin / maxLead)
                P.set_rect_color(r, { tc[1], tc[2], tc[3], a })
            else
                local nc = neutral_color()
                P.set_rect_color(r, { nc[1], nc[2], nc[3], 0.10 })
            end
            r:SetHidden(false)
        end
    end

    if not tdm_line then
        b.momStats:SetText("")
        return
    end
    local Match = BGMeter.Match
    local sp = {}
    if lead then
        local tc = S.team_color(lead.maxTeam)
        sp[#sp + 1] = string.format("|c%smax lead %s +%d|r", hexc(tc), team_name(lead.maxTeam), lead.maxLead)
        sp[#sp + 1] = string.format("lead changes %d", lead.changes)
    end
    local bm = Match.bloodiest_minute(m.killfeed)
    if bm then
        sp[#sp + 1] = string.format("|c%sbloodiest %s-%s (%d kills)|r",
            hexc(K.COLOR.gold), F.duration(bm.t0), F.duration(bm.t1), bm.count)
    end
    local fb = Match.first_blood(m.killfeed)
    if fb then
        local tc = S.team_color(fb.kt)
        sp[#sp + 1] = string.format("|c%sfirst blood %s|r @ %s", hexc(tc), tostring(fb.kn), F.duration(fb.t))
    end
    local runs = Match.kill_streaks(m.killfeed)
    if runs then
        local best = runs[1]
        for _, r in ipairs(runs) do
            if r.n > best.n then best = r end
        end
        local tc = S.team_color(best.team)
        sp[#sp + 1] = string.format("best streak |c%s%s x%d|r", hexc(tc), tostring(best.name), best.n)
    end
    b.momStats:SetText(table.concat(sp, "    "))
end

local function render_timeline(m)
    local b = W.battle
    b.dot_pool:release_all()
    if b.line_pool then b.line_pool:release_all() end
    b.skull_pool:release_all()
    b.ribbon_pool:release_all()
    b.pin_pool:release_all()
    b.tick_hit_pool:release_all()
    for _, lbl in ipairs(b.ribbon_letters) do lbl:SetHidden(true) end
    for _, ic in ipairs(b.lane_pins) do ic:SetHidden(true) end
    b.ribbon:SetHidden(true)
    b.occ_pool:release_all()
    b.occ:SetHidden(true)
    b.mom_pool:release_all()
    b.mom:SetHidden(true)
    b.bloodiest:SetHidden(true)
    chart_state = nil
    if not timeline_ok(m) then
        b.chart:SetHidden(true)
        return
    end

    local tl = m.timeline
    local n = #tl.t
    local tspan = math.max(1, tl.t[n] or 1)
    local gt = C.GAME_TYPE_LABEL and C.GAME_TYPE_LABEL[m.gameType] or nil

    local lanes = BGMeter.Match.flag_lanes(m, tspan)
    local occ, neutralPct, fstats
    if lanes then
        occ, neutralPct = BGMeter.Match.flag_occupation(lanes, tspan)
        fstats = BGMeter.Match.flag_stats(lanes)
    end
    if occ and #occ == 0 then occ = nil end
    local ribbon_h = lanes and (L.ribbon_top + #lanes * (L.lane_h + L.lane_gap) + 3) or 0
    local occ_h = occ and L.occ_h or 0
    local lead = BGMeter.Match.lead_stats(tl)
    local tdm_line = (not lanes) and lead ~= nil
    local mom_h = lead and (tdm_line and 46 or 28) or 0

    local rows_h = 24 + #m.battle * L.row_h
    local cont_h = b.container:GetHeight()
    local function fits(extra) return cont_h - rows_h >= L.chart_h + extra + 8 end
    if lanes and mom_h > 0 and not fits(mom_h + ribbon_h + occ_h) then
        mom_h, tdm_line = 0, false
    end
    if occ_h > 0 and not fits(mom_h + ribbon_h + occ_h) then
        occ, occ_h = nil, 0
    end
    if ribbon_h > 0 and not fits(mom_h + ribbon_h + occ_h) then
        lanes, ribbon_h = nil, 0
    end
    if mom_h > 0 and tdm_line and not fits(mom_h + ribbon_h + occ_h) then
        mom_h, tdm_line = 28, false
    end
    if mom_h > 0 and not fits(mom_h + ribbon_h + occ_h) then
        mom_h, tdm_line = 0, false
    end
    if not fits(0) then
        b.chart:SetHidden(true)
        return
    end
    local rib_off = (occ_h > 0) and (occ_h + 2) or 0
    local mom_off = rib_off + ((ribbon_h > 0) and (ribbon_h + 2) or 0)
    local chart_off = mom_off + ((mom_h > 0) and (mom_h + 2) or 0)
    b.chart:SetHidden(false)
    b.chart:ClearAnchors()
    b.chart:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, -chart_off)
    b.chart:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, -chart_off)
    b.chart:SetHeight(L.chart_h)

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

    local bm = BGMeter.Match.bloodiest_minute(m.killfeed)
    if bm then
        local x0 = math.floor((math.min(bm.t0, tspan) / tspan) * (w - 6) + 0.5)
        local x1 = math.floor((math.min(bm.t1, tspan) / tspan) * (w - 6) + 0.5)
        b.bloodiest:ClearAnchors()
        b.bloodiest:SetAnchor(TOPLEFT, b.chart, TOPLEFT, x0, 2)
        b.bloodiest:SetDimensions(math.max(2, x1 - x0), h - 4)
        b.bloodiest:SetHidden(false)
    end

    if m.killfeed then
        for _, k in ipairs(m.killfeed) do
            local x = math.floor((math.min(k.t or 0, tspan) / tspan) * (w - 6) + 0.5)
            if k.kind == "kill" or k.kind == "death" then
                local ic = b.skull_pool:acquire()
                local c = (k.kind == "kill") and K.COLOR.gold or K.COLOR.accent
                ic:SetColor(c[1], c[2], c[3], 1)
                ic:SetAnchor(BOTTOM, b.chart, BOTTOMLEFT, x, 5)
                ic:SetHidden(false)
            elseif k.kt then
                local tc = S.team_color(k.kt)
                local mark = b.dot_pool:acquire()
                mark:ClearAnchors()
                mark:SetAnchor(BOTTOMLEFT, b.chart, BOTTOMLEFT, x, -2)
                mark:SetDimensions(2, 5)
                P.set_rect_color(mark, { tc[1], tc[2], tc[3], 0.65 })
                mark:SetHidden(false)
            end
        end
    end

    if lanes then
        render_ribbon(b, lanes, ribbon_h, tspan, w, rib_off, gt)
    end
    if occ then
        render_occupation(b, occ, neutralPct, fstats, w)
    end
    if mom_h > 0 then
        render_momentum(b, m, tl, n, tspan, w, mom_h, mom_off, lead, tdm_line)
    end

    chart_state = { tl = tl, n = n, w = w, smax = smax, lanes = lanes, kf = m.killfeed }
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
    if st.lanes then
        for _, lane in ipairs(st.lanes) do
            local own = 0
            for _, seg in ipairs(lane.segs) do
                if want_t >= seg.t0 and want_t < seg.t1 then
                    own = seg.own
                    break
                end
            end
            if own ~= 0 then
                local tc = S.team_color(own)
                parts[#parts + 1] = string.format("|c%sflag %s  %s|r",
                    hexc(tc), lane.letter, team_name(own))
            else
                parts[#parts + 1] = string.format("|c8c8c95flag %s  neutral|r", lane.letter)
            end
        end
    end

    if st.kf then
        local shown, extra = 0, 0
        for _, k in ipairs(st.kf) do
            if k.t and math.abs(k.t - want_t) <= 8000 then
                if shown >= 4 then
                    extra = extra + 1
                elseif k.kn and k.dn then
                    local tc = S.team_color(k.kt)
                    parts[#parts + 1] = string.format("|c%s%s|r killed %s  @ %s",
                        hexc(tc), k.kn, k.dn, F.duration(k.t))
                    shown = shown + 1
                elseif k.kind then
                    parts[#parts + 1] = string.format("%s @ %s",
                        k.kind == "kill" and "your kill" or "your death", F.duration(k.t))
                    shown = shown + 1
                end
            end
        end
        if extra > 0 then
            parts[#parts + 1] = string.format("+%d more kills here", extra)
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

local function ensure_duel_icons(b)
    if b.nemesisIcon then return end
    b.nemesisIcon = P.icon(b.container, "EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds")
    b.nemesisIcon:SetDimensions(18, 18)
    b.nemesisIcon:SetAnchor(LEFT, b.headers.name, RIGHT, 12, -1)
    S.color(b.nemesisIcon, K.COLOR.accent)
    b.nemesisIcon:SetHidden(true)
    b.nemesisHit = hit_proxy(b.nemesisIcon)
    W.tip_static(b.nemesisHit, "")

    b.preyIcon = P.icon(b.container, "EsoUI/Art/HUD/HUD_Countdown_Badge_Dueling.dds")
    b.preyIcon:SetDimensions(18, 18)
    b.preyIcon:SetAnchor(LEFT, b.nemesisIcon, RIGHT, 8, 0)
    S.color(b.preyIcon, K.COLOR.gold)
    b.preyIcon:SetHidden(true)
    b.preyHit = hit_proxy(b.preyIcon)
    W.tip_static(b.preyHit, "")
end

local function render_duels(m)
    local b = W.battle
    ensure_duel_icons(b)
    local d = m and BGMeter.Match.duels(m)
    if d and d.nemesis then
        b.nemesisIcon:SetHidden(false)
        b.nemesisHit:SetHidden(false)
        W.tips[b.nemesisHit] = string.format("Nemesis: %s\nKilled you %d time%s this match",
            d.nemesis.name, d.nemesis.count, d.nemesis.count == 1 and "" or "s")
    else
        b.nemesisIcon:SetHidden(true)
        b.nemesisHit:SetHidden(true)
        W.tips[b.nemesisHit] = nil
    end
    if d and d.prey then
        b.preyIcon:SetHidden(false)
        b.preyHit:SetHidden(false)
        W.tips[b.preyHit] = string.format("Prey: %s\nYou killed them %d time%s this match",
            d.prey.name, d.prey.count, d.prey.count == 1 and "" or "s")
    else
        b.preyIcon:SetHidden(true)
        b.preyHit:SetHidden(true)
        W.tips[b.preyHit] = nil
    end
end

local function render_haul(m, animate)
    local p, h = W.haul, m.haul
    local rec = m.records or {}
    local vet = h.vetEnd or h.vetStart
    local vetControls = { p.vetIcon, p.vetIconHit, p.vetTitle, p.vetTier, p.track.container, p.vetDelta, p.season }

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
        W.tips[p.vetIconHit] = string.format("%s%s\n%s%s",
            vet.rankTitle or ("Veteran Rank " .. tostring(vet.rank)),
            vet.tier and ("  ·  Tier " .. vet.tier) or "",
            vet.seasonName or "Veterancy season", endsTxt)
    else
        hide_all(vetControls, false)
        p.vetIcon:SetHidden(true)
        set_text(p.vetTitle, "Veterancy"); set_text(p.vetTier, "(no season data)")
        Bar.set_hidden(p.track, true); set_text(p.vetDelta, ""); set_text(p.season, "")
        W.tips[p.vetIconHit] = nil
    end

    set_count(p.ap.val, h.apGained, "+", animate)
    set_count(p.xp.val, h.xpGained, "+", animate)
    set_text(p.cp.val, h.cpGained > 0 and F.signed(h.cpGained) or "+0")
    S.color(p.ap.val, rec.ap and K.COLOR.you or K.COLOR.gold)
    if rec.ap and animate then pop(p.ap.val) end

    local lr = BGMeter.Match.local_row(m)
    local ids = lr and lr.medalIds or {}
    local counts = lr and lr.medalCounts or {}
    hide_medal_card()
    for i = 1, #p.medalIcons do
        local mi, badge, id = p.medalIcons[i], p.medalBadges[i], ids[i]
        local hit = p.medalHits[i]
        local info = id and Icons.medal_info(id) or nil
        if info and info.icon then
            mi:SetTexture(info.icon); mi:SetHidden(false)
            if hit then hit:SetHidden(false) end
            local n = counts[id] or 1
            mi.bgmMedalId = id
            mi.bgmMedalCount = n
            if n > 1 then
                set_text(badge, "x" .. n)
                badge:SetHidden(false)
            else
                badge:SetHidden(true)
            end
        else
            mi:SetHidden(true); badge:SetHidden(true)
            if hit then hit:SetHidden(true) end
            mi.bgmMedalId = nil
            mi.bgmMedalCount = nil
        end
    end
    set_text(p.medalMore, (#ids > #p.medalIcons) and ("+" .. (#ids - #p.medalIcons)) or "")

    set_text(p.eff, string.format("%s AP/min  ·  %s AP/kill", F.commas(h.apPerMin), F.commas(h.apPerKill)))

    local standControls = { p.sep, p.standHeading, p.standRank, p.standSub }
    if not Prefs.get("show_standing") or m.competitive == false then hide_all(standControls, true); return end
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
        W.battle.skull_pool:release_all()
        W.battle.chart:SetHidden(true)
        W.battle.ribbon_pool:release_all()
        W.battle.pin_pool:release_all()
        W.battle.tick_hit_pool:release_all()
        W.battle.ribbon:SetHidden(true)
        W.battle.occ_pool:release_all()
        W.battle.occ:SetHidden(true)
        W.battle.mom_pool:release_all()
        W.battle.mom:SetHidden(true)
        render_duels(nil)
        set_text(W.detail, "")
        return
    end
    render_header(m)
    render_battle(m, animate)
    render_timeline(m)
    render_duels(m)
    render_haul(m, animate)
    W.render_detail(m)
end

function W.render_detail(m)
    if selected_row then
        local r = selected_row
        local ic = team_icon(r.team)
        local prefix = ic and (F.icon(ic, 16) .. " ") or ""
        local taken = (r.taken and r.taken > 0) and string.format("  ·  %s taken", F.abbrev(r.taken)) or ""
        local eff = ""
        if m and m.durationMs and m.durationMs > 0 then
            local dpm = math.floor((r.damage or 0) / math.max(1, m.durationMs / 60000))
            eff = string.format("  ·  %s dpm", F.abbrev(dpm))
            if r.kills and r.kills > 0 then
                eff = eff .. string.format("  ·  %s per kill", F.abbrev(math.floor((r.damage or 0) / r.kills)))
            end
            local teamDmg = 0
            for _, row in ipairs(m.battle) do
                if row.team == r.team then teamDmg = teamDmg + (row.damage or 0) end
            end
            if teamDmg > 0 then
                eff = eff .. string.format("  ·  %d%% of team dmg",
                    math.floor((r.damage or 0) / teamDmg * 100 + 0.5))
            end
        end
        local capsTxt = ""
        if m and flag_col_spec(m) == "carried" then
            if (r.carried or 0) > 0 then capsTxt = string.format("  ·  held %s", F.duration(r.carried * 1000)) end
        elseif (r.caps or 0) > 0 then
            capsTxt = string.format("  ·  %d caps", r.caps)
        end
        set_text(W.detail, string.format("%s%s  ·  %s  --  %s dmg  ·  %s heal%s  ·  %d/%d/%d%s  ·  %d medals%s",
            prefix, r.displayName or r.charName or "?", team_name(r.team),
            F.abbrev(r.damage), F.abbrev(r.healing), taken, r.kills, r.deaths, r.assists, capsTxt, r.medals or 0, eff))
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

local layers_debug = false

function W.toggle_layers_debug()
    build()
    layers_debug = not layers_debug
    local Log = BGMeter.Log
    if layers_debug then
        P.set_rect_color(W.bg, { 1, 0, 1, 0.85 })
        W.bgMap:SetColor(0, 1, 0, 0.50)
        W.bgArtL:SetColor(1, 0, 0, 0.70)
        W.bgArtR:SetColor(1, 0.55, 0, 0.70)
        P.set_rect_color(W.haul.bd, { 0, 0.4, 1, 0.70 })
        P.set_rect_color(W.battle.chartBg, { 1, 1, 0, 0.50 })
        P.set_rect_color(W.footerBd, { 0, 1, 1, 0.70 })
        Log.say("layer debug ON:")
        Log.say("  |cff00ffMAGENTA|r = base window rect (W.bg)")
        Log.say("  |c00ff00GREEN|r = map loading screen (bgMap)")
        Log.say("  |cff0000RED|r = scoreboardBG left art")
        Log.say("  |cff8c00ORANGE|r = scoreboardBG right art")
        Log.say("  |c0066ffBLUE|r = haul panel backdrop")
        Log.say("  |cffff00YELLOW|r = timeline chart strip")
        Log.say("  |c00ffffCYAN|r = footer band (new)")
        Log.say("run |cFFFFFF/bgmeter layers|r again to restore")
    else
        apply_visual_prefs()
        W.bgMap:SetColor(1, 1, 1, K.ALPHA.map_art)
        W.bgArtL:SetColor(1, 1, 1, K.ALPHA.score_art)
        W.bgArtR:SetColor(1, 1, 1, K.ALPHA.score_art)
        P.set_rect_color(W.haul.bd, K.COLOR.panel)
        P.set_rect_color(W.battle.chartBg, { 1, 1, 1, K.ALPHA.chart_bg })
        P.set_rect_color(W.footerBd, { K.COLOR.panel[1], K.COLOR.panel[2], K.COLOR.panel[3], K.ALPHA.footer_band })
        Log.say("layer debug OFF")
    end
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
    if not want then
        W._chart_hover_stop()
        hide_medal_card()
    end
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
    if Prefs.get("animate") then W.win:SetAlpha(0); Anim.value(0, 1, K.ANIM.window_fade_ms, function(v) W.win:SetAlpha(v) end)
    else W.win:SetAlpha(1) end
    W._persist_hidden(false)
end

function W.current() return current_index end

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
    hide_medal_card()
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
