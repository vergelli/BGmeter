BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Capture = {}

local SAMPLE_NAME = "BGMeterScoreSample"
local SAMPLE_MS   = 5000

local active = nil
local baseline = nil

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

local function team_list()
    local C = BGMeter.zenimax.constants
    return { C.BATTLEGROUND_TEAM_FIRE_DRAKES, C.BATTLEGROUND_TEAM_PIT_DAEMONS, C.BATTLEGROUND_TEAM_STORM_LORDS }
end

local function current_round()
    local A = BGMeter.zenimax.api
    return safe(A.get_bg_round_index) or 1
end

local function read_score(i, stype, round)
    local A = BGMeter.zenimax.api
    local v = safe(A.get_entry_cumulative, i, stype, round)
    if v == nil then v = safe(A.get_entry_score, i, stype, round) end
    return v or 0
end

local function count_entry_medals(i, round)
    local A = BGMeter.zenimax.api
    local count, last, ids, counts = 0, nil, {}, {}
    for _ = 1, 64 do
        local id = safe(A.get_next_entry_medal, i, round, last)
        if not id then break end
        local n = safe(A.get_entry_medal_count, i, id, round) or 1
        count = count + n
        ids[#ids + 1] = id
        counts[id] = n
        last = id
    end
    return count, ids, counts
end

function Capture.read_battle(m)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local Match = BGMeter.Match
    local round = current_round()
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
        row.damage      = read_score(i, C.SCORE_TRACKER_TYPE_DAMAGE_DONE, round)
        row.healing     = read_score(i, C.SCORE_TRACKER_TYPE_HEALING_DONE, round)
        row.taken       = read_score(i, C.SCORE_TRACKER_TYPE_DAMAGE_TAKEN, round)
        row.kills       = read_score(i, C.SCORE_TRACKER_TYPE_KILL, round)
        row.deaths      = read_score(i, C.SCORE_TRACKER_TYPE_DEATH, round)
        row.assists     = read_score(i, C.SCORE_TRACKER_TYPE_ASSISTS, round)
        row.score       = read_score(i, C.SCORE_TRACKER_TYPE_SCORE, round)
        row.medals, row.medalIds, row.medalCounts = count_entry_medals(i, round)
        m.battle[#m.battle + 1] = row
    end
    return m
end

local function read_teams(m)
    local A = BGMeter.zenimax.api
    local round = current_round()
    local present = {}
    for _, row in ipairs(m.battle) do
        if row.team ~= nil then present[row.team] = true end
    end
    local order = {}
    for _, t in ipairs(team_list()) do
        if t ~= nil and (present[t] or next(present) == nil) then
            order[#order + 1] = t
        end
    end
    local teams = {}
    for _, t in ipairs(order) do
        teams[#teams + 1] = {
            team      = t,
            score     = safe(A.get_team_score, round, t) or 0,
            roundsWon = safe(A.get_rounds_won, t) or 0,
        }
    end
    m.teams = teams
    m.numRounds = (m.bgId and safe(A.get_num_rounds, m.bgId)) or 1
end

local function read_result(localTeam)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    if localTeam == nil then return nil end
    local r = safe(A.get_result_for_team, localTeam)
    if r == nil then return nil end
    return C.RESULT_LABEL[r]
end

local function sample_scores()
    if not active or not active.timeline then return end
    local A = BGMeter.zenimax.api
    local tl = active.timeline
    local round = current_round()
    local i = #tl.t + 1
    tl.t[i] = (safe(A.now_ms) or 0) - (active.startMs or 0)
    tl.r[i] = round
    local teams = team_list()
    tl.s1[i] = (teams[1] ~= nil and safe(A.get_team_score, round, teams[1])) or 0
    tl.s2[i] = (teams[2] ~= nil and safe(A.get_team_score, round, teams[2])) or 0
    tl.s3[i] = (teams[3] ~= nil and safe(A.get_team_score, round, teams[3])) or 0
end

local function start_sampler()
    BGMeter.zenimax.events.register_update(SAMPLE_NAME, SAMPLE_MS, sample_scores)
end

local function stop_sampler()
    BGMeter.zenimax.events.unregister_update(SAMPLE_NAME)
end

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
    active.timeline  = { t = {}, r = {}, s1 = {}, s2 = {}, s3 = {}, teams = team_list() }
    active.killfeed  = {}

    baseline = {
        ap  = safe(A.get_alliance_points) or 0,
        cp  = safe(A.get_cp_earned) or 0,
        vet = Vet.snapshot(),
    }
    active.haul.vetStart = baseline.vet

    start_sampler()
    sample_scores()

    BGMeter.Log.debug("match begin: bg=%s ap0=%d", tostring(active.name), baseline.ap)
end

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

function Capture.on_kill(_, killedChar, killedDisp, _killedTeam, killerChar, killerDisp, _killerTeam)
    if not active or not active.killfeed then return end
    local A = BGMeter.zenimax.api
    local myDisp = safe(A.get_display_name)
    local myChar = safe(A.get_char_name)
    local kind = nil
    if (killerDisp and killerDisp == myDisp) or (killerChar and killerChar == myChar) then
        kind = "kill"
    elseif (killedDisp and killedDisp == myDisp) or (killedChar and killedChar == myChar) then
        kind = "death"
    end
    if not kind then return end
    local t = (safe(A.now_ms) or 0) - (active.startMs or 0)
    active.killfeed[#active.killfeed + 1] = { t = t, kind = kind }
end

function Capture.finalize()
    if not active then return nil end
    local A = BGMeter.zenimax.api
    local Match = BGMeter.Match

    stop_sampler()
    sample_scores()

    active.endMs = safe(A.now_ms) or active.startMs
    active.capturedAt = safe(A.get_timestamp)
    active.result = read_result(active.localTeam)

    Capture.read_battle(active)
    read_teams(active)

    if baseline then
        local apNow = safe(A.get_alliance_points)
        local cpNow = safe(A.get_cp_earned)
        if apNow then active.haul.apGained = math.max(active.haul.apGained, apNow - baseline.ap) end
        if cpNow then active.haul.cpGained = math.max(active.haul.cpGained, cpNow - baseline.cp) end
    end

    active.haul.vetEnd = BGMeter.Veterancy.snapshot()
    local lr = Match.local_row(active)
    if lr then active.haul.medals = lr.medals end

    Match.derive(active)

    local finished = active
    active, baseline = nil, nil
    return finished
end

function Capture.abort()
    if not active then return end
    stop_sampler()
    BGMeter.Log.debug("capture aborted (left battleground mid-match)")
    active, baseline = nil, nil
end

function Capture.is_active() return active ~= nil end

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
    read_teams(m)
    m.haul.vetEnd = Vet.snapshot()
    return m
end

BGMeter.Capture = Capture
