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
        teams      = nil,
        numRounds  = 1,
        timeline   = nil,
        killfeed   = nil,

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
        taken       = 0,
        kills       = 0,
        deaths      = 0,
        assists     = 0,
        score       = 0,
        caps        = 0,
        defPts      = 0,
        carried     = 0,
        carrierKills = 0,
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

function Match.flag_lanes(m, tspan)
    local ob = m.objectives
    if not ob or not ob.t or #ob.t == 0 or not ob.list or #ob.list == 0 then return nil end
    local CZ = BGMeter.zenimax.constants
    local lanes = {}
    for li = 1, math.min(#ob.list, 4) do
        lanes[li] = { letter = tostring(ob.list[li].letter), segs = {}, ticks = {}, cur = nil, t0 = 0 }
    end
    local function close(lane, t1)
        if lane.cur ~= nil and t1 > lane.t0 then
            lane.segs[#lane.segs + 1] = { t0 = lane.t0, t1 = t1, own = lane.cur }
        end
    end
    for i = 1, #ob.t do
        local lane = lanes[ob.o[i]]
        if lane then
            local t = math.min(math.max(ob.t[i] or 0, 0), tspan)
            local evl = CZ.OBJ_EVENT_LABEL[ob.ev[i]] or (ob.ev[i] == -1 and "initial") or "?"
            local own = ob.own[i] or 0
            if lane.cur == nil then lane.cur, lane.t0 = 0, 0 end
            if evl == "initial" then
                if own ~= lane.cur then
                    close(lane, t)
                    lane.cur, lane.t0 = own, t
                end
            elseif evl == "captured" or evl == "recaptured" then
                if own ~= lane.cur then
                    close(lane, t)
                    lane.cur, lane.t0 = own, t
                    lane.ticks[#lane.ticks + 1] = { t = t, own = own, kind = "cap" }
                else
                    lane.ticks[#lane.ticks + 1] = { t = t, own = own, kind = "def" }
                end
            elseif evl == "neutral" then
                if lane.cur ~= 0 then
                    close(lane, t)
                    lane.cur, lane.t0 = 0, t
                end
            end
        end
    end
    for _, lane in ipairs(lanes) do
        if lane.cur == nil then lane.cur, lane.t0 = 0, 0 end
        close(lane, tspan)
        lane.cur = nil
    end
    return lanes
end

function Match.flag_occupation(lanes, tspan)
    if not lanes or #lanes == 0 or not tspan or tspan <= 0 then return nil end
    local total = tspan * #lanes
    local by = {}
    local neutral = 0
    for _, lane in ipairs(lanes) do
        for _, seg in ipairs(lane.segs) do
            local d = math.max(0, (seg.t1 or 0) - (seg.t0 or 0))
            if seg.own and seg.own ~= 0 then
                by[seg.own] = (by[seg.own] or 0) + d
            else
                neutral = neutral + d
            end
        end
    end
    local out = {}
    for team, ms in pairs(by) do
        out[#out + 1] = { team = team, ms = ms, pct = ms / total }
    end
    table.sort(out, function(a, b) return a.ms > b.ms end)
    return out, neutral / total
end

function Match.flag_stats(lanes)
    if not lanes or #lanes == 0 then return nil end
    local per = {}
    local function bucket(team)
        local b = per[team]
        if not b then
            b = { team = team, caps = 0, defs = 0, holdMs = 0, holds = 0 }
            per[team] = b
        end
        return b
    end
    local first = nil
    for _, lane in ipairs(lanes) do
        for _, tick in ipairs(lane.ticks) do
            if tick.own and tick.own ~= 0 then
                local bk = bucket(tick.own)
                if tick.kind == "cap" then
                    bk.caps = bk.caps + 1
                    if not first or tick.t < first.t then
                        first = { team = tick.own, t = tick.t, letter = lane.letter }
                    end
                else
                    bk.defs = bk.defs + 1
                end
            end
        end
        for _, seg in ipairs(lane.segs) do
            if seg.own and seg.own ~= 0 then
                local bk = bucket(seg.own)
                bk.holdMs = bk.holdMs + math.max(0, (seg.t1 or 0) - (seg.t0 or 0))
                bk.holds = bk.holds + 1
            end
        end
    end
    local out = {}
    for _, b in pairs(per) do
        b.avgHoldMs = (b.holds > 0) and math.floor(b.holdMs / b.holds) or 0
        out[#out + 1] = b
    end
    table.sort(out, function(x, y)
        if x.caps ~= y.caps then return x.caps > y.caps end
        return x.holdMs > y.holdMs
    end)
    if #out == 0 then return nil end
    return { per = out, first = first }
end

function Match.lead_stats(tl)
    if not tl or not tl.t or #tl.t < 2 then return nil end
    local series = { tl.s1, tl.s2, tl.s3 }
    local teams = tl.teams or {}
    local changes = 0
    local leader = nil
    local maxLead = { team = nil, lead = 0, t = 0 }
    for i = 1, #tl.t do
        local best, second, bestTeam = 0, 0, nil
        for s = 1, 3 do
            local team = teams[s]
            local v = (series[s] and series[s][i]) or 0
            if team and v > best then
                second = best
                best, bestTeam = v, team
            elseif team and v > second then
                second = v
            end
        end
        local lead = best - second
        if bestTeam and lead > 0 then
            if leader and bestTeam ~= leader then changes = changes + 1 end
            leader = bestTeam
            if lead > maxLead.lead then
                maxLead = { team = bestTeam, lead = lead, t = tl.t[i] }
            end
        end
    end
    if not maxLead.team then return nil end
    return { changes = changes, maxTeam = maxLead.team, maxLead = maxLead.lead,
             maxAt = maxLead.t, finalLeader = leader }
end

function Match.bloodiest_minute(killfeed, windowMs)
    if not killfeed or #killfeed == 0 then return nil end
    windowMs = windowMs or 60000
    local best = { count = 0, t0 = 0, t1 = 0 }
    local j = 1
    for i = 1, #killfeed do
        while (killfeed[i].t or 0) - (killfeed[j].t or 0) > windowMs do j = j + 1 end
        local count = i - j + 1
        if count > best.count then
            best = { count = count, t0 = killfeed[j].t or 0, t1 = killfeed[i].t or 0 }
        end
    end
    if best.count < 3 then return nil end
    return best
end

function Match.duels(m)
    local kf = m.killfeed
    if not kf or #kf == 0 then return nil end
    local killers, victims, kteam, vteam = {}, {}, {}, {}
    for _, k in ipairs(kf) do
        if k.kind == "death" and k.kn then
            killers[k.kn] = (killers[k.kn] or 0) + 1
            kteam[k.kn] = k.kt
        elseif k.kind == "kill" and k.dn then
            victims[k.dn] = (victims[k.dn] or 0) + 1
            vteam[k.dn] = k.dt
        end
    end
    local function top(map)
        local name, n = nil, 0
        for k, v in pairs(map) do
            if v > n or (v == n and name and k < name) then name, n = k, v end
        end
        return name, n
    end
    local nname, nn = top(killers)
    local pname, pn = top(victims)
    if not nname and not pname then return nil end
    return {
        nemesis = nname and { name = nname, count = nn, team = kteam[nname] } or nil,
        prey    = pname and { name = pname, count = pn, team = vteam[pname] } or nil,
    }
end

function Match.kill_streaks(killfeed, windowMs)
    if not killfeed or #killfeed == 0 then return nil end
    windowMs = windowMs or 12000
    local runs, open = {}, {}
    for _, k in ipairs(killfeed) do
        if k.kn then
            local o = open[k.kn]
            if o and (k.t or 0) - o.last <= windowMs then
                o.n = o.n + 1
                o.last = k.t or 0
            else
                if o and o.n >= 2 then runs[#runs + 1] = o end
                open[k.kn] = { name = k.kn, team = k.kt, n = 1, t = k.t or 0, last = k.t or 0 }
            end
        end
    end
    for _, o in pairs(open) do
        if o.n >= 2 then runs[#runs + 1] = o end
    end
    if #runs == 0 then return nil end
    table.sort(runs, function(a, b) return a.t < b.t end)
    return runs
end

function Match.first_blood(killfeed)
    if not killfeed then return nil end
    for _, k in ipairs(killfeed) do
        if k.kn and k.dn then return k end
    end
    return nil
end

BGMeter.Match = Match
