BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local K = BGMeter.Constants
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local F = BGMeter.Format

local TC = {}
TC.__index = TC

local MAX_SERIES = 3

function TC.new(parent, label)
    local self = setmetatable({}, TC)
    self.root = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL)
    self.bg = P.rect(self.root, { 0, 0, 0, 0.35 })
    self.bg:SetAnchorFill(self.root)
    local probe = P.line(self.root, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        self.line_pool = BGMeter.Plot.pool.new(
            function() return P.line(self.root, { 1, 1, 1, 1 }, 2) end,
            function(ln) ln:SetHidden(true); ln:ClearAnchors() end)
        self.line_pool.label = label .. ".lines"
    end
    self.dot_pool = BGMeter.Plot.pool.new(
        function() return P.rect(self.root, { 1, 1, 1, 1 }) end,
        function(r) r:SetHidden(true); r:ClearAnchors() end)
    self.dot_pool.label = label .. ".dots"
    self.cursor = P.rect(self.root, { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.8 })
    self.cursor:SetWidth(1)
    self.cursor:SetHidden(true)
    self.legend = P.label(self.root, S.FONT.small, K.COLOR.text)
    self.legend:SetAnchor(TOPRIGHT, self.root, TOPRIGHT, -3, 1)
    self.legend:SetHeight(12)
    self.legend:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.w, self.h = 0, 0
    self.n, self.cols, self.drawn, self.max, self.tspan = 0, 0, 0, 0, 0
    self.series, self.col = {}, {}
    self.nseries = 0
    self.t = nil
    return self
end

function TC:set_data(data)
    self.data = data
    local n = (data and data.t) and (data.n or #data.t) or 0
    self.n = n
    self.nseries = 0
    for s = 1, MAX_SERIES do
        local src = data and data.series and data.series[s]
        self.series[s] = src
        if src then self.nseries = s end
    end
    self.max = (data and data.max) or 0
    self.tspan = (n > 0 and data.t[n]) or 0
    self.fmt = data and data.fmt or nil
    self:reset()
end

function TC:set_series(tl)
    if not tl or not tl.t or not tl.teams then self:set_data(nil) return end
    local series, max = {}, 0
    local arrays = { tl.s1, tl.s2, tl.s3 }
    for s = 1, MAX_SERIES do
        local team, arr = tl.teams[s], arrays[s]
        if team and arr then
            series[#series + 1] = { values = arr, color = S.team_color(team) }
            for i = 1, #tl.t do
                local v = arr[i] or 0
                if v > max then max = v end
            end
        end
    end
    self:set_data({ n = #tl.t, t = tl.t, series = series, max = max })
end

function TC:layout(w, h)
    if w == self.w and h == self.h then return end
    self.w, self.h = w, h
    self.root:SetDimensions(w, h)
    self:reset()
end

local function release(self)
    if self.line_pool then self.line_pool:release_all() end
    self.dot_pool:release_all()
    self.drawn = 0
end

function TC:reset()
    release(self)
    self.t = nil
    self.cursor:SetHidden(true)
    self.legend:SetText("")
    local n, plot_w = self.n, self.w - 1
    if n < 2 or plot_w < 2 or self.tspan <= 0 or self.max <= 0 or self.nseries == 0 then self.cols = 0 return end
    local t, col = self.data.t, self.col
    local i = 1
    for x = 0, plot_w do
        local tx = (x / plot_w) * self.tspan
        while i < n and (t[i + 1] or 0) <= tx do i = i + 1 end
        col[x + 1] = i
    end
    self.cols = plot_w + 1
end

local function y_of(self, s, idx)
    local v = (self.series[s].values[idx]) or 0
    return math.floor((1 - v / self.max) * (self.h - 1) + 0.5)
end

local function seg(self, x0, y0, x1, y1, tc)
    if self.line_pool then
        local ln = self.line_pool:acquire()
        ln:ClearAnchors()
        ln:SetAnchor(TOPLEFT, self.root, TOPLEFT, x0, y0)
        ln:SetAnchor(TOPRIGHT, self.root, TOPLEFT, x1, y1)
        ln:SetColor(tc[1], tc[2], tc[3], 0.9)
        ln:SetHidden(false)
    else
        local dot = self.dot_pool:acquire()
        dot:ClearAnchors()
        dot:SetAnchor(TOPLEFT, self.root, TOPLEFT, x1, y1)
        dot:SetDimensions(2, 2)
        P.set_rect_color(dot, { tc[1], tc[2], tc[3], 0.9 })
        dot:SetHidden(false)
    end
end

local function draw_to(self, xT)
    for x = self.drawn + 1, xT do
        for s = 1, self.nseries do
            local sr = self.series[s]
            if sr then
                seg(self, x - 1, y_of(self, s, self.col[x]), x, y_of(self, s, self.col[x + 1]), sr.color)
            end
        end
    end
    if xT > self.drawn then self.drawn = xT end
end

function TC:set_time(t)
    if self.cols == 0 then return end
    local plot_w = self.cols - 1
    t = math.max(0, math.min(self.tspan, t or self.tspan))
    local xT = math.floor(t / self.tspan * plot_w + 0.5)
    if xT < self.drawn then release(self) end
    draw_to(self, xT)
    self.t = t
    self.cursor:ClearAnchors()
    self.cursor:SetAnchor(TOPLEFT, self.root, TOPLEFT, xT, 0)
    self.cursor:SetHeight(self.h)
    self.cursor:SetHidden(false)
    local idx = self.col[xT + 1] or 1
    local text = ""
    for s = 1, self.nseries do
        local sr = self.series[s]
        if sr then
            local v = sr.values[idx] or 0
            local shown = self.fmt and self.fmt(v) or tostring(math.floor(v + 0.5))
            text = text .. ((text ~= "") and "  " or "") .. string.format("|c%s%s|r", F.hexc(sr.color), shown)
        end
    end
    self.legend:SetText(text)
end

function TC:count()
    return (self.line_pool and self.line_pool:active_count() or 0) + self.dot_pool:active_count()
end

function TC:segments_at(t)
    if self.cols == 0 then return 0 end
    local plot_w = self.cols - 1
    t = math.max(0, math.min(self.tspan, t or self.tspan))
    local xT = math.floor(t / self.tspan * plot_w + 0.5)
    local k = 0
    for s = 1, self.nseries do if self.series[s] then k = k + 1 end end
    return xT * k
end

BGMeter.UI.timechart = TC
