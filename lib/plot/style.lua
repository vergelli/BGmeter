
BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.Plot = BGMeter.Plot or {}

local S = {}

S.FONT = {
    row     = "ZoFontGame",
    header  = "ZoFontWinH4",
    big     = "ZoFontWinT1",
    small   = "ZoFontGameSmall",
    title   = "ZoFontWinH2",
    banner  = "ZoFontWinH1",
}

function S.color(control, rgba)
    if not control or not rgba then return end
    control:SetColor(rgba[1], rgba[2], rgba[3], rgba[4] or 1)
end

function S.named(key)
    return BGMeter.Constants.COLOR[key]
end

local RAMP_N = 32
local ramps = {}

local function mix(a, b, f)
    return { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f }
end

function S.team_ramp(team, level)
    local base = S.team_color(team)
    local lut = ramps[base]
    if not lut then
        lut = {}
        local dark = { base[1] * 0.22, base[2] * 0.20, base[3] * 0.24 }
        local bright = mix(base, { 1, 1, 1 }, 0.45)
        local hot = { 0.99, 0.96, 0.88 }
        for i = 0, RAMP_N - 1 do
            local f = i / (RAMP_N - 1)
            local c
            if f < 0.45 then c = mix(dark, base, f / 0.45)
            elseif f < 0.80 then c = mix(base, bright, (f - 0.45) / 0.35)
            else c = mix(bright, hot, (f - 0.80) / 0.20) end
            c[4] = 0.30 + 0.70 * math.min(1, f / 0.25)
            lut[i] = c
        end
        ramps[base] = lut
    end
    if level < 0 then level = 0 end
    if level > 1 then level = 1 end
    return lut[math.floor(level * (RAMP_N - 1) + 0.5)]
end

function S.team_color(team)
    local C = BGMeter.zenimax.constants
    local COL = BGMeter.Constants.COLOR.team
    if team == C.BATTLEGROUND_TEAM_FIRE_DRAKES then return COL.fire end
    if team == C.BATTLEGROUND_TEAM_PIT_DAEMONS then return COL.pit end
    if team == C.BATTLEGROUND_TEAM_STORM_LORDS then return COL.storm end
    return BGMeter.Constants.COLOR.text_dim
end

function S.team_art_key(team)
    local C = BGMeter.zenimax.constants
    if team == C.BATTLEGROUND_TEAM_FIRE_DRAKES then return "orange" end
    if team == C.BATTLEGROUND_TEAM_PIT_DAEMONS then return "green" end
    if team == C.BATTLEGROUND_TEAM_STORM_LORDS then return "purple" end
    return "neutral"
end

BGMeter.Plot.style = S
