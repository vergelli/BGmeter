-- bgmeter :: lib/plot/style.lua
-- Fonts and colour helpers shared by every drawn control. Colours live in
-- core/constants K.COLOR; this module is just the application helpers + fonts.

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
    banner  = "ZoFontWinH1",   -- big VICTORY / DEFEAT banner
}

-- Apply an RGBA array {r,g,b,a} to a label/texture.
function S.color(control, rgba)
    if not control or not rgba then return end
    control:SetColor(rgba[1], rgba[2], rgba[3], rgba[4] or 1)
end

-- Resolve a colour by core/constants key name ("accent", "heal", ...).
function S.named(key)
    return BGMeter.Constants.COLOR[key]
end

-- Team tint for a BattlegroundTeam enum value.
function S.team_color(team)
    local C = BGMeter.zenimax.constants
    local COL = BGMeter.Constants.COLOR.team
    if team == C.BATTLEGROUND_TEAM_FIRE_DRAKES then return COL.fire end
    if team == C.BATTLEGROUND_TEAM_PIT_DAEMONS then return COL.pit end
    if team == C.BATTLEGROUND_TEAM_STORM_LORDS then return COL.storm end
    return BGMeter.Constants.COLOR.text_dim
end

BGMeter.Plot.style = S
