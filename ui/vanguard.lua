-- bgmeter :: ui/vanguard.lua
-- The "Vanguard Bar" -- a slim, optional HUD widget for your AvA-wide veterancy
-- progress + AP, designed to be transversal: it shows in battlegrounds AND in
-- Cyrodiil (the veterancy season-track advances everywhere). Two personalities,
-- one object:
--
--   FLOAT mode (default): a free, draggable capsule
--       [rank icon]  ==== "3,650 / 5,000" ====  [next-rank icon]
--     Hovering grows it downward into a rich detail panel (season time, AP this
--     session + AP/hour, the AP-by-source breakdown as a stacked mini-bar).
--
--   DOCK mode: pinned just above the native experience bar (ZO_PlayerProgress),
--     micro (no inline text), reads as "your second XP bar". Hovering shows the
--     same detail as a native text tooltip -- no expansion, so it sits cleanly at
--     the bottom edge.
--
-- Both modes share the polish that makes "always on" pleasant:
--   * Auto-fade at rest -- the bar idles dim (~28%) and self-brightens for ~2s
--     whenever you gain AP or a veterancy rank, then fades back. The eye ignores
--     it until something happens.
--   * Scene-aware -- it auto-hides in menus/inventory/map and only shows on the
--     gameplay HUD (via the HUD scenes' StateChange).
--   * Earning AP slides the fill + floats a "+N AP" toast; a tier-up flashes the
--     bar gold and plays the rank-up cue; the fill shifts violet -> gold in the
--     final stretch to the next rank.
--
-- It subscribes to BGMeter.Ava for live AP/session events and reads
-- BGMeter.Veterancy.snapshot() for the rank fill, owning no data of its own.

BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local V = {}
local built = false
local expanded = false
local preview_vet = nil          -- demo override for the veterancy snapshot
local C, K, F, P, S, Bar, Icons, Prefs, Anim, Sound, Ava, Vet

-- ── layout ──────────────────────────────────────────────────────────────────
local VW        = 360            -- default window width (user-resizable)
local V_MINW    = 240            -- resize clamp
local V_MAXW    = 680
local VH        = 40             -- collapsed height (one capsule row)
local ICON      = 30             -- rank-icon edge
local PAD       = 8
local BAR_H     = 14
local ROW_H     = 16             -- a breakdown row
local PANEL_TOP = 10             -- gap below the capsule before the panel content
local SEGMENTS  = 8              -- battle-pass-style tick divisions on the fill

-- ── auto-fade ───────────────────────────────────────────────────────────────
local REST_ALPHA  = 0.28
local WAKE_ALPHA  = 1.0
local WAKE_HOLD_MS = 2200        -- how long it stays bright after an event
local FADE_MS     = 600

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if not ok then return nil end
    return a
end

-- pcall a method call (obj:method(...)) safely.
local function safe_m(obj, method, ...)
    if not obj or type(obj[method]) ~= "function" then return nil end
    local ok, a = pcall(obj[method], obj, ...)
    if not ok then return nil end
    return a
end

local function set_text(c, t) if c then c:SetText(t or "") end end

local function sv_vanguard()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return { x = 0, y = 0, locked = false } end
    sv.vanguard = sv.vanguard or { x = 0, y = 0, locked = false }
    return sv.vanguard
end

-- The veterancy snapshot to render (demo override wins, else live).
local function current_vet()
    if preview_vet then return preview_vet end
    return Vet and Vet.snapshot() or nil
end

-- Width available to the fill bar between the two rank icons.
local function bar_width()
    return V.w - 2 * PAD - 2 * ICON - 2 * 8
end

local function in_bg()
    return safe(BGMeter.zenimax.api.is_active_bg) and true or false
end

-- The context-appropriate AP/session line. In a battleground the AvA session
-- doesn't run (a BG isn't an AvA world) and the match AP is shown post-match, so
-- we don't nag about Cyrodiil there -- the bar is just the veterancy track.
local function session_line()
    local s = Ava.session
    if s.ap > 0 then
        return string.format("%s AP this session  ·  %s AP/hr",
            F.commas(s.ap), F.commas(Ava.ap_per_hour()))
    elseif in_bg() then
        return "Battleground  ·  AP tallies in the post-match window"
    elseif Ava.in_ava() then
        return "0 AP yet this session  ·  go earn some"
    else
        return "veterancy progress (AvA-wide)"
    end
end

-- Hint under the breakdown; empty (no nag) unless we're idle in a place where
-- the by-source split would actually fill.
local function breakdown_hint(hasSplit)
    if hasSplit or in_bg() then return "" end
    if Ava.in_ava() then return "earn AP to see the split" end
    return "the AP split fills in Cyrodiil / Imperial City"
end

-- Fill colour: veterancy violet, easing to gold in the final 10% to the next
-- rank, so the home stretch reads as "almost there". Details matter.
local function vet_fill_color(pct)
    local v, g = K.COLOR.veterancy, K.COLOR.gold
    if not pct or pct < 0.9 then return v end
    local t = math.min(1, (pct - 0.9) / 0.1)
    return { v[1] + (g[1] - v[1]) * t, v[2] + (g[2] - v[2]) * t, v[3] + (g[3] - v[3]) * t, 1 }
end

-- ── build ───────────────────────────────────────────────────────────────────

local function build_panel(win)
    local p = {}
    local INNER = VW - 2 * PAD

    p.div = P.rect(win, { 1, 1, 1, 0.10 })
    p.div:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, VH - 2)
    p.div:SetDimensions(INNER, 1)

    p.season = P.label(win, S.FONT.small, K.COLOR.text_dim)
    p.season:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, VH + PANEL_TOP)
    p.season:SetDimensions(INNER, 16)

    -- AP session line: [green AP icon]  12,400 AP this session  ·  3,180 AP/hr
    p.apIcon = P.icon(win, Icons.ap())
    p.apIcon:SetDimensions(20, 20)
    p.apIcon:SetAnchor(TOPLEFT, p.season, BOTTOMLEFT, 0, 8)
    p.apLine = P.label(win, S.FONT.row, K.COLOR.gold)
    p.apLine:SetAnchor(LEFT, p.apIcon, RIGHT, 8, 0)
    p.apLine:SetDimensions(INNER - 28, 20)
    p.apLine:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- stacked proportional mini-bar of the AP-by-source split
    p.stackBG = P.rect(win, { 1, 1, 1, 0.06 })
    p.stackBG:SetAnchor(TOPLEFT, p.apIcon, BOTTOMLEFT, 0, 10)
    p.stackBG:SetDimensions(INNER, BAR_H)
    p.segments = {}
    for i = 1, #Ava.SOURCES do
        local seg = P.rect(win, Ava.SOURCES[i].color)
        seg:SetHeight(BAR_H)
        seg:SetHidden(true)
        p.segments[i] = seg
    end

    -- breakdown rows (preallocated; shown/hidden per render)
    p.rows = {}
    for i = 1, #Ava.SOURCES do
        local r = {}
        r.swatch = P.rect(win, { 1, 1, 1, 1 })
        r.swatch:SetDimensions(10, 10)
        r.label = P.label(win, S.FONT.small, K.COLOR.text)
        r.label:SetDimensions(INNER - 90, ROW_H)
        r.value = P.label(win, S.FONT.small, K.COLOR.text_dim)
        r.value:SetDimensions(78, ROW_H)
        r.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        r.swatch:SetHidden(true); r.label:SetHidden(true); r.value:SetHidden(true)
        p.rows[i] = r
    end

    p.hint = P.label(win, S.FONT.small, K.COLOR.text_dim)
    p.hint:SetDimensions(INNER, 14)
    p.hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    return p
end

local function build()
    if built then return end
    C, K, F = BGMeter.zenimax.constants, BGMeter.Constants, BGMeter.Format
    P, S, Bar = BGMeter.Plot.primitives, BGMeter.Plot.style, BGMeter.Plot.bar
    Icons, Prefs = BGMeter.Icons, BGMeter.Prefs
    Anim, Sound = BGMeter.Anim, BGMeter.Sound
    Ava, Vet = BGMeter.Ava, BGMeter.Veterancy

    local g0 = sv_vanguard()
    V.w = (g0.w and g0.w >= V_MINW and g0.w <= V_MAXW) and g0.w or VW

    local win = BGMeter.zenimax.ui.wm:CreateTopLevelWindow("BGMeterVanguard")
    win:SetDimensions(V.w, VH)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    -- width-only resize: handles let you drag the width; height is owned by the
    -- addon (collapsed vs hover-expanded), so OnResizeStop forces height back.
    win:SetResizeHandleSize(6)
    win:SetDimensionConstraints(V_MINW, VH, V_MAXW, 2000)
    win:SetHandler("OnResizeStop", function() V.on_resize_stop() end)
    V.win = win

    -- chrome: dark capsule + the same crisp ESO border the main window uses
    V.bg = P.rect(win, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.88 })
    V.bg:SetAnchorFill(win)
    P.frame(win):SetAnchorFill(win)

    -- left/right rank medallions (real veterancy rank art)
    V.rankIcon = P.icon(win)
    V.rankIcon:SetDimensions(ICON, ICON)
    V.rankIcon:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, (VH - ICON) / 2)

    V.nextIcon = P.icon(win)
    V.nextIcon:SetDimensions(ICON, ICON)
    V.nextIcon:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD, (VH - ICON) / 2)

    -- the fill bar between them
    V.bar = Bar.create(win)
    V.bar.container:SetAnchor(LEFT, V.rankIcon, RIGHT, 8, 0)
    V.bar.container:SetDimensions(bar_width(), BAR_H)

    -- battle-pass segmentation: faint dark ticks over the fill (SEGMENTS-1 of them)
    V.ticks = {}
    local bw = bar_width()
    for i = 1, SEGMENTS - 1 do
        local tick = P.rect(V.bar.container, { 0, 0, 0, 0.35 })
        tick:SetDimensions(1, BAR_H)
        tick:SetAnchor(LEFT, V.bar.container, LEFT, math.floor(bw * i / SEGMENTS + 0.5), 0)
        V.ticks[i] = tick
    end

    -- centered progress text over the bar (hidden in dock/micro mode)
    V.barText = P.label(win, S.FONT.small, K.COLOR.text)
    V.barText:SetAnchor(CENTER, V.bar.container, CENTER, 0, 0)
    V.barText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- the floating "+N AP" toast (hidden at rest)
    V.toast = P.label(win, S.FONT.row, K.COLOR.gold)
    V.toast:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    V.toast:SetDimensions(120, 22)
    V.toast:SetHidden(true)

    V.panel = build_panel(win)

    -- drag (float only) + hover (mode-dependent)
    win:SetHandler("OnMoveStop", function() V.on_move_stop() end)
    win:SetHandler("OnMouseEnter", function() V.on_enter() end)
    win:SetHandler("OnMouseExit", function() V.on_exit() end)
    win:SetHandler("OnMouseUp", function(_, button, upInside)
        -- a click on the docked micro-bar opens the full window (in float the
        -- click is ambiguous with a drag, so we leave float to the hover panel)
        if upInside and Prefs.get("vanguard_dock") and BGMeter.UI.window then
            BGMeter.UI.window.show()
        end
    end)

    Ava.subscribe(function(evt) V.on_ava(evt) end)
    built = true
end

-- ── render ──────────────────────────────────────────────────────────────────

-- The capsule: rank medallions + fill + "X / Y" text (+ colour shift near rank).
local function render_bar(animate)
    local dock = Prefs.get("vanguard_dock")
    local vet = current_vet()
    if not vet or not vet.rank then
        if vet then
            V.rankIcon:SetHidden(true); V.nextIcon:SetHidden(true)
            Bar.set(V.bar, 0, K.COLOR.veterancy, bar_width())
            set_text(V.barText, "no veterancy season")
            S.color(V.barText, K.COLOR.text_dim)
            V.barText:SetHidden(dock)
        end
        return
    end

    if vet.rankIcon then V.rankIcon:SetTexture(vet.rankIcon); V.rankIcon:SetHidden(false)
    else V.rankIcon:SetHidden(true) end

    -- next-rank medallion (one tier up); hidden at max rank
    local nextIcon = vet.rank and safe(BGMeter.zenimax.api.get_veterancy_rank_icon, vet.rank + 1, vet.seasonId)
    if nextIcon then V.nextIcon:SetTexture(nextIcon); V.nextIcon:SetHidden(false)
    else V.nextIcon:SetHidden(true) end

    local pct = vet.percent
    local w = bar_width()
    if pct == nil then
        Bar.set(V.bar, 0, K.COLOR.text_dim, w)
        set_text(V.barText, "no track data"); S.color(V.barText, K.COLOR.text_dim)
    elseif vet.tierTotal == 0 then
        Bar.set(V.bar, 1, K.COLOR.gold, w)
        set_text(V.barText, "MAX RANK"); S.color(V.barText, K.COLOR.gold)
    else
        local col = vet_fill_color(pct)
        if animate and Prefs.get("animate") then
            Anim.value(0, pct, 450, function(v) Bar.set(V.bar, v, vet_fill_color(v), w) end)
        else
            Bar.set(V.bar, pct, col, w)
        end
        set_text(V.barText, string.format("%s / %s",
            F.commas(vet.progressToNext or 0), F.commas(vet.tierTotal or 0)))
        S.color(V.barText, K.COLOR.text)
    end
    V.barText:SetHidden(dock)   -- micro in dock mode
end

-- The float-mode hover panel: season, AP session + rate, stacked split + rows.
local function render_panel()
    local pnl = V.panel
    local vet = current_vet()
    local INNER = V.w - 2 * PAD

    if vet and vet.seasonName then
        local ends = (vet.secondsLeft and vet.secondsLeft > 0)
            and ("  ·  ends in " .. F.countdown(vet.secondsLeft)) or ""
        set_text(pnl.season, vet.seasonName .. ends)
    elseif vet and vet.rank then
        set_text(pnl.season, "Veteran Rank " .. tostring(vet.rank))
    else
        set_text(pnl.season, "Veterancy season")
    end

    set_text(pnl.apLine, session_line())

    local bd = Ava.breakdown()
    local rowsBottom = VH + PANEL_TOP + 16 + 8 + 20 + 10 + BAR_H + 8

    local x, totalW = 0, INNER
    for i = 1, #pnl.segments do pnl.segments[i]:SetHidden(true) end
    pnl.stackBG:SetHidden(false)
    for i, e in ipairs(bd) do
        local seg = pnl.segments[i]
        if seg then
            local segw = math.max(2, math.floor(totalW * e.pct + 0.5))
            if x + segw > totalW then segw = totalW - x end
            seg:ClearAnchors()
            seg:SetAnchor(TOPLEFT, pnl.stackBG, TOPLEFT, x, 0)
            seg:SetDimensions(segw, BAR_H)
            P.set_rect_color(seg, e.color)
            seg:SetHidden(false)
            x = x + segw
        end
    end

    local y = rowsBottom
    for i = 1, #pnl.rows do
        local r = pnl.rows[i]
        local e = bd[i]
        if e then
            r.swatch:ClearAnchors()
            r.swatch:SetAnchor(TOPLEFT, V.win, TOPLEFT, PAD, y + 3)
            P.set_rect_color(r.swatch, e.color)
            r.label:ClearAnchors()
            r.label:SetAnchor(TOPLEFT, r.swatch, TOPRIGHT, 8, -3)
            set_text(r.label, e.label)
            r.value:ClearAnchors()
            r.value:SetAnchor(TOPRIGHT, V.win, TOPRIGHT, -PAD, y)
            set_text(r.value, string.format("%s  (%d%%)", F.commas(e.ap), math.floor(e.pct * 100 + 0.5)))
            r.swatch:SetHidden(false); r.label:SetHidden(false); r.value:SetHidden(false)
            y = y + ROW_H
        else
            r.swatch:SetHidden(true); r.label:SetHidden(true); r.value:SetHidden(true)
        end
    end

    local hint = breakdown_hint(#bd > 0)
    if hint ~= "" then y = y + 2 end
    set_text(pnl.hint, hint)
    pnl.hint:ClearAnchors()
    pnl.hint:SetAnchor(TOPLEFT, V.win, TOPLEFT, PAD, y + 6)

    V.expandedHeight = math.max(y + 24, VH + 120)
end

local function show_panel(show)
    local pnl = V.panel
    pnl.div:SetHidden(not show)
    pnl.season:SetHidden(not show)
    pnl.apIcon:SetHidden(not show)
    pnl.apLine:SetHidden(not show)
    pnl.stackBG:SetHidden(not show)
    pnl.hint:SetHidden(not show)
    if not show then
        for i = 1, #pnl.segments do pnl.segments[i]:SetHidden(true) end
        for i = 1, #pnl.rows do
            pnl.rows[i].swatch:SetHidden(true)
            pnl.rows[i].label:SetHidden(true)
            pnl.rows[i].value:SetHidden(true)
        end
    end
end

-- The dock-mode hover text (the same detail, native tooltip, no expansion).
function V.tooltip_text()
    local vet = current_vet()
    local lines = {}
    if vet and vet.rank then
        lines[#lines + 1] = vet.rankTitle or ("Veteran Rank " .. tostring(vet.rank))
        if vet.percent and vet.tierTotal and vet.tierTotal > 0 then
            lines[#lines + 1] = string.format("%s / %s to next rank  (%d%%)",
                F.commas(vet.progressToNext or 0), F.commas(vet.tierTotal),
                math.floor(vet.percent * 100 + 0.5))
        elseif vet.tierTotal == 0 then
            lines[#lines + 1] = "max rank reached"
        end
        if vet.seasonName then
            local ends = (vet.secondsLeft and vet.secondsLeft > 0)
                and ("  ·  ends in " .. F.countdown(vet.secondsLeft)) or ""
            lines[#lines + 1] = vet.seasonName .. ends
        end
    end
    lines[#lines + 1] = session_line()
    for _, e in ipairs(Ava.breakdown()) do
        lines[#lines + 1] = string.format("   %s: %s  (%d%%)",
            e.label, F.commas(e.ap), math.floor(e.pct * 100 + 0.5))
    end
    lines[#lines + 1] = "click to open bgmeter"
    return table.concat(lines, "\n")
end

-- ── auto-fade ───────────────────────────────────────────────────────────────

local function rest_alpha()
    return Prefs.get("vanguard_fade") and REST_ALPHA or WAKE_ALPHA
end

local function set_alpha(a) if V.win then V.win:SetAlpha(a) end end

-- Brighten now; cancel any pending fade (a new event / a hover resets the clock).
local function wake_full()
    V.wakeToken = (V.wakeToken or 0) + 1
    set_alpha(WAKE_ALPHA)
end

local function fade_to_rest()
    if V.hovered then return end
    local target = rest_alpha()
    if Prefs.get("animate") then
        Anim.value(WAKE_ALPHA, target, FADE_MS, set_alpha)
    else
        set_alpha(target)
    end
end

-- Schedule the bar to fade back to its idle dim after the hold window.
local function schedule_fade()
    if not Prefs.get("vanguard_fade") then set_alpha(WAKE_ALPHA); return end
    local token = (V.wakeToken or 0) + 1
    V.wakeToken = token
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if V.wakeToken == token and not V.hovered and built and not V.win:IsHidden() then
                fade_to_rest()
            end
        end, WAKE_HOLD_MS)
    end
end

-- A full wake-and-settle cycle (used on AP / veterancy events).
local function wake()
    if not built or V.win:IsHidden() then return end
    wake_full()
    schedule_fade()
end

-- ── interaction ─────────────────────────────────────────────────────────────

function V.expand()
    if not built or expanded then return end
    expanded = true
    render_panel()
    show_panel(true)
    V.win:SetHeight(V.expandedHeight or (VH + 160))
end

function V.collapse()
    if not built or not expanded then return end
    expanded = false
    show_panel(false)
    V.win:SetHeight(VH)
end

function V.on_enter()
    if not built then return end
    V.hovered = true
    wake_full()
    if Prefs.get("vanguard_dock") then
        if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(V.win, TOP, V.tooltip_text()) end
    else
        V.expand()
    end
end

function V.on_exit()
    if not built then return end
    V.hovered = false
    if Prefs.get("vanguard_dock") then
        if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
    else
        V.collapse()
    end
    schedule_fade()
end

-- A "+N AP" toast that rises off the capsule and fades.
local function float_toast(text, color)
    if not Prefs.get("animate") then return end
    local t = V.toast
    S.color(t, color or K.COLOR.gold)
    set_text(t, text)
    t:SetHidden(false)
    t:SetAlpha(1)
    Anim.start(950, function(p)
        t:ClearAnchors()
        t:SetAnchor(BOTTOM, V.bar.container, TOP, 0, -2 - math.floor(p * 16))
        t:SetAlpha(1 - p)
    end, function() t:SetHidden(true) end)
end

-- A brief gold flash of the fill on a rank-up.
local function flash_rankup()
    if not Prefs.get("animate") then render_bar(false); return end
    local w = bar_width()
    Anim.start(700, function(p)
        local g = 1 - p
        local col = { K.COLOR.gold[1] * g + K.COLOR.veterancy[1] * p,
                      K.COLOR.gold[2] * g + K.COLOR.veterancy[2] * p,
                      K.COLOR.gold[3] * g + K.COLOR.veterancy[3] * p, 1 }
        Bar.set(V.bar, 1, col, w)
    end, function() render_bar(true) end)
end

-- React to AvA engine events.
function V.on_ava(evt)
    if not built or V.win:IsHidden() then return end
    if evt.kind == "ap" then
        wake()
        local apIcon = Icons.ap()
        local prefix = apIcon and (F.icon(apIcon, 18) .. " ") or ""
        float_toast(prefix .. "+" .. F.commas(evt.delta), K.COLOR.gold)
        render_bar(false)
        if expanded then render_panel() end
    elseif evt.kind == "veterancy" then
        wake()
        if evt.rankUp then
            float_toast(F.icon("EsoUI/Art/Collections/favorite_starOnly.dds", 20) .. " RANK UP!", K.COLOR.gold)
            flash_rankup()
            Sound.play("rankup")
        else
            render_bar(true)
        end
    elseif evt.kind == "session" or evt.kind == "reset" then
        render_bar(false)
        if expanded then render_panel() end
    end
end

function V.on_move_stop()
    if not built or Prefs.get("vanguard_dock") then return end
    local g = sv_vanguard()
    g.x, g.y = V.win:GetLeft(), V.win:GetTop()
end

-- ── resize (width-only) ─────────────────────────────────────────────────────

-- Reflow everything that depends on the window width: the fill bar, the
-- segmentation ticks, and the panel element widths.
local function relayout()
    if not built then return end
    V.win:SetWidth(V.w)
    local bw = bar_width()
    V.bar.container:SetWidth(bw)
    for i = 1, #V.ticks do
        V.ticks[i]:ClearAnchors()
        V.ticks[i]:SetAnchor(LEFT, V.bar.container, LEFT, math.floor(bw * i / SEGMENTS + 0.5), 0)
    end
    local pnl, INNER = V.panel, V.w - 2 * PAD
    pnl.div:SetWidth(INNER)
    pnl.season:SetWidth(INNER)
    pnl.apLine:SetWidth(INNER - 28)
    pnl.stackBG:SetWidth(INNER)
    pnl.hint:SetWidth(INNER)
    for i = 1, #pnl.rows do
        pnl.rows[i].label:SetWidth(INNER - 90)
    end
    render_bar(false)
    if expanded then render_panel() end
end

function V.on_resize_stop()
    if not built then return end
    local w = V.win:GetWidth()
    if w < V_MINW then w = V_MINW elseif w > V_MAXW then w = V_MAXW end
    V.w = w
    sv_vanguard().w = w
    -- height is addon-owned: snap it back (the user only resizes width)
    V.win:SetHeight(expanded and (V.expandedHeight or (VH + 120)) or VH)
    relayout()
end

-- ── mode (dock / float) ─────────────────────────────────────────────────────

function V.apply_mode()
    if not built then return end
    V.collapse()
    local dock = Prefs.get("vanguard_dock")
    local g = sv_vanguard()
    V.win:ClearAnchors()
    if dock then
        V.win:SetMovable(false)
        -- pin just above the native experience bar; fall back to a fixed spot
        -- near the bottom-centre if that control isn't available.
        local xpbar = BGMeter.zenimax.ui.get_control("ZO_PlayerProgress")
        if xpbar then V.win:SetAnchor(BOTTOM, xpbar, TOP, 0, -8)
        else V.win:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -110) end
    else
        V.win:SetMovable(not g.locked)
        if not (g.x == 0 and g.y == 0) then
            V.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, g.x, g.y)
        else
            V.win:SetAnchor(TOP, GuiRoot, TOP, 0, 120)
        end
    end
    render_bar(false)
end

-- ── scene-awareness (hide in menus, show on the gameplay HUD) ────────────────

function V.refresh_visibility()
    if not built then return end
    local vis = Prefs.get("show_vanguard") and V.onHud
    V.win:SetHidden(not vis)
end

function V.on_scene(onHud)
    V.onHud = onHud and true or false
    if not built then return end
    V.refresh_visibility()
    if V.onHud and not V.win:IsHidden() then
        set_alpha(rest_alpha()); wake()   -- re-settle when returning to the HUD
    end
end

local scene_wired = false
function V.init_scene()
    if scene_wired or not SCENE_MANAGER then return end
    local function handler(_, newState)
        if newState == SCENE_SHOWN then V.on_scene(true)
        elseif newState == SCENE_HIDDEN then V.on_scene(false) end
    end
    for _, name in ipairs({ "hud", "hudui" }) do
        local sc = safe_m(SCENE_MANAGER, "GetScene", name)
        if sc and type(sc.RegisterCallback) == "function" then
            pcall(function() sc:RegisterCallback("StateChange", handler) end)
        end
    end
    scene_wired = true
end

-- ── show / hide / lock / mode toggles ───────────────────────────────────────

function V.show()
    build()
    Prefs.set("show_vanguard", true)
    V.onHud = (BGMeter.zenimax.scene and BGMeter.zenimax.scene.is_hud_scene()) and true or true
    expanded = false
    show_panel(false)
    V.apply_mode()
    V.refresh_visibility()
    render_bar(true)
    set_alpha(rest_alpha())
    wake()
end

function V.hide()
    if not built then Prefs.set("show_vanguard", false); return end
    Prefs.set("show_vanguard", false)
    if ZO_Tooltips_HideTextTooltip then pcall(ZO_Tooltips_HideTextTooltip) end
    V.win:SetHidden(true)
end

function V.toggle()
    build()
    if V.win:IsHidden() then V.show(); Sound.play("open")
    else V.hide() end
end

function V.toggle_lock()
    build()
    local g = sv_vanguard()
    g.locked = not g.locked
    if not Prefs.get("vanguard_dock") then V.win:SetMovable(not g.locked) end
    BGMeter.Log.say("vanguard bar %s", g.locked and "locked" or "unlocked")
    return g.locked
end

function V.toggle_dock()
    build()
    local on = Prefs.toggle("vanguard_dock")
    V.apply_mode()
    if not V.win:IsHidden() then wake() end
    BGMeter.Log.say("vanguard bar: %s mode", on and "docked (by the XP bar)" or "floating")
    return on
end

function V.toggle_fade()
    build()
    local on = Prefs.toggle("vanguard_fade")
    set_alpha(on and rest_alpha() or WAKE_ALPHA)
    if on then wake() end
    BGMeter.Log.say("vanguard auto-fade %s", on and "ON" or "OFF")
    return on
end

-- Re-apply the current prefs (mode + fade) without toggling anything. Called by
-- the settings window after it flips a vanguard_* pref directly.
function V.sync()
    build()
    if Prefs.get("show_vanguard") then
        if V.win:IsHidden() then V.show(); return end
        V.apply_mode()
        set_alpha(rest_alpha())
        wake()
    else
        V.hide()
    end
end

-- Demo: show the bar with a supplied veterancy snapshot so /bgmeter demo can
-- showcase it without standing in Cyrodiil.
function V.preview(vet)
    build()
    preview_vet = vet
    V.show()
    if not Prefs.get("vanguard_dock") then V.expand() end
end

function V.clear_preview()
    preview_vet = nil
    if built then render_bar(false); if expanded then render_panel() end end
end

function V.init()
    V.onHud = true
    V.init_scene()
    if BGMeter.Prefs.get("show_vanguard") then V.show() end
    BGMeter.Log.debug("vanguard ready (shown=%s dock=%s fade=%s)",
        tostring(BGMeter.Prefs.get("show_vanguard")),
        tostring(BGMeter.Prefs.get("vanguard_dock")),
        tostring(BGMeter.Prefs.get("vanguard_fade")))
end

BGMeter.UI.vanguard = V
