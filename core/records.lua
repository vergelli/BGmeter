-- bgmeter :: core/records.lua
-- Personal bests across all matches, persisted in sv.records. When you beat one
-- this match, the result window shows a ★ next to that figure -- a small, very
-- personal reward loop that fits a tool you built for yourself.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Records = {}

local function store()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return nil end
    sv.records = sv.records or { damage = 0, healing = 0, kills = 0, ap = 0, bestRank = 0 }
    return sv.records
end

-- Evaluate the combat / haul personal bests for a freshly finished match. Sets
-- m.records = { damage=bool, healing=bool, kills=bool, ap=bool } for the ones
-- beaten, and updates the stored bests. Rank is handled separately (async).
function Records.evaluate(m)
    local R = store()
    if not R then return end
    m.records = m.records or {}
    local lr = BGMeter.Match.local_row(m)
    if lr then
        if (lr.damage or 0)  > (R.damage or 0)  then m.records.damage  = true; R.damage  = lr.damage end
        if (lr.healing or 0) > (R.healing or 0) then m.records.healing = true; R.healing = lr.healing end
        if (lr.kills or 0)   > (R.kills or 0)   then m.records.kills   = true; R.kills   = lr.kills end
    end
    if (m.haul.apGained or 0) > (R.ap or 0) then m.records.ap = true; R.ap = m.haul.apGained end
end

-- Note a competitive rank once the standing arrives (lower rank = better).
function Records.note_rank(m, rank)
    if not rank or rank <= 0 then return end
    local R = store()
    if not R then return end
    if (R.bestRank or 0) == 0 or rank < R.bestRank then
        m.records = m.records or {}
        m.records.rank = true
        R.bestRank = rank
    end
end

BGMeter.Records = Records
