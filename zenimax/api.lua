-- bgmeter :: zenimax/api.lua
-- Thin aliases over the raw ZOS global functions. Nothing else in the addon
-- calls a bare API global; it goes through BGMeter.zenimax.api. This keeps the
-- engine surface in one auditable place and makes the call sites readable.

BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.zenimax = BGMeter.zenimax or {}

local C = BGMeter.zenimax.constants

local A = {}

-- ── Time / diagnostics ────────────────────────────────────────────────────
A.now_ms = GetGameTimeMilliseconds
A.get_api_version = GetAPIVersion
A.get_timestamp = GetTimeStamp
A.get_display_name = GetDisplayName
A.get_char_name = function() return GetUnitName("player") end
A.get_ui_mouse = GetUIMousePosition

-- ── Match metadata ────────────────────────────────────────────────────────
A.get_bg_id          = GetCurrentBattlegroundId
A.get_bg_state       = GetCurrentBattlegroundState
A.get_bg_game_type   = GetCurrentBattlegroundGameType
A.get_bg_round_index = GetCurrentBattlegroundRoundIndex
A.is_active_bg       = IsActiveWorldBattleground
A.get_bg_name        = GetBattlegroundName        -- (battlegroundId) -> string
A.get_bg_team_size   = GetBattlegroundTeamSize    -- (battlegroundId) -> int
A.get_local_team     = function() return GetUnitBattlegroundTeam("player") end
A.get_result_for_team = GetBattlegroundResultForTeam -- (team) -> BattlegroundResult
A.get_num_rounds     = GetBattlegroundNumRounds
A.get_round_result   = GetCurrentBattlegroundRoundResult
A.get_rounds_won     = GetCurrentBattlegroundRoundsWonByTeam
A.get_team_score     = GetCurrentBattlegroundScore
A.get_team_icon      = GetBattlegroundTeamIcon
A.get_team_name      = GetBattlegroundTeamName

A.get_num_objectives          = GetNumObjectives
A.get_objective_ids           = GetObjectiveIdsForIndex
A.is_bg_objective             = IsBattlegroundObjective
A.get_objective_info          = GetObjectiveInfo
A.get_objective_type          = GetObjectiveType
A.get_objective_designation   = GetObjectiveDesignation
A.get_objective_control_state = GetObjectiveControlState
A.get_capture_area_owner      = GetCaptureAreaObjectiveOwner

-- ── Scoreboard ────────────────────────────────────────────────────────────
A.get_num_entries          = GetNumScoreboardEntries                -- (roundIndex?) -> n
A.get_local_entry_index    = GetScoreboardLocalPlayerEntryIndex     -- (roundIndex?) -> idx
A.get_entry_info           = GetScoreboardEntryInfo                 -- (i, round?) -> charName, displayName, team, isLocal
A.get_entry_team           = GetScoreboardEntryBattlegroundTeam     -- (i, round?) -> team
A.get_entry_class          = GetScoreboardEntryClassId              -- (i, round?) -> classId
A.get_entry_lives          = GetScoreboardEntryNumLivesRemaining    -- (i, round?) -> n
A.get_entry_score          = GetScoreboardEntryScoreByType          -- (i, scoreType, round?) -> int
A.get_entry_cumulative     = GetBattlegroundCumulativeScoreForScoreboardEntryByType -- (i, scoreType, round?) -> int

-- Medals (per scoreboard entry) -- iterator + lookup
A.get_next_entry_medal     = GetNextScoreboardEntryMedalId          -- (i, round?, lastMedalId?) -> nextId|nil
A.get_entry_medal_count    = GetScoreboardEntryNumEarnedMedalsById  -- (i, medalId, round?) -> n
A.get_medal_info           = GetMedalInfo                           -- (medalId) -> name, icon, condition, scoreReward
A.gen_cumulative_medals    = GenerateCumulativeMedalInfoForScoreboardEntry
A.get_next_cumulative_medal = GetNextBattlegroundCumulativeMedalId
A.get_cumulative_medal_count = GetBattlegroundCumulativeNumEarnedMedalsById

-- ── Progression: AP / XP / Champion ───────────────────────────────────────
A.get_currency       = GetCurrencyAmount                            -- (CurrencyType, CurrencyLocation) -> int
A.get_currency_icon  = GetCurrencyKeyboardIcon                      -- (CurrencyType) -> textureName
A.get_alliance_points = function()
    return GetCurrencyAmount(C.CURT_ALLIANCE_POINTS, C.CURRENCY_LOCATION_CHARACTER)
end
A.get_unit_xp        = function() return GetUnitXP("player") end
A.get_unit_xp_max    = function() return GetUnitXPMax("player") end
A.get_cp_earned      = GetPlayerChampionPointsEarned                -- () -> int

-- ── AvA presence / zone (for the transversal Cyrodiil session) ────────────
-- IsPlayerInAvAWorld covers Cyrodiil + Imperial City; IsInAvAZone is the
-- fallback name. Resolved through safe() at the call site so either may be nil.
A.is_player_in_ava_world = IsPlayerInAvAWorld                       -- () -> bool
A.is_in_ava_zone         = IsInAvAZone                              -- () -> bool
A.get_zone_name          = function() return GetUnitZone("player") end

-- ── Competitive leaderboard / ranking ─────────────────────────────────────
A.query_bg_leaderboard      = QueryBattlegroundLeaderboardData          -- (type) -> readyState
A.get_bg_leaderboard_local  = GetBattlegroundLeaderboardLocalPlayerInfo -- (type) -> rank, score
A.get_player_mmr            = GetPlayerMMRByType                        -- (LFGActivity) -> mmr
A.does_bg_impact_mmr        = DoesCurrentBattlegroundImpactMMR          -- () -> bool

-- ── Veterancy / Season ────────────────────────────────────────────────────
A.is_veterancy_season_active = IsVeterancySeasonActive             -- () -> bool
A.get_season_name            = GetCurrentVeterancySeasonName        -- () -> string
A.get_season_time_remaining  = GetCurrentVeterancySeasonTimeRemainingS -- () -> seconds
A.get_season_id              = GetCurrentVeterancySeasonId          -- () -> int
A.is_in_veterancy_zone       = IsInVeterancyProgressionZone         -- () -> bool
A.get_unit_veterancy_rank    = function() return GetUnitVeterancyRank("player") end
A.get_veterancy_rank_title   = GetVeterancyRankTitle               -- (rank, seasonId?) -> string
A.get_veterancy_rank_icon    = GetVeterancyRankIcon               -- (rank, seasonId?) -> texture
A.get_veterancy_large_icon   = GetVeterancyLargeRankIcon          -- (rank, seasonId?) -> texture

-- Reward-track progress (the % within a veterancy tier).
A.get_active_ref_track_ids   = GetActiveReferenceTrackIdsForRewardTrackType -- (type) -> refTrackId
A.get_ref_track_index        = GetReferenceTrackIndex             -- (type, refTrackId) -> idx|nil
A.get_reward_track_id_from_ref = GetRewardTrackIdFromReferenceTrackId -- (type, refTrackId) -> rewardTrackId
A.get_info_for_reward_track  = GetInfoForRewardTrack              -- (type, refIdx) -> trackId, currentRank, progressToNext, endTime
A.get_tier_total_progress    = GetTotalProgressAtRewardTrackTier  -- (rewardTrackId, rankIndex) -> total points for that tier

BGMeter.zenimax.api = A
