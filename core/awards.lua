-- bgmeter :: core/awards.lua
-- Standout detection for the battle table. Deliberately restrained (the user
-- asked for least-intrusive): one overall MVP crown, plus per-column leaders
-- that the table tints gold. No clutter of badges on every row.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Awards = {}

local LEADER_FIELDS = { "damage", "healing", "kills", "assists", "caps", "carried" }

-- Returns { leaders = { field -> prow }, mvp = prow }.
-- MVP is a weighted blend so a pure healer or a kill-heavy player can still win,
-- not just raw damage. Weights are in damage-equivalent points.
function Awards.compute(m)
    local leaders = {}
    for _, f in ipairs(LEADER_FIELDS) do
        local best, row = 0, nil
        for _, r in ipairs(m.battle) do
            local v = r[f] or 0
            if v > best then best, row = v, r end
        end
        if best > 0 then leaders[f] = row end
    end

    local mvp, mvpScore = nil, -1
    for _, r in ipairs(m.battle) do
        local s = (r.damage or 0)
                + (r.healing or 0) * 0.8
                + (r.kills or 0) * 8000
                + (r.assists or 0) * 2000
                - (r.deaths or 0) * 3000
        if s > mvpScore then mvpScore, mvp = s, r end
    end

    return { leaders = leaders, mvp = mvp }
end

BGMeter.Awards = Awards
