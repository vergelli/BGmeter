BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local W = U.W
local TX = U.TX
local set_text, mk_button, team_name, hexc = U.set_text, U.mk_button, U.team_name, U.hexc

local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prefs = BGMeter.Prefs
local Sound = BGMeter.Sound
local Scene = BGMeter.zenimax.scene

local M = {}

local PAD = 16
local SCRUB_H = 26
local LEGEND_W = 200
local BINS = 32
local DOCK_SNAP = 48
local SKULL = "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds"
local FALLBACK_PIN = "EsoUI/Art/MapPins/battlegrounds_murderball_neutral.dds"
local FALLBACK_AREA = "EsoUI/Art/MapPins/battlegrounds_capturePoint_pin_neutral.dds"
local LV = { tile = 1, heat = 2, path = 3, mark = 4, hit = 5 }

local LAYERS = {
    { key = "map_heat_mode", label = "Heat", cycle = { "presence", "deaths", "off" },
      names = { presence = "presence", deaths = "deaths", off = "off" },
      tip = "Click to cycle.\nPresence: where your team spent its time once the gates opened.\nDeaths: where you died and where you got kills, spread around each spot." },
    { key = "map_path",   label = "Your path",  tip = "Where you went, gold on a halo in your team's colour, up to the scrubbed second." },
    { key = "map_team",   label = "Team paths", tip = "Your teammates' paths, faint, in the team colour." },
    { key = "map_deaths", label = "Deaths",     tip = "Red skull = where you died  ·  gold skull = where you got a kill." },
    { key = "map_pins",   label = "Objectives", tip = "Flags, relics and balls where they were at the scrubbed second." },
}

local VIRIDIS = {
    { 0.27, 0.00, 0.33 }, { 0.28, 0.14, 0.46 }, { 0.24, 0.29, 0.54 }, { 0.19, 0.41, 0.56 },
    { 0.13, 0.57, 0.55 }, { 0.21, 0.72, 0.47 }, { 0.53, 0.83, 0.29 }, { 0.99, 0.91, 0.14 },
}
local EMBER = {
    { 0.20, 0.02, 0.10 }, { 0.45, 0.05, 0.15 }, { 0.72, 0.12, 0.12 }, { 0.90, 0.35, 0.10 },
    { 0.98, 0.62, 0.15 }, { 1.00, 0.85, 0.40 }, { 1.00, 0.97, 0.75 }, { 1.00, 1.00, 1.00 },
}

local function ramp(lut, u)
    u = math.max(0, math.min(1, u))
    local pos = u * (#lut - 1) + 1
    local i = math.floor(pos)
    local f = pos - i
    local a, b = lut[i], lut[math.min(#lut, i + 1)]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

local built = false
local c = nil
local state = { m = nil, geo = nil, t = nil, side = 0, applying = false, docked = true }

local function sv_win()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return {} end
    sv.window = sv.window or {}
    sv.window.map = sv.window.map or { open = false, dock = true, x = 0, y = 0, w = 0, h = 0 }
    return sv.window.map
end

local function pin_texture(ty, kind)
    local data = ZO_MapPin and ZO_MapPin.PIN_DATA and ty and ZO_MapPin.PIN_DATA[ty]
    if data and data.texture then return data.texture end
    if kind == "area" then return FALLBACK_AREA end
    return FALLBACK_PIN
end

local function leveled_pool(make, level)
    return BGMeter.Plot.pool.new(
        function()
            local ctl = make()
            if ctl.SetDrawLevel then ctl:SetDrawLevel(level) end
            return ctl
        end,
        function(ctl) ctl:SetHidden(true); ctl:ClearAnchors() end)
end

local function dock()
    local win = c.win
    win:ClearAnchors()
    if W.win then
        win:SetAnchor(TOPLEFT, W.win, BOTTOMLEFT, 0, 4)
    else
        win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    state.docked = true
    sv_win().dock = true
end

local function undock(x, y)
    local win = c.win
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    state.docked = false
    local g = sv_win()
    g.dock, g.x, g.y = false, x, y
end

local function on_move_stop()
    if not W.win then return end
    local x, y = c.win:GetLeft(), c.win:GetTop()
    local dx = math.abs(x - W.win:GetLeft())
    local dy = math.abs(y - (W.win:GetBottom() + 4))
    if dx <= DOCK_SNAP and dy <= DOCK_SNAP then
        dock()
        Sound.play("nav")
    else
        undock(x, y)
    end
end

local function build()
    if built then return end
    local wm = BGMeter.zenimax.ui.wm
    local g = sv_win()
    local win = wm:CreateTopLevelWindow("BGMeterMapPanel")
    win:SetDimensions((g.w or 0) > 0 and g.w or L.map_w, (g.h or 0) > 0 and g.h or L.map_h)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetDrawTier(DT_HIGH)
    win:SetResizeHandleSize(L.resize_h)
    win:SetDimensionConstraints(L.map_min, L.map_min - 120, L.max_w, L.max_h)
    win:SetHandler("OnMoveStop", on_move_stop)
    win:SetHandler("OnResizeStop", function()
        M.snap_size()
        M.render()
    end)
    Scene.register_top_level(win, function() M.close() end)
    c = { win = win }

    c.bg = P.rect(win, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.97 })
    c.bg:SetAnchorFill(win)
    c.art = P.icon(win)
    c.art:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
    c.art:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -2, -2)
    c.art:SetColor(1, 1, 1, K.ALPHA.map_art * 0.8)
    c.art:SetHidden(true)
    P.frame(win):SetAnchorFill(win)
    local strip = P.rect(win, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    c.map = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    c.map:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, PAD)
    c.map:SetMouseEnabled(true)
    c.mapBg = P.rect(c.map, { 0, 0, 0, 0.7 })
    c.mapBg:SetAnchorFill(c.map)
    c.tiles = {}
    c.heat_pool = leveled_pool(function() return P.rect(c.map, { 1, 1, 1, 1 }) end, LV.heat)
    c.dot_pool = leveled_pool(function() return P.rect(c.map, { 1, 1, 1, 1 }) end, LV.mark)
    local probe = P.line(c.map, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        c.line_pool = leveled_pool(function() return P.line(c.map, { 1, 1, 1, 1 }, 2) end, LV.path)
    end
    c.icon_pool = leveled_pool(function() return P.icon(c.map, "") end, LV.mark)
    c.hit_pool = BGMeter.Plot.pool.new(
        function()
            local h = BGMeter.zenimax.ui.create_control(nil, c.map, CT_CONTROL)
            if h.SetDrawLevel then h:SetDrawLevel(LV.hit) end
            W.tip_dynamic(h)
            return h
        end,
        function(h) h:SetHidden(true); h:ClearAnchors(); W.tips[h] = nil end)
    c.mapBox = P.hairline_box(c.map, { K.COLOR.text_dim[1], K.COLOR.text_dim[2], K.COLOR.text_dim[3], K.ALPHA.chart_edge })
    for _, edge in pairs(c.mapBox) do if edge.SetDrawLevel then edge:SetDrawLevel(LV.hit) end end

    c.empty = P.label(c.map, S.FONT.small, K.COLOR.text_dim)
    c.empty:SetAnchor(CENTER, c.map, CENTER, 0, 0)
    c.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.empty:SetText("this match was recorded before 0.4.0\nthere is no position data to draw")
    c.empty:SetHidden(true)
    if c.empty.SetDrawLevel then c.empty:SetDrawLevel(LV.hit) end

    c.title = P.label(win, S.FONT.title, K.COLOR.text)
    c.title:SetText("MAP")
    c.title:SetAnchor(TOPLEFT, c.map, TOPRIGHT, PAD, -4)
    c.sub = P.label(win, S.FONT.small, K.COLOR.text_dim)
    U.clamp_line(c.sub)
    c.sub:SetAnchor(TOPLEFT, c.title, BOTTOMLEFT, 0, 2)
    c.sub:SetDimensions(LEGEND_W, 14)

    c.close = mk_button(win, TX.close, 20, function() M.close() end, "Close")
    c.close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -14, 14)

    local edge = { K.COLOR.text_dim[1], K.COLOR.text_dim[2], K.COLOR.text_dim[3], K.ALPHA.chart_edge }
    local function card(y, h, heading)
        local box = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
        box:SetAnchor(TOPLEFT, c.map, TOPRIGHT, PAD, y)
        box:SetDimensions(LEGEND_W, h)
        local bg = P.rect(box, { 1, 1, 1, K.ALPHA.chart_bg })
        bg:SetAnchorFill(box)
        P.hairline_box(box, edge)
        local hd = P.label(box, S.FONT.small, K.COLOR.gold)
        hd:SetText(heading)
        hd:SetAnchor(TOPLEFT, box, TOPLEFT, 8, 5)
        hd:SetDimensions(LEGEND_W - 16, 14)
        local rule = P.rect(box, { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.22 })
        rule:SetAnchor(TOPLEFT, box, TOPLEFT, 8, 22)
        rule:SetAnchor(TOPRIGHT, box, TOPRIGHT, -8, 22)
        rule:SetHeight(1)
        return box
    end

    c.layersCard = card(48, 30 + #LAYERS * 24 + 6, "LAYERS")
    c.toggles = {}
    local y = 30
    for i, lay in ipairs(LAYERS) do
        local t = {}
        t.hit = BGMeter.zenimax.ui.create_control(nil, c.layersCard, CT_CONTROL)
        t.hit:SetAnchor(TOPLEFT, c.layersCard, TOPLEFT, 8, y)
        t.hit:SetDimensions(LEGEND_W - 16, 22)
        t.hit:SetMouseEnabled(true)
        t.mark = P.rect(t.hit, K.COLOR.accent)
        t.mark:SetAnchor(LEFT, t.hit, LEFT, 0, 0)
        t.mark:SetDimensions(3, 14)
        t.label = P.label(t.hit, S.FONT.row, K.COLOR.text)
        t.label:SetAnchor(LEFT, t.hit, LEFT, 12, 0)
        t.label:SetHeight(22)
        set_text(t.label, lay.label)
        t.value = P.label(t.hit, S.FONT.small, K.COLOR.text_dim)
        t.value:SetAnchor(RIGHT, t.hit, RIGHT, -4, 0)
        t.value:SetDimensions(70, 22)
        t.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        t.hit:SetHandler("OnMouseUp", function(_, _, upInside)
            if not upInside then return end
            if lay.cycle then
                local cur = Prefs.get(lay.key)
                local idx = 1
                for j, v in ipairs(lay.cycle) do if v == cur then idx = j break end end
                Prefs.set(lay.key, lay.cycle[(idx % #lay.cycle) + 1])
            else
                Prefs.toggle(lay.key)
            end
            Sound.play("nav")
            M.render()
        end)
        t.hit:SetHandler("OnMouseEnter", function() if U.card_show then U.card_show(t.hit, RIGHT, lay.tip) end end)
        t.hit:SetHandler("OnMouseExit", function() if U.card_hide then U.card_hide() end end)
        t.lay = lay
        c.toggles[i] = t
        y = y + 24
    end

    local legendTop = 48 + 30 + #LAYERS * 24 + 6 + 10
    c.legendCard = card(legendTop, 96, "MATCH")
    c.legend = P.label(c.legendCard, S.FONT.small, K.COLOR.text_dim)
    c.legend:SetAnchor(TOPLEFT, c.legendCard, TOPLEFT, 8, 28)
    c.legend:SetAnchor(BOTTOMRIGHT, c.legendCard, BOTTOMRIGHT, -8, -6)
    c.legend:SetVerticalAlignment(TEXT_ALIGN_TOP)

    c.dockHint = P.label(win, S.FONT.small, K.COLOR.text_dim)
    c.dockHint:SetAnchor(BOTTOMLEFT, c.map, BOTTOMRIGHT, PAD, 0)
    c.dockHint:SetDimensions(LEGEND_W, 28)
    c.dockHint:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    c.dockHint:SetAlpha(0.7)

    c.timeLabel = P.label(win, S.FONT.small, K.COLOR.gold)
    c.timeLabel:SetAnchor(BOTTOMLEFT, c.map, BOTTOMLEFT, 0, SCRUB_H)
    c.timeLabel:SetDimensions(80, 16)

    c.slider = BGMeter.zenimax.ui.create_from_virtual(nil, win, "ZO_Slider")
    c.slider:SetAnchor(BOTTOMLEFT, c.map, BOTTOMLEFT, 84, SCRUB_H - 2)
    c.slider:SetHeight(14)
    if c.slider.SetMinMax then c.slider:SetMinMax(0, 1) end
    c.slider:SetHandler("OnValueChanged", function(_, v)
        if state.applying then return end
        M.set_time(v, false)
    end)

    if g.dock == false and (g.x or 0) ~= 0 then undock(g.x, g.y) else dock() end
    built = true
end

local function side_for(w, h)
    return math.max(120, math.min(w - LEGEND_W - 3 * PAD, h - 2 * PAD - SCRUB_H - 6))
end

function M.snap_size()
    local win = c.win
    local side = side_for(win:GetWidth(), win:GetHeight())
    local w, h = side + LEGEND_W + 3 * PAD, side + 2 * PAD + SCRUB_H + 6
    win:SetDimensions(w, h)
    local gg = sv_win()
    gg.w, gg.h = w, h
    return w, h
end

local function layout()
    local win = c.win
    local w, h = win:GetWidth(), win:GetHeight()
    local side = side_for(w, h)
    state.side = side
    c.map:SetDimensions(side, side)
    c.slider:SetWidth(math.max(60, side - 84))
    if W.map_art_path then
        c.art:SetTexture(W.map_art_path)
        c.art:SetHidden(false)
    else
        c.art:SetHidden(true)
    end
    set_text(c.dockHint, state.docked and "docked under the report\ndrag it away to float" or "floating\ndrag it under the report to dock")
end

local function apply_tiles(m)
    local map = m.map
    local nx, ny = (map and map.nx) or 0, (map and map.ny) or 0
    local total = nx * ny
    for i = 1, math.max(total, #c.tiles) do
        local tile = c.tiles[i]
        if i <= total then
            if not tile then
                tile = P.icon(c.map, "")
                if tile.SetDrawLevel then tile:SetDrawLevel(LV.tile) end
                c.tiles[i] = tile
            end
            local col = (i - 1) % nx
            local row = math.floor((i - 1) / nx)
            local tw = state.side / nx
            tile:ClearAnchors()
            tile:SetAnchor(TOPLEFT, c.map, TOPLEFT, col * tw, row * tw)
            tile:SetDimensions(tw + 0.5, tw + 0.5)
            tile:SetTexture(map.tex and map.tex[i] or "")
            tile:SetColor(1, 1, 1, 0.92)
            tile:SetHidden(false)
        elseif tile then
            tile:SetHidden(true)
        end
    end
end

local function mx(v) return v / 1000 * state.side end

local function polyline(xs, ys, n, color, thick, alpha)
    if n < 2 then return end
    if not c.line_pool then
        for i = 1, n do
            local d = c.dot_pool:acquire()
            d:ClearAnchors()
            d:SetAnchor(CENTER, c.map, TOPLEFT, xs[i], ys[i])
            d:SetDimensions(thick + 1, thick + 1)
            P.set_rect_color(d, { color[1], color[2], color[3], alpha })
            d:SetHidden(false)
        end
        return
    end
    for i = 2, n do
        local ln = c.line_pool:acquire()
        ln:ClearAnchors()
        ln:SetAnchor(TOPLEFT, c.map, TOPLEFT, xs[i - 1], ys[i - 1])
        ln:SetAnchor(TOPRIGHT, c.map, TOPLEFT, xs[i], ys[i])
        ln:SetColor(color[1], color[2], color[3], alpha)
        if ln.SetThickness then ln:SetThickness(thick) end
        ln:SetHidden(false)
    end
end

local function scaled(series, upto, smooth)
    local xs, ys = {}, {}
    local n = 0
    if smooth and upto >= 3 then
        local sx, sy = BGMeter.Match.geo_spline(series.x, series.y, upto, 3)
        for i = 1, #sx do xs[i], ys[i] = mx(sx[i]), mx(sy[i]) end
        n = #sx
    else
        for i = 1, upto do xs[i], ys[i] = mx(series.x[i] or 0), mx(series.y[i] or 0) end
        n = upto
    end
    return xs, ys, n
end

local function release_all()
    c.heat_pool:release_all()
    c.dot_pool:release_all()
    if c.line_pool then c.line_pool:release_all() end
    c.icon_pool:release_all()
    c.hit_pool:release_all()
end

local function draw_heat(geo, m, mode)
    local heat, lut
    if mode == "deaths" then
        heat, lut = BGMeter.Match.geo_heat_deaths(geo, m, BINS), EMBER
    else
        heat, lut = BGMeter.Match.geo_heat(geo, m, BINS), VIRIDIS
    end
    if not heat then return end
    local cell = state.side / BINS
    for by = 1, BINS do
        for bx = 1, BINS do
            local v = heat.grid[(by - 1) * BINS + bx]
            if v and v > 0 then
                local u = math.min(1, v / heat.cap)
                local r = c.heat_pool:acquire()
                r:ClearAnchors()
                r:SetAnchor(TOPLEFT, c.map, TOPLEFT, (bx - 1) * cell, (by - 1) * cell)
                r:SetDimensions(cell + 0.5, cell + 0.5)
                local cr, cg, cb = ramp(lut, u)
                P.set_rect_color(r, { cr, cg, cb, 0.12 + 0.70 * u ^ 0.6 })
                r:SetHidden(false)
            end
        end
    end
end

local function draw_paths(geo, m, idx, t)
    local mine = geo.mine
    if Prefs.get("map_team") then
        local tc = S.team_color(m.localTeam)
        for name, s in pairs(geo.pos) do
            if name ~= mine then
                local xs, ys, n = scaled(s, idx, false)
                polyline(xs, ys, n, tc, 1, 0.45)
            end
        end
    end
    if Prefs.get("map_path") then
        local me = geo.me
        local upto = me and BGMeter.Match.geo_index_of(me.t, me.n, t) or idx
        local s = me or (mine and geo.pos[mine])
        if s then
            local xs, ys, n = scaled(s, upto, me ~= nil)
            local tc = S.team_color(m.localTeam)
            polyline(xs, ys, n, tc, 7, 0.40)
            polyline(xs, ys, n, K.COLOR.you, 3, 1)
        end
    end
end

local function draw_deaths(geo, m, t)
    for _, k in ipairs(m.killfeed or {}) do
        if k.x and k.y and k.kind and (k.t or 0) <= t then
            local ic = c.icon_pool:acquire()
            ic:SetTexture(SKULL)
            local col = (k.kind == "kill") and K.COLOR.gold or K.COLOR.accent
            ic:SetColor(col[1], col[2], col[3], 1)
            ic:SetDimensions(18, 18)
            ic:ClearAnchors()
            ic:SetAnchor(CENTER, c.map, TOPLEFT, mx(k.x), mx(k.y))
            ic:SetHidden(false)
            local hit = c.hit_pool:acquire()
            hit:ClearAnchors()
            hit:SetAnchorFill(ic)
            hit:SetHidden(false)
            W.tips[hit] = (k.kind == "kill")
                and string.format("you killed %s  @ %s", tostring(k.dn), F.duration(k.t or 0))
                or string.format("%s killed you  @ %s", tostring(k.kn), F.duration(k.t or 0))
        end
    end
end

local function draw_pins(geo, idx)
    for _, pin in ipairs(geo.pins) do
        local x, y = pin.x[idx], pin.y[idx]
        if x and y and (x > 0 or y > 0) then
            local ic = c.icon_pool:acquire()
            ic:SetTexture(pin_texture(pin.ty[idx], pin.kind))
            ic:SetColor(1, 1, 1, 1)
            ic:SetDimensions(30, 30)
            ic:ClearAnchors()
            ic:SetAnchor(CENTER, c.map, TOPLEFT, mx(x), mx(y))
            ic:SetHidden(false)
            local hit = c.hit_pool:acquire()
            hit:ClearAnchors()
            hit:SetAnchorFill(ic)
            hit:SetHidden(false)
            W.tips[hit] = tostring(pin.name or "objective")
        end
    end
end

local function draw_positions(geo, m, idx, t)
    local mine = geo.mine
    for name, s in pairs(geo.pos) do
        if name ~= mine then
            local x, y = s.x[idx], s.y[idx]
            if x and y then
                local d = c.dot_pool:acquire()
                d:ClearAnchors()
                d:SetAnchor(CENTER, c.map, TOPLEFT, mx(x), mx(y))
                d:SetDimensions(7, 7)
                local col = S.team_color(geo.team[name] or m.localTeam)
                P.set_rect_color(d, { col[1], col[2], col[3], 0.9 })
                d:SetHidden(false)
                local hit = c.hit_pool:acquire()
                hit:ClearAnchors()
                hit:SetAnchorFill(d)
                hit:SetHidden(false)
                W.tips[hit] = name
            end
        end
    end
    local mx_, my_
    if geo.me then
        local i = BGMeter.Match.geo_index_of(geo.me.t, geo.me.n, t)
        mx_, my_ = geo.me.x[i], geo.me.y[i]
    elseif mine and geo.pos[mine] then
        mx_, my_ = geo.pos[mine].x[idx], geo.pos[mine].y[idx]
    end
    if mx_ and my_ then
        local d = c.dot_pool:acquire()
        d:ClearAnchors()
        d:SetAnchor(CENTER, c.map, TOPLEFT, mx(mx_), mx(my_))
        d:SetDimensions(11, 11)
        P.set_rect_color(d, K.COLOR.you)
        d:SetHidden(false)
        local hit = c.hit_pool:acquire()
        hit:ClearAnchors()
        hit:SetAnchorFill(d)
        hit:SetHidden(false)
        W.tips[hit] = "you"
    end
end

function M.render()
    if not built or c.win:IsHidden() then return end
    local m = BGMeter.History.get(W.current_index)
    release_all()
    layout()
    for _, t in ipairs(c.toggles) do
        local lay = t.lay
        local v = Prefs.get(lay.key)
        local on = lay.cycle and (v ~= "off") or (v and true or false)
        t.mark:SetHidden(not on)
        S.color(t.label, on and K.COLOR.text or K.COLOR.text_dim)
        set_text(t.value, lay.cycle and (lay.names[v] or tostring(v)) or (on and "on" or "off"))
    end
    if state.m ~= m then state.t = nil end
    state.m = m
    state.geo = m and BGMeter.Match.geo(m) or nil
    apply_tiles(m or {})
    if not state.geo then
        c.empty:SetHidden(false)
        set_text(c.sub, m and (m.name or "Battleground") or "")
        set_text(c.legend, "")
        set_text(c.timeLabel, "")
        c.slider:SetHidden(true)
        return
    end
    c.empty:SetHidden(true)
    c.slider:SetHidden(false)
    local geo = state.geo
    local tspan = geo.t[geo.n] or 1
    if state.t == nil then state.t = tspan end
    if state.t > tspan then state.t = tspan end
    state.applying = true
    if c.slider.SetMinMax then c.slider:SetMinMax(0, tspan) end
    c.slider:SetValue(state.t)
    state.applying = false
    local idx = BGMeter.Match.geo_index(geo, state.t)
    set_text(c.sub, string.format("%s  ·  %s", m.name or "Battleground", m.map and m.map.name or ""))
    local hm = Prefs.get("map_heat_mode")
    if hm ~= "off" then draw_heat(geo, m, hm) end
    draw_paths(geo, m, idx, state.t)
    if Prefs.get("map_deaths") then draw_deaths(geo, m, state.t) end
    if Prefs.get("map_pins") then draw_pins(geo, idx) end
    draw_positions(geo, m, idx, state.t)
    set_text(c.timeLabel, "t " .. F.duration(state.t))
    local tc = S.team_color(m.localTeam)
    set_text(c.legend, string.format("|c%s%s|r  ·  %d teammates tracked\n%d samples every %d s%s\ndrag the slider or hover the timeline chart\nto move through the match",
        hexc(tc), team_name(m.localTeam), geo.teammates, geo.n, math.floor((geo.stepMs or 3000) / 1000),
        geo.me and ", your path every second" or ""))
end

function M.set_time(t, from_chart)
    if not built or c.win:IsHidden() or not state.geo then return end
    local tspan = state.geo.t[state.geo.n] or 1
    t = math.max(0, math.min(tspan, t or tspan))
    if math.abs(t - (state.t or -1)) < 250 then return end
    state.t = t
    if from_chart then
        state.applying = true
        c.slider:SetValue(t)
        state.applying = false
    end
    M.render()
end

function M.time() return state.t end
function M.is_docked() return state.docked end

function M.open()
    build()
    if not W.win or W.win:IsHidden() then return end
    c.win:SetHidden(false)
    sv_win().open = true
    state.t = nil
    M.render()
    Sound.play("menu")
end

function M.close(silent)
    if not built or c.win:IsHidden() then return end
    c.win:SetHidden(true)
    sv_win().open = false
    if not silent then Sound.play("close") end
end

function M.toggle()
    build()
    if c.win:IsHidden() then M.open() else M.close() end
end

function M.is_open() return built and not c.win:IsHidden() end

function M.on_report_render()
    if not built or c.win:IsHidden() then return end
    M.render()
end

function M.on_report_hidden()
    if built and not c.win:IsHidden() then c.win:SetHidden(true) end
end

function M.on_report_shown()
    build()
    if sv_win().open then
        c.win:SetHidden(false)
        state.t = nil
        M.render()
    end
end

function M.on_move_stop() on_move_stop() end

function M.controls() return c end

BGMeter.UI.map = M
