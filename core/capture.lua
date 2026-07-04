-- bgmeter :: core/capture.lua
-- The capture engine. Owns the in-flight match: snapshots progression baselines
-- when a match starts, accumulates AP/XP/CP/veterancy deltas during it, and reads
-- the full scoreboard into a Match record when it finishes. No UI here -- it just
-- produces a finished Match and hands it to pipeline/presentation.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Capture = {}

-- In-flight state. nil between matches.
local active = nil          -- the Match record being built
local baseline = nil        -- progression baselines at match start

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

-- Count the medals a single scoreboard entry earned, and collect their ids
-- (for rendering the real medal icons). Returns (count, idList).
local function count_entry_medals(i, round)
    local A = BGMeter.zenimax.api
    local count, last, ids = 0, nil, {}
    -- Hard cap the loop so a misbehaving iterator can never hang the frame.
    for _ = 1, 64 do
        local id = safe(A.get_next_entry_medal, i, round, last)
        if not id then break end
        local n = safe(A.get_entry_medal_count, i, id, round) or 1
        count = count + n
        ids[#ids + 1] = id
        last = id
    end
    return count, ids
end

-- Read the live scoreboard into m.battle. Reusable by the /bgmeter dump command.
function Capture.read_battle(m)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local Match = BGMeter.Match
    local round = nil  -- current round
    local n = safe(A.get_num_entries, round) or 0

    m.battle = {}
    for i = 1, n do
        local row = Match.new_row()
        local charName, displayName, team, isLocal = safe(A.get_entry_info, i, round)
        row.charName    = charName
        row.displayName = displayName
        row.team        = team or safe(A.get_entry_team, i, round)
        row.isLocal     = isLocal and true or false
        row.classId     = safe(A.get_entry_class, i, round)
        row.lives       = safe(A.get_entry_lives, i, round)
        row.damage      = safe(A.get_entry_score, i, C.SCORE_TRACKER_TYPE_DAMAGE_DONE, round)  or 0
        row.healing     = safe(A.get_entry_score, i, C.SCORE_TRACKER_TYPE_HEALING_DONE, round) or 0
        row.kills       = safe(A.get_entry_score, i, C.SCORE_TRACKER_TYPE_KILL, round)         or 0
        row.deaths      = safe(A.get_entry_score, i, C.SCORE_TRACKER_TYPE_DEATH, round)        or 0
        row.assists     = safe(A.get_entry_score, i, C.SCORE_TRACKER_TYPE_ASSISTS, round)      or 0
        row.score       = safe(A.get_entry_score, i, C.SCORE_TRACKER_TYPE_SCORE, round)        or 0
        row.medals, row.medalIds = count_entry_medals(i, round)
        m.battle[#m.battle + 1] = row
    end
    return m
end

-- Resolve the win/loss/tie label for the local player's team.
local function read_result(localTeam)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    if localTeam == nil then return nil end
    local r = safe(A.get_result_for_team, localTeam)
    if r == nil then return nil end
    return C.RESULT_LABEL[r]
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────

-- Called when the BG transitions into an active running state. Snapshots every
-- progression baseline so the finish delta is "what this match earned".
function Capture.begin()
    local A = BGMeter.zenimax.api
    local Match = BGMeter.Match
    local Vet = BGMeter.Veterancy

    active = Match.new()
    active.startMs   = safe(A.now_ms) or 0
    active.bgId      = safe(A.get_bg_id)
    active.name      = active.bgId and safe(A.get_bg_name, active.bgId) or nil
    active.gameType  = safe(A.get_bg_game_type)
    active.localTeam = safe(A.get_local_team)

    baseline = {
        ap  = safe(A.get_alliance_points) or 0,
        xp  = safe(A.get_unit_xp) or 0,
        cp  = safe(A.get_cp_earned) or 0,
        vet = Vet.snapshot(),
    }
    active.haul.vetStart = baseline.vet

    BGMeter.Log.debug("match begin: bg=%s ap0=%d xp0=%d", tostring(active.name), baseline.ap, baseline.xp)
end

-- Event accumulators -- a live cross-check on the baseline delta, and the only
-- way to flag a veterancy tier-up the moment it happens.
function Capture.on_ap(_, alliancePoints, _playSound, difference)
    if not active or not difference then return end
    active.haul.apGained = active.haul.apGained + difference
end

function Capture.on_xp(_, reason, _level, prev, current)
    if not active or not prev or not current then return end
    active.haul.xpGained = active.haul.xpGained + math.max(0, current - prev)
end

function Capture.on_cp(_, delta)
    if not active or not delta then return end
    active.haul.cpGained = active.haul.cpGained + delta
end

function Capture.on_reward_track(_, rewardTrackType, _trackId, prevTier, newTier)
    if not active then return end
    local C = BGMeter.zenimax.constants
    if rewardTrackType ~= C.REWARD_TRACK_TYPE_AVA_VETERANCY then return end
    if newTier and prevTier and newTier > prevTier then
        active.haul.vetRankUp = true
        BGMeter.Log.debug("veterancy tier up: %s -> %s", tostring(prevTier), tostring(newTier))
    end
end

-- Called when the BG reaches FINISHED. Reads the scoreboard, finalises the haul
-- from baseline deltas (authoritative) and returns the completed Match record.
function Capture.finalize()
    if not active then return nil end
    local A = BGMeter.zenimax.api
    local Match = BGMeter.Match
    local Vet = BGMeter.Veterancy

    active.endMs = safe(A.now_ms) or active.startMs
    active.capturedAt = safe(GetTimeStamp)
    active.result = read_result(active.localTeam)

    Capture.read_battle(active)

    -- Haul totals: baseline delta is the source of truth; fall back to the
    -- event-accumulated value if a baseline read failed.
    if baseline then
        local apNow = safe(A.get_alliance_points)
        local xpNow = safe(A.get_unit_xp)
        local cpNow = safe(A.get_cp_earned)
        if apNow then active.haul.apGained = math.max(active.haul.apGained, apNow - baseline.ap) end
        if xpNow then active.haul.xpGained = math.max(active.haul.xpGained, xpNow - baseline.xp) end
        if cpNow then active.haul.cpGained = math.max(active.haul.cpGained, cpNow - baseline.cp) end
    end

    active.haul.vetEnd = Vet.snapshot()
    -- Medals the local player earned this match (from their scoreboard row).
    local lr = Match.local_row(active)
    if lr then active.haul.medals = lr.medals end

    Match.derive(active)

    local finished = active
    active, baseline = nil, nil
    return finished
end

-- Are we mid-match? (Used to guard the dump command.)
function Capture.is_active() return active ~= nil end

-- For /bgmeter dump: build a throwaway Match snapshot of the current state
-- without disturbing any in-flight capture.
function Capture.snapshot_now()
    local A = BGMeter.zenimax.api
    local Match = BGMeter.Match
    local Vet = BGMeter.Veterancy
    local m = Match.new()
    m.bgId     = safe(A.get_bg_id)
    m.name     = m.bgId and safe(A.get_bg_name, m.bgId) or nil
    m.gameType = safe(A.get_bg_game_type)
    m.localTeam = safe(A.get_local_team)
    m.result   = read_result(m.localTeam)
    Capture.read_battle(m)
    m.haul.vetEnd = Vet.snapshot()
    return m
end

BGMeter.Capture = Capture
