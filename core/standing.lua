-- bgmeter :: core/standing.lua
-- The competitive Battleground standing: the local player's leaderboard rank
-- (position number) and rating, plus the up/down movement since the last match.
--
-- The game exposes the CURRENT rank/score directly, but NOT the previous value,
-- so we persist the last-seen rank/score in SavedVars and diff. Leaderboard data
-- can arrive asynchronously, so this module queries, then fills the match record
-- either immediately (data cached) or when the data-received event fires.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Standing = {}

local pending = nil  -- match awaiting its standing fill

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

-- Best-effort MMR: BG MMR is keyed by LFG activity, not leaderboard type, so we
-- take the first non-zero among champion / non-champion / low-level.
local function read_mmr()
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    for _, act in ipairs({ C.LFG_ACTIVITY_BG_CHAMPION, C.LFG_ACTIVITY_BG_NON_CHAMPION, C.LFG_ACTIVITY_BG_LOW_LEVEL }) do
        if act ~= nil then
            local mmr = safe(A.get_player_mmr, act)
            if mmr and mmr > 0 then return mmr end
        end
    end
    return nil
end

-- Read the raw current standing (rank/score/mmr/impacts). Fields are 0/nil when
-- unranked or unavailable.
function Standing.read()
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local rank, score = safe(A.get_bg_leaderboard_local, C.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE)
    return {
        rank    = rank or 0,
        score   = score or 0,
        mmr     = read_mmr(),
        impacts = safe(A.does_bg_impact_mmr) and true or false,
    }
end

-- Compare a fresh read against the stored previous standing, then persist the
-- new values. Returns the enriched standing (with prevRank / deltas).
local function diff_and_store(cur)
    local sv = BGMeter.zenimax.savedvars.get()
    local prev = (sv and sv.standing) or { rank = 0, score = 0 }

    cur.prevRank   = prev.rank or 0
    cur.prevScore  = prev.score or 0
    -- Lower rank number is better: positive rankDelta == moved UP the ladder.
    cur.rankDelta  = (cur.prevRank > 0 and cur.rank > 0) and (cur.prevRank - cur.rank) or 0
    cur.scoreDelta = (cur.prevScore > 0) and (cur.score - cur.prevScore) or 0
    cur.improved   = cur.rankDelta > 0 or (cur.rankDelta == 0 and cur.scoreDelta > 0)

    -- Only overwrite the baseline when we actually got a ranked read.
    if sv and cur.rank > 0 then
        sv.standing = { rank = cur.rank, score = cur.score }
    end
    return cur
end

-- Fill the pending (or most recent) match with the standing and refresh the UI.
function Standing.apply()
    local cur = diff_and_store(Standing.read())
    local match = pending or BGMeter.History.most_recent()
    if match then
        match.standing = cur
        BGMeter.Records.note_rank(match, cur.rank)   -- best-rank ★
        if match.records and match.records.rank then BGMeter.Sound.play("pb") end
    end
    pending = nil

    BGMeter.Log.debug("standing: rank=%d (Δ%d) score=%d (Δ%d)",
        cur.rank, cur.rankDelta, cur.score, cur.scoreDelta)

    if BGMeter.UI and BGMeter.UI.window and BGMeter.UI.window.refresh_if_visible then
        BGMeter.UI.window.refresh_if_visible()
    end
    return cur
end

-- Kick off a standing fill for a freshly finished match. Queries the leaderboard
-- and either applies now (data cached) or waits for the data-received event.
function Standing.request(match)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    pending = match
    local ready = safe(A.query_bg_leaderboard, C.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE)
    if ready == C.LEADERBOARD_DATA_READY then
        Standing.apply()
    end
    -- else: wait for EVENT_BATTLEGROUND_LEADERBOARD_DATA_RECEIVED -> Standing.on_data
end

function Standing.on_data(_, leaderboardType)
    local C = BGMeter.zenimax.constants
    if leaderboardType ~= nil and leaderboardType ~= C.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE then
        return
    end
    Standing.apply()
end

BGMeter.Standing = Standing
