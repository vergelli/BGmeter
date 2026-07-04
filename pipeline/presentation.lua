-- bgmeter :: pipeline/presentation.lua
-- Terminal stage: a finished Match arrives here, gets persisted to history, and
-- the window is told to show it. Kept separate from acquisition so the data
-- path (capture) has no dependency on the UI being loaded.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Presentation = {}

function Presentation.publish(match)
    BGMeter.History.push(match)
    BGMeter.Records.evaluate(match)          -- personal-best ★ flags (combat/AP)
    BGMeter.Session.record(match)            -- running W/L + AP tally for this play session

    -- Kick off the competitive-standing fill (async: applies now or on event).
    BGMeter.Standing.request(match)

    local lr = BGMeter.Match.local_row(match)
    local F = BGMeter.Format
    BGMeter.Log.say("%s %s -- you: %s dmg, %s heal, %d/%d/%d -- haul %s AP, %s XP",
        tostring(match.name or "Battleground"),
        tostring(match.result or ""),
        lr and F.abbrev(lr.damage) or "0",
        lr and F.abbrev(lr.healing) or "0",
        lr and lr.kills or 0, lr and lr.deaths or 0, lr and lr.assists or 0,
        F.commas(match.haul.apGained), F.commas(match.haul.xpGained))

    -- Result cue: a tier-up trumps the win/loss sting.
    if match.haul.vetRankUp then BGMeter.Sound.play("rankup")
    elseif match.result == "WIN" then BGMeter.Sound.play("win")
    elseif match.result == "LOSS" then BGMeter.Sound.play("loss")
    else BGMeter.Sound.play("open") end

    -- Auto-open the result window (toggleable).
    if BGMeter.Prefs.get("auto_open") and BGMeter.UI and BGMeter.UI.window then
        BGMeter.UI.window.show_match(1)
    end
end

BGMeter.Pipeline = BGMeter.Pipeline or {}
BGMeter.Pipeline.presentation = Presentation
