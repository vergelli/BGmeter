-- bgmeter :: bgmeter.lua  (entry, loaded last)
-- Bootstraps the addon: opens SavedVars, wires the capture pipeline, builds the
-- slash-command router. Everything else is attached to the single BGMeter global.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local K = BGMeter.Constants

-- ── /bgmeter dump  (the M0 validator) ─────────────────────────────────────
-- Reads the live scoreboard + progression snapshot and prints it to chat, so we
-- can confirm the API returns what we expect (especially whether veterancy moves
-- in a battleground) BEFORE trusting it in the UI.
local function cmd_dump()
    local A   = BGMeter.zenimax.api
    local Log = BGMeter.Log
    local F   = BGMeter.Format

    local ok, apiVer = pcall(A.get_api_version)
    if not ok then apiVer = "?" end
    Log.say("API %s  ·  BG active=%s  state=%s",
        tostring(apiVer), tostring(A.is_active_bg and A.is_active_bg() or "?"),
        tostring(A.get_bg_state and A.get_bg_state() or "?"))

    local m = BGMeter.Capture.snapshot_now()
    Log.say("%s  ·  %d players  ·  result=%s",
        tostring(m.name or "Battleground"), #m.battle, tostring(m.result or "—"))
    BGMeter.Match.sort(m, "damage", true)
    for i, r in ipairs(m.battle) do
        Log.say("  %d. %s  dmg=%s heal=%s  %d/%d/%d  pts=%s  medals=%d%s",
            i, tostring(r.displayName or r.charName or "?"),
            F.abbrev(r.damage), F.abbrev(r.healing),
            r.kills, r.deaths, r.assists, F.abbrev(r.score), r.medals or 0,
            r.isLocal and "  <- you" or "")
    end

    local vet = m.haul.vetEnd
    if vet and vet.rank then
        Log.say("veterancy: rank=%s tier=%s pct=%.1f%%  season=%s  inZone=%s",
            tostring(vet.rank), tostring(vet.tier), (vet.percent or 0) * 100,
            tostring(vet.seasonName or "—"), tostring(vet.inZone))
    else
        Log.say("veterancy: no data (season inactive or not in a veterancy zone)")
    end
    Log.say("progression now: AP=%s  XP=%s/%s  CP=%s",
        F.commas(A.get_alliance_points() or 0),
        F.commas(A.get_unit_xp() or 0), F.commas(A.get_unit_xp_max() or 0),
        F.commas(A.get_cp_earned() or 0))

    -- Competitive standing: query then read (may be cached or pending).
    if A.query_bg_leaderboard then
        pcall(A.query_bg_leaderboard, BGMeter.zenimax.constants.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE)
    end
    local st = BGMeter.Standing.read()
    Log.say("standing: rank=%s  score=%s  mmr=%s  impactsMMR=%s",
        st.rank > 0 and ("#" .. st.rank) or "unranked",
        tostring(st.score), tostring(st.mmr or "—"), tostring(st.impacts))
end

-- ── /bgmeter demo  (synthetic match -> see the window without queueing a BG) ─
local function cmd_demo()
    local Match = BGMeter.Match
    local m = Match.new()
    m.name, m.gameType, m.result = "Mournhold Sewers", nil, "WIN"
    m.startMs, m.endMs = 0, 14 * 60000
    m.localTeam = BGMeter.zenimax.constants.BATTLEGROUND_TEAM_FIRE_DRAKES
    m.capturedAt = pcall(GetTimeStamp) and GetTimeStamp() or 0

    local sample = {
        { "Velladocuments",  412331, 38120,  9,  4, 12, 5, 3, true  },
        { "@StormLord",      390887,  2010, 11,  6,  7, 4, 1, false },
        { "Shadowmend",      301044, 95210,  5,  3, 15, 6, 2, false },
        { "Brakka gro-Mug",  288190, 14002,  8,  5,  6, 3, 0, false },
        { "Lyra Heartwood",  150220, 188400, 2,  2, 19, 7, 2, false },
        { "@FrostCaller",    260110,  9100,  7,  7,  5, 2, 0, false },
        { "Dro-mathra",      198320, 22110,  4,  8,  9, 1, 0, false },
        { "@HealBot",         54000, 240300, 1,  1, 22, 8, 4, false },
    }
    local C = BGMeter.zenimax.constants
    local teams = { C.BATTLEGROUND_TEAM_FIRE_DRAKES, C.BATTLEGROUND_TEAM_PIT_DAEMONS, C.BATTLEGROUND_TEAM_STORM_LORDS }
    for i, s in ipairs(sample) do
        local r = Match.new_row()
        r.displayName, r.damage, r.healing = s[1], s[2], s[3]
        r.kills, r.deaths, r.assists, r.score, r.medals = s[4], s[5], s[6], s[7] * 1000, s[8]
        r.isLocal = s[9]
        r.team = teams[((i - 1) % 3) + 1]
        m.battle[#m.battle + 1] = r
    end

    m.haul.apGained, m.haul.xpGained, m.haul.cpGained, m.haul.medals = 14200, 38400, 2, 3
    m.haul.vetStart = { rank = 14, tier = 14, percent = 0.73, progressToNext = 3650, tierTotal = 5000, seasonName = "Whitestrake's Mayhem", secondsLeft = 387600, inZone = true }
    m.haul.vetEnd   = { rank = 14, tier = 14, percent = 0.81, progressToNext = 4050, tierTotal = 5000, rankTitle = "Veteran Lieutenant", seasonName = "Whitestrake's Mayhem", secondsLeft = 387600, inZone = true }
    Match.derive(m)
    m.standing = { rank = 3, prevRank = 5, rankDelta = 2, score = 1840, prevScore = 1795, scoreDelta = 45, mmr = 1620, impacts = true }
    m.records  = { damage = true, ap = true, rank = true }   -- showcase the ★ markers

    BGMeter.History.push(m)
    BGMeter.UI.window.show_match(1)
    BGMeter.Sound.play("win")

    -- Showcase the Vanguard HUD bar with a synthetic AP-by-source split so it
    -- can be seen without queueing for Cyrodiil.
    local Ava = BGMeter.Ava
    Ava.session.active = true
    Ava.session.ap = 18450
    Ava.session.xp = 92000
    Ava.session.startMs = (BGMeter.zenimax.api.now_ms and BGMeter.zenimax.api.now_ms() or 0) - 3300000
    Ava.session.sources = { kills = 9200, offense = 4800, defense = 2600, rez = 1100, bg = 0, other = 750 }
    BGMeter.UI.vanguard.preview(m.haul.vetEnd)

    BGMeter.Log.say("demo match injected -- window + vanguard bar shown")
end

-- ── /bgmeter ap  (the AvA AP-source probe) ─────────────────────────────────
-- Prints the live AvA session + its AP-by-source split, and toggles a verbose
-- mode that echoes each AP gain with its reason code -- so we can confirm the
-- `reason` attribution is correct in Cyrodiil BEFORE trusting the breakdown.
local function cmd_ap()
    local Ava = BGMeter.Ava
    local Log = BGMeter.Log
    local F   = BGMeter.Format

    Ava.probe = not Ava.probe
    Log.say("AP probe %s  ·  in AvA=%s  ·  session %s",
        Ava.probe and "|c5cc85fON|r" or "|ce34234OFF|r",
        tostring(Ava.in_ava()), tostring(Ava.session.active))

    local s = Ava.session
    Log.say("session AP=%s  XP=%s  AP/hr=%s  (%d gains)",
        F.commas(s.ap), F.commas(s.xp), F.commas(Ava.ap_per_hour()), s.gains)
    local bd = Ava.breakdown()
    if #bd == 0 then
        Log.say("  no AP earned yet -- the split fills as you play")
    else
        for _, e in ipairs(bd) do
            Log.say("  %s: %s  (%d%%)", e.label, F.commas(e.ap), math.floor(e.pct * 100 + 0.5))
        end
    end
    if Ava.probe then Log.say("  earn some AP now -- each gain prints its reason code") end
end

-- ── slash router ──────────────────────────────────────────────────────────
local function on_slash(args)
    args = (args or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local Log = BGMeter.Log

    if args == "" or args == "show" then
        BGMeter.UI.window.show()
    elseif args == "hide" then
        BGMeter.UI.window.hide()
    elseif args == "toggle" then
        BGMeter.UI.window.toggle()
    elseif args == "dump" then
        cmd_dump()
    elseif args == "ap" then
        cmd_ap()
    elseif args == "bar" then
        BGMeter.UI.vanguard.toggle()
    elseif args == "bar lock" or args == "lock" then
        BGMeter.UI.vanguard.toggle_lock()
    elseif args == "dock" or args == "bar dock" then
        BGMeter.UI.vanguard.toggle_dock()
    elseif args == "fade" or args == "bar fade" then
        BGMeter.UI.vanguard.toggle_fade()
    elseif args == "demo" then
        cmd_demo()
    elseif args == "last" then
        if BGMeter.History.count() == 0 then Log.say("no matches recorded yet")
        else BGMeter.UI.window.show_match(1) end
    elseif args == "clear" then
        BGMeter.History.clear()
        Log.say("history cleared")
    elseif args == "debug" then
        Log.DEBUG = not Log.DEBUG
        Log.say("debug %s", Log.DEBUG and "ON" or "OFF")
    else
        Log.say("commands: |cFFFFFF/bgmeter|r [show|hide|toggle|bar|dock|fade|lock|last|demo|ap|dump|clear|debug]")
    end
end

-- ── bootstrap ─────────────────────────────────────────────────────────────
local function on_addon_loaded()
    BGMeter.zenimax.savedvars.init(K.SAVED_VARS, 1)

    BGMeter.Pipeline.acquisition.init()
    BGMeter.Ava.init()
    BGMeter.UI.window.init()
    BGMeter.UI.vanguard.init()

    SLASH_COMMANDS[K.SLASH] = on_slash

    BGMeter.Log.say("v%s loaded  ·  %s for commands", K.VERSION, K.SLASH)
end

BGMeter.zenimax.events.register_addon_loaded(K.ADDON_NAME, on_addon_loaded)
