-- bgmeter :: core/session.lua
-- In-memory tally of the current play session (resets on /reloadui or relog).
-- Gives the result window a glanceable "how's tonight going" footer without
-- persisting anything -- the long-term record lives in history + records.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Session = { wins = 0, losses = 0, matches = 0, ap = 0, xp = 0 }

function Session.record(m)
    Session.matches = Session.matches + 1
    if m.result == "WIN" then Session.wins = Session.wins + 1
    elseif m.result == "LOSS" then Session.losses = Session.losses + 1 end
    Session.ap = Session.ap + (m.haul.apGained or 0)
    Session.xp = Session.xp + (m.haul.xpGained or 0)
end

-- A one-line summary, or nil when no matches have been played this session.
function Session.summary()
    if Session.matches == 0 then return nil end
    local F = BGMeter.Format
    return string.format("Session: %dW-%dL  ·  %s AP  ·  %s XP earned",
        Session.wins, Session.losses, F.commas(Session.ap), F.commas(Session.xp))
end

BGMeter.Session = Session
