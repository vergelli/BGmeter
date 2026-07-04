-- bgmeter :: pipeline/acquisition.lua
-- Wires the engine events to the capture engine and brackets the match
-- lifecycle. This is the only module that talks to zenimax/events for combat/
-- progression data; it owns when a match begins and ends.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Acquisition = {}

local PREFIX = "BGMeter_"

local function on_state_change(_, previousState, currentState)
    local C = BGMeter.zenimax.constants
    local Capture = BGMeter.Capture

    -- Begin once, as early as possible, so AP/XP baselines predate any gain.
    if not Capture.is_active() then
        if currentState == C.BATTLEGROUND_STATE_STARTING
        or currentState == C.BATTLEGROUND_STATE_PREROUND
        or currentState == C.BATTLEGROUND_STATE_RUNNING then
            Capture.begin()
        end
    end

    if currentState == C.BATTLEGROUND_STATE_FINISHED then
        local match = Capture.finalize()
        if match then BGMeter.Pipeline.presentation.publish(match) end
    end
end

function Acquisition.init()
    local E = BGMeter.zenimax.events
    local C = BGMeter.zenimax.constants
    local Capture = BGMeter.Capture

    E.register(PREFIX .. "State", C.EVENT_BATTLEGROUND_STATE_CHANGED, on_state_change)
    E.register(PREFIX .. "AP",    C.EVENT_ALLIANCE_POINT_UPDATE,      Capture.on_ap)
    E.register(PREFIX .. "XP",    C.EVENT_EXPERIENCE_GAIN,            Capture.on_xp)
    E.register(PREFIX .. "CP",    C.EVENT_CHAMPION_POINT_GAINED,      Capture.on_cp)
    E.register(PREFIX .. "Vet",   C.EVENT_REWARD_TRACK_PROGRESS_GAINED, Capture.on_reward_track)
    E.register(PREFIX .. "Board", C.EVENT_BATTLEGROUND_LEADERBOARD_DATA_RECEIVED, BGMeter.Standing.on_data)

    BGMeter.Log.debug("acquisition wired")
end

BGMeter.Pipeline = BGMeter.Pipeline or {}
BGMeter.Pipeline.acquisition = Acquisition
