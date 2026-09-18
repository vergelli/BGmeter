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
local SKULL = "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds"
local FALLBACK_PIN = "EsoUI/Art/MapPins/battlegrounds_murderball_neutral.dds"
local FALLBACK_AREA = "EsoUI/Art/MapPins/battlegrounds_capturePoint_pin_neutral.dds"

local LAYERS = {
    { key = "map_heat",   label = "Heat",       tip = "Where your team spent its time.\nBrighter = more presence." },
    { key = "map_path",   label = "Your path",  tip = "Where you went, in gold, up to the scrubbed second." },
    { key = "map_team",   label = "Team paths", tip = "Your teammates' paths, faint, in the team colour." },
    { key = "map_deaths", label = "Deaths",     tip = "Red skull = where you died  ·  gold skull = where you got a kill." },
    { key = "map_pins",   label = "Objectives", tip = "Flags, relics and balls where they were at the scrubbed second." },
}

local built = false
local c = nil
local state = { m = nil, geo = nil, t = nil, side = 0, applying = false }

local function sv_map()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return {} end
    sv.window = sv.window or {}
    return sv.window
end

local function pin_texture(ty, kind)
    local data = ZO_MapPin and ZO_MapPin.PIN_DATA and ty and ZO_MapPin.PIN_DATA[ty]
    if data and data.texture then return data.texture end
    if kind == "area" then return FALLBACK_AREA end
    return FALLBACK_PIN
end

local function rect_pool(parent)
    return BGMeter.Plot.pool.new(
        function() return P.rect(parent, { 1, 1, 1, 1 }) end,
        function(r) r:SetHidden(true); r:ClearAnchors() end)
end

local function icon_pool(parent)
    return BGMeter.Plot.pool.new(
        function() return P.icon(parent, "") end,
        function(ic) ic:SetHidden(true); ic:ClearAnchors() end)
end

local function build()
    if built then return end
    local wm = BGMeter.zenimax.ui.wm
    local win = wm:CreateTopLevelWindow("BGMeterMapPanel")
    win:SetDimensions(L.window_w, L.map_h)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetDrawTier(DT_HIGH)
    Scene.register_top_level(win, function() M.close() end)
    c = { win = win }

    c.bg = P.rect(win, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.97 })
    c.bg:SetAnchorFill(win)
    P.frame(win):SetAnchorFill(win)
    local strip = P.rect(win, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    c.map = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    c.map:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, PAD)
    c.map:SetMouseEnabled(true)
    c.mapBg = P.rect(c.map, { 0, 0, 0, 0.6 })
    c.mapBg:SetAnchorFill(c.map)
    c.tiles = {}
    c.tileLayer = BGMeter.zenimax.ui.create_control(nil, c.map, CT_CONTROL)
    c.tileLayer:SetAnchorFill(c.map)
    c.heatLayer = BGMeter.zenimax.ui.create_control(nil, c.map, CT_CONTROL)
    c.heatLayer:SetAnchorFill(c.map)
    c.pathLayer = BGMeter.zenimax.ui.create_control(nil, c.map, CT_CONTROL)
    c.pathLayer:SetAnchorFill(c.map)
    c.markLayer = BGMeter.zenimax.ui.create_control(nil, c.map, CT_CONTROL)
    c.markLayer:SetAnchorFill(c.map)
    c.heat_pool = rect_pool(c.heatLayer)
    c.dot_pool = rect_pool(c.markLayer)
    local probe = P.line(c.pathLayer, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        c.line_pool = BGMeter.Plot.pool.new(
            function() return P.line(c.pathLayer, { 1, 1, 1, 1 }, 2) end,
            function(ln) ln:SetHidden(true); ln:ClearAnchors() end)
    end
    c.icon_pool = icon_pool(c.markLayer)
    c.hit_pool = BGMeter.Plot.pool.new(
        function()
            local h = BGMeter.zenimax.ui.create_control(nil, c.markLayer, CT_CONTROL)
            W.tip_dynamic(h)
            return h
        end,
        function(h) h:SetHidden(true); h:ClearAnchors(); W.tips[h] = nil end)
    c.mapBox = P.hairline_box(c.map, { K.COLOR.text_dim[1], K.COLOR.text_dim[2], K.COLOR.text_dim[3], K.ALPHA.chart_edge })

    c.empty = P.label(c.map, S.FONT.small, K.COLOR.text_dim)
    c.empty:SetAnchor(CENTER, c.map, CENTER, 0, 0)
    c.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.empty:SetText("no map data for this match\nmatches recorded from 0.4.0 on carry positions")
    c.empty:SetHidden(true)

    c.title = P.label(win, S.FONT.title, K.COLOR.text)
    c.title:SetText("MAP")
    c.title:SetAnchor(TOPLEFT, c.map, TOPRIGHT, PAD, -4)
    c.sub = P.label(win, S.FONT.small, K.COLOR.text_dim)
    U.clamp_line(c.sub)
    c.sub:SetAnchor(TOPLEFT, c.title, BOTTOMLEFT, 0, 2)
    c.sub:SetDimensions(LEGEND_W, 14)

    c.close = mk_button(win, TX.close, 20, function() M.close() end, "Close")
    c.close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -14, 14)

    c.toggles = {}
    local y = 52
    for i, lay in ipairs(LAYERS) do
        local t = {}
        t.hit = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
        t.hit:SetAnchor(TOPLEFT, c.map, TOPRIGHT, PAD, y)
        t.hit:SetDimensions(LEGEND_W, 22)
        t.hit:SetMouseEnabled(true)
        t.mark = P.rect(t.hit, K.COLOR.accent)
        t.mark:SetAnchor(LEFT, t.hit, LEFT, 0, 0)
        t.mark:SetDimensions(3, 14)
        t.label = P.label(t.hit, S.FONT.row, K.COLOR.text)
        t.label:SetAnchor(LEFT, t.hit, LEFT, 12, 0)
        t.label:SetAnchor(RIGHT, t.hit, RIGHT, 0, 0)
        t.label:SetHeight(22)
        set_text(t.label, lay.label)
        t.hit:SetHandler("OnMouseUp", function(_, _, upInside)
            if upInside then
                Prefs.toggle(lay.key)
                Sound.play("nav")
                M.render()
            end
        end)
        t.hit:SetHandler("OnMouseEnter", function() if U.card_show then U.card_show(t.hit, RIGHT, lay.tip) end end)
        t.hit:SetHandler("OnMouseExit", function() if U.card_hide then U.card_hide() end end)
        t.key = lay.key
        c.toggles[i] = t
        y = y + 24
    end

    c.legend = P.label(win, S.FONT.small, K.COLOR.text_dim)
    c.legend:SetAnchor(TOPLEFT, c.map, TOPRIGHT, PAD, y + 8)
    c.legend:SetDimensions(LEGEND_W, 120)
    c.legend:SetVerticalAlignment(TEXT_ALIGN_TOP)

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

    built = true
end

local function layout()
    local win = c.win
    local w = W.win and W.win:GetWidth() or L.window_w
    win:SetWidth(w)
    local side = L.map_h - 2 * PAD - SCRUB_H - 6
    state.side = side
    c.map:SetDimensions(side, side)
    c.slider:SetWidth(math.max(60, side - 84))
    win:ClearAnchors()
    if W.win then
        win:SetAnchor(TOPLEFT, W.win, BOTTOMLEFT, 0, 4)
    else
        win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
end

local function apply_tiles(m)
    local map = m.map
    local nx, ny = (map and map.nx) or 0, (map and map.ny) or 0
    local total = nx * ny
    for i = 1, math.max(total, #c.tiles) do
        local tile = c.tiles[i]
        if i <= total then
            if not tile then
                tile = P.icon(c.tileLayer, "")
                c.tiles[i] = tile
            end
            local col = (i - 1) % nx
            local row = math.floor((i - 1) / nx)
            local tw = state.side / nx
            tile:ClearAnchors()
            tile:SetAnchor(TOPLEFT, c.tileLayer, TOPLEFT, col * tw, row * tw)
            tile:SetDimensions(tw + 0.5, tw + 0.5)
            tile:SetTexture(map.tex and map.tex[i] or "")
            tile:SetColor(1, 1, 1, 0.92)
            tile:SetHidden(false)
        elseif tile then
            tile:SetHidden(true)
        end
    end
end

local function mx(v) return math.floor(v / 1000 * state.side + 0.5) end

local function polyline(px, py, n, color, thick, alpha)
    if not c.line_pool then
        for i = 1, n do
            local d = c.dot_pool:acquire()
            d:ClearAnchors()
            d:SetAnchor(CENTER, c.pathLayer, TOPLEFT, px(i), py(i))
            d:SetDimensions(thick + 1, thick + 1)
            P.set_rect_color(d, { color[1], color[2], color[3], alpha })
            d:SetHidden(false)
        end
        return
    end
    for i = 2, n do
        local ln = c.line_pool:acquire()
        ln:ClearAnchors()
        ln:SetAnchor(TOPLEFT, c.pathLayer, TOPLEFT, px(i - 1), py(i - 1))
        ln:SetAnchor(TOPRIGHT, c.pathLayer, TOPLEFT, px(i), py(i))
        ln:SetColor(color[1], color[2], color[3], alpha)
        if ln.SetThickness then ln:SetThickness(thick) end
        ln:SetHidden(false)
    end
end

local function release_all()
    c.heat_pool:release_all()
    c.dot_pool:release_all()
    if c.line_pool then c.line_pool:release_all() end
    c.icon_pool:release_all()
    c.hit_pool:release_all()
end

local function draw_heat(geo, m)
    local heat = BGMeter.Match.geo_heat(geo, m, BINS)
    if not heat then return end
    local cell = state.side / BINS
    local tc = S.team_color(m.localTeam)
    for by = 1, BINS do
        for bx = 1, BINS do
            local v = heat.grid[(by - 1) * BINS + bx]
            if v and v > 0 then
                local r = c.heat_pool:acquire()
                r:ClearAnchors()
                r:SetAnchor(TOPLEFT, c.heatLayer, TOPLEFT, (bx - 1) * cell, (by - 1) * cell)
                r:SetDimensions(cell + 0.5, cell + 0.5)
                local a = 0.10 + 0.60 * (v / heat.max) ^ 0.6
                P.set_rect_color(r, { tc[1], tc[2], tc[3], a })
                r:SetHidden(false)
            end
        end
    end
end

local function draw_paths(geo, m, upto)
    local mine = geo.mine
    if Prefs.get("map_team") then
        local tc = S.team_color(m.localTeam)
        for name, s in pairs(geo.pos) do
            if name ~= mine and geo.team[name] == m.localTeam then
                polyline(function(i) return mx(s.x[i]) end, function(i) return mx(s.y[i]) end, upto, tc, 1, 0.35)
            end
        end
    end
    if Prefs.get("map_path") and mine and geo.pos[mine] then
        local s = geo.pos[mine]
        polyline(function(i) return mx(s.x[i]) end, function(i) return mx(s.y[i]) end, upto, K.COLOR.you, 4, 0.18)
        polyline(function(i) return mx(s.x[i]) end, function(i) return mx(s.y[i]) end, upto, K.COLOR.you, 2, 0.95)
    end
end

local function draw_deaths(geo, m, t)
    for _, k in ipairs(m.killfeed or {}) do
        if k.x and k.y and k.kind and (k.t or 0) <= t then
            local ic = c.icon_pool:acquire()
            ic:SetTexture(SKULL)
            local col = (k.kind == "kill") and K.COLOR.gold or K.COLOR.accent
            ic:SetColor(col[1], col[2], col[3], 0.95)
            ic:SetDimensions(16, 16)
            ic:ClearAnchors()
            ic:SetAnchor(CENTER, c.markLayer, TOPLEFT, mx(k.x), mx(k.y))
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
            ic:SetDimensions(28, 28)
            ic:ClearAnchors()
            ic:SetAnchor(CENTER, c.markLayer, TOPLEFT, mx(x), mx(y))
            ic:SetHidden(false)
            local hit = c.hit_pool:acquire()
            hit:ClearAnchors()
            hit:SetAnchorFill(ic)
            hit:SetHidden(false)
            W.tips[hit] = tostring(pin.name or "objective")
        end
    end
end

local function draw_positions(geo, m, idx)
    local mine = geo.mine
    for name, s in pairs(geo.pos) do
        local x, y = s.x[idx], s.y[idx]
        if x and y then
            local me = (name == mine)
            local d = c.dot_pool:acquire()
            d:ClearAnchors()
            d:SetAnchor(CENTER, c.markLayer, TOPLEFT, mx(x), mx(y))
            d:SetDimensions(me and 9 or 6, me and 9 or 6)
            local col = me and K.COLOR.you or S.team_color(geo.team[name] or m.localTeam)
            P.set_rect_color(d, { col[1], col[2], col[3], me and 1 or 0.85 })
            d:SetHidden(false)
            local hit = c.hit_pool:acquire()
            hit:ClearAnchors()
            hit:SetAnchorFill(d)
            hit:SetHidden(false)
            W.tips[hit] = me and "you" or name
        end
    end
end

function M.render()
    if not built or c.win:IsHidden() then return end
    local m = BGMeter.History.get(W.current_index)
    release_all()
    layout()
    for _, t in ipairs(c.toggles) do
        local on = Prefs.get(t.key)
        t.mark:SetHidden(not on)
        S.color(t.label, on and K.COLOR.text or K.COLOR.text_dim)
    end
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
    if state.t == nil or state.m ~= m then state.t = tspan end
    if state.t > tspan then state.t = tspan end
    state.applying = true
    if c.slider.SetMinMax then c.slider:SetMinMax(0, tspan) end
    c.slider:SetValue(state.t)
    state.applying = false
    local idx = BGMeter.Match.geo_index(geo, state.t)
    set_text(c.sub, string.format("%s  ·  %s", m.name or "Battleground", m.map and m.map.name or ""))
    if Prefs.get("map_heat") then draw_heat(geo, m) end
    draw_paths(geo, m, idx)
    if Prefs.get("map_deaths") then draw_deaths(geo, m, state.t) end
    if Prefs.get("map_pins") then draw_pins(geo, idx) end
    draw_positions(geo, m, idx)
    set_text(c.timeLabel, "t " .. F.duration(state.t))
    local tc = S.team_color(m.localTeam)
    set_text(c.legend, string.format("|c%s%s|r  ·  %d teammates tracked\n%d samples every %d s\ndrag the slider or hover the timeline chart\nto move through the match",
        hexc(tc), team_name(m.localTeam), geo.teammates, geo.n, math.floor((geo.stepMs or 3000) / 1000)))
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

function M.open()
    build()
    if not W.win or W.win:IsHidden() then return end
    c.win:SetHidden(false)
    sv_map().map_open = true
    state.t = nil
    M.render()
    Sound.play("menu")
end

function M.close(silent)
    if not built or c.win:IsHidden() then return end
    c.win:SetHidden(true)
    sv_map().map_open = false
    if not silent then Sound.play("close") end
end

function M.toggle()
    build()
    if c.win:IsHidden() then M.open() else M.close() end
end

function M.is_open() return built and not c.win:IsHidden() end

function M.on_report_render()
    if not built then return end
    if c.win:IsHidden() then return end
    state.t = nil
    M.render()
end

function M.on_report_hidden()
    if built and not c.win:IsHidden() then c.win:SetHidden(true) end
end

function M.on_report_shown()
    build()
    if sv_map().map_open then
        c.win:SetHidden(false)
        state.t = nil
        M.render()
    end
end

function M.controls() return c end

BGMeter.UI.map = M
