-- bgmeter :: core/sound.lua
-- Native ESO sound cues, gated by the `sounds` pref. Uses only stock SOUNDS
-- ids (no asset authoring) and pcall-guards every play so a renamed id can
-- never error. Cues are deliberately sparse -- least-intrusive by design.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Sound = {}

-- Logical cue -> stock SOUNDS key (resolved lazily so a missing id is harmless).
local CUE = {
    open    = "BOOK_ACQUIRED",
    win     = "DUEL_WON",
    loss    = "GENERAL_ALERT_ERROR",
    rankup  = "LEVEL_UP",
    pb      = "ACHIEVEMENT_AWARDED",
    nav     = "CHAMPION_SPINNER_UP",
}

function Sound.play(cue)
    if not BGMeter.Prefs.get("sounds") then return end
    local key = CUE[cue]
    if not key then return end
    local id = SOUNDS and SOUNDS[key]
    if id then pcall(PlaySound, id) end
end

BGMeter.Sound = Sound
