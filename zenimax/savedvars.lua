-- bgmeter :: zenimax/savedvars.lua
-- ZO_SavedVars wrapper. bgmeter persists a rolling history of matches plus
-- window position and user prefs. Account-wide (not per-character) so your
-- BG history follows you across alts; per-server split so EU/NA/PTS don't mix.

BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.zenimax = BGMeter.zenimax or {}

local M = {}

-- Defaults shape -- see core/history.lua and ui/window.lua for the consumers.
local DEFAULTS = {
    version  = 1,
    matches  = {},        -- ring of recent match records (newest first)
    standing = { rank = 0, score = 0 },  -- last-seen competitive rank/score (for up/down diff)
    records  = {          -- personal bests across all matches (for the ★ markers)
        damage = 0, healing = 0, kills = 0, ap = 0, bestRank = 0,
    },
    window   = { x = 0, y = 0, w = 0, h = 0, hidden = true, scale = 1.0 },
    launcher = { x = 0, y = 0 },
    prefs    = {
        max_history    = 50,
        auto_open_mode = "exit",
        sounds         = true,
        animate        = true,
        show_haul      = true,
        show_veterancy = true,
        show_standing  = true,
        show_awards    = true,
        show_timeline  = true,
        show_launcher  = true,
        opacity        = 0.97,
        sort_key       = "damage",
        sort_desc      = true,
    },
}

-- saved_var_name: the global declared in the manifest's ## SavedVariables.
function M.init(saved_var_name, version)
    -- Account-wide + per-server: the `profile` argument (GetWorldName) is the
    -- documented way to split EU/NA/PTS so histories never bleed across servers.
    local sv = ZO_SavedVars:NewAccountWide(saved_var_name, version, nil, DEFAULTS, GetWorldName())
    sv.vanguard = nil
    M.data = sv
    return sv
end

function M.get() return M.data end

BGMeter.zenimax.savedvars = M
