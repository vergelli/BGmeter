-- bgmeter :: core/match.lua
-- The Match data model -- the single record that flows from capture -> history
-- -> UI. A Match has two faces:
--   .battle  the scoreboard (every player's combat: dmg/heal/K/D/A/score/medals)
--   .haul    the local player's progression earned this match (AP/XP/CP/veterancy)
-- This module owns the shape and the derivations; it does no I/O and no API
-- reads (capture.lua feeds it). Records are plain tables -> trivially saveable.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Match = {}

-- A fresh, empty record. capture.lua fills it across the match lifecycle.
function Match.new()
    return {
        -- meta
        bgId       = nil,
        name       = nil,        -- battleground display name
        gameType   = nil,        -- BattlegroundGameType enum
        startMs    = nil,
        endMs      = nil,
        durationMs = 0,
        result     = nil,        -- "WIN" | "LOSS" | "TIE" | nil
        localTeam  = nil,
        capturedAt = nil,        -- wall-clock (GetTimeStamp) for history labels
        standing   = nil,        -- competitive leaderboard standing (filled async; see core/standing)

        -- face 1: the battle
        battle = {},             -- array of player rows (see Match.new_row)

        -- face 2: the haul (local player's progression)
        haul = {
            apGained   = 0,
            xpGained   = 0,
            cpGained   = 0,
            medals     = 0,      -- count of medals the local player earned
            vetStart   = nil,    -- veterancy snapshot at match start
            vetEnd     = nil,    -- veterancy snapshot at match end
            vetRankUp  = false,  -- did a reward-track tier increase fire?
            -- derived (filled by Match.derive):
            apPerMin   = 0,
            apPerKill  = 0,
            xpPerMin   = 0,
        },
    }
end

function Match.new_row()
    return {
        charName    = nil,
        displayName = nil,
        team        = nil,
        classId     = nil,
        isLocal     = false,
        damage      = 0,
        healing     = 0,
        kills       = 0,
        deaths      = 0,
        assists     = 0,
        score       = 0,
        lives       = nil,
        medals      = 0,
    }
end

-- Return the local player's row, or nil.
function Match.local_row(m)
    for _, row in ipairs(m.battle) do
        if row.isLocal then return row end
    end
    return nil
end

-- Sort the battle rows by a column key, descending by default. Stable-ish:
-- ties fall back to damage so the table doesn't jitter between renders.
function Match.sort(m, key, desc)
    if desc == nil then desc = true end
    table.sort(m.battle, function(a, b)
        local av, bv = a[key] or 0, b[key] or 0
        if av == bv then return (a.damage or 0) > (b.damage or 0) end
        if desc then return av > bv end
        return av < bv
    end)
end

-- The max value of a column across rows -- used to scale the meter bars.
function Match.column_max(m, key)
    local max = 0
    for _, row in ipairs(m.battle) do
        local v = row[key] or 0
        if v > max then max = v end
    end
    return max
end

-- Fill the derived haul rates once startMs/endMs and the local row are known.
function Match.derive(m)
    m.durationMs = (m.endMs and m.startMs) and math.max(0, m.endMs - m.startMs) or m.durationMs
    local h = m.haul
    local F = BGMeter.Format
    h.apPerMin = math.floor(F.per_minute(h.apGained, m.durationMs) + 0.5)
    h.xpPerMin = math.floor(F.per_minute(h.xpGained, m.durationMs) + 0.5)
    local lr = Match.local_row(m)
    local kills = lr and lr.kills or 0
    h.apPerKill = (kills > 0) and math.floor(h.apGained / kills + 0.5) or 0
    return m
end

BGMeter.Match = Match
