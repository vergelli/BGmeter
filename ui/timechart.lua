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
    self.n, self.cols, self.drawn, self.smax, self.tspan = 0, 0, 0, 0, 0
    self.series, self.teams, self.col = {}, {}, {}
    self.t = nil
    return self
end

function TC:set_series(tl)
    self.tl = tl
    local n = (tl and tl.t) and #tl.t or 0
    self.n = n
    self.series[1], self.series[2], self.series[3] = tl and tl.s1, tl and tl.s2, tl and tl.s3
    self.teams = (tl and tl.teams) or {}
    local smax = 0
    for s = 1, MAX_SERIES do
        local arr = self.series[s]
        if arr and self.teams[s] then
            for i = 1, n do
                local v = arr[i] or 0
                if v > smax then smax = v end
            end
        end
    end
    self.smax = smax
    self.tspan = (n > 0 and tl.t[n]) or 0
    self:reset()
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
    if n < 2 or plot_w < 2 or self.tspan <= 0 or self.smax <= 0 then self.cols = 0 return end
    local t, col = self.tl.t, self.col
    local i = 1
    for x = 0, plot_w do
        local tx = (x / plot_w) * self.tspan
        while i < n and (t[i + 1] or 0) <= tx do i = i + 1 end
        col[x + 1] = i
    end
    self.cols = plot_w + 1
end

local function y_of(self, s, idx)
    local v = (self.series[s] and self.series[s][idx]) or 0
    return math.floor((1 - v / self.smax) * (self.h - 1) + 0.5)
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
        for s = 1, MAX_SERIES do
            local team = self.teams[s]
            if team and self.series[s] then
                seg(self, x - 1, y_of(self, s, self.col[x]), x, y_of(self, s, self.col[x + 1]), S.team_color(team))
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
    for s = 1, MAX_SERIES do
        local team = self.teams[s]
        if team and self.series[s] then
            local tc = S.team_color(team)
            text = text .. ((text ~= "") and "  " or "") .. string.format("|c%s%d|r", F.hexc(tc), math.floor((self.series[s][idx] or 0) + 0.5))
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
    local nteams = 0
    for s = 1, MAX_SERIES do if self.teams[s] and self.series[s] then nteams = nteams + 1 end end
    return xT * nteams
end

BGMeter.UI.timechart = TC
