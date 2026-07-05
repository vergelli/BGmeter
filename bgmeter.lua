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
local function cmd_demo(two_teams)
    local Match = BGMeter.Match
    local A = BGMeter.zenimax.api
    local m = Match.new()
    m.name, m.gameType, m.result = two_teams and "Ularra Temple" or "Mournhold Sewers", nil, "WIN"
    m.startMs, m.endMs = 0, 14 * 60000
    m.localTeam = BGMeter.zenimax.constants.BATTLEGROUND_TEAM_FIRE_DRAKES
    m.capturedAt = (type(A.get_timestamp) == "function") and A.get_timestamp() or 0

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
    local nteams = two_teams and 2 or 3
    for i, s in ipairs(sample) do
        local r = Match.new_row()
        r.displayName, r.damage, r.healing = s[1], s[2], s[3]
        r.taken = math.floor(s[2] * 0.55)
        r.kills, r.deaths, r.assists, r.score, r.medals = s[4], s[5], s[6], s[7] * 1000, s[8]
        r.isLocal = s[9]
        r.team = teams[((i - 1) % nteams) + 1]
        m.battle[#m.battle + 1] = r
    end

    m.numRounds = two_teams and 3 or 1
    m.teams = {
        { team = teams[1], score = 512, roundsWon = two_teams and 2 or 0 },
        { team = teams[2], score = 430, roundsWon = two_teams and 1 or 0 },
    }
    if not two_teams then
        m.teams[3] = { team = teams[3], score = 381, roundsWon = 0 }
    end

    m.timeline = { t = {}, r = {}, s1 = {}, s2 = {}, s3 = {}, teams = teams }
    for i = 1, 60 do
        local p = i / 60
        m.timeline.t[i]  = math.floor(p * 14 * 60000)
        m.timeline.r[i]  = 1
        m.timeline.s1[i] = math.floor(512 * p * (0.85 + 0.15 * math.sin(p * 9)))
        m.timeline.s2[i] = math.floor(430 * p * (0.90 + 0.10 * math.sin(3 + p * 7)))
        m.timeline.s3[i] = two_teams and 0 or math.floor(381 * p * (0.88 + 0.12 * math.sin(1.5 + p * 11)))
    end

    m.killfeed = {}
    for i = 1, 9 do
        m.killfeed[i] = { t = i * 85000, kind = (i % 3 == 0) and "death" or "kill" }
    end

    local medalIds = BGMeter.Icons.scan_medal_ids(300, 6)
    if #medalIds > 0 then
        local lr = Match.local_row(m)
        if lr then
            lr.medalIds = medalIds
            lr.medalCounts = {}
            local total = 0
            for i, id in ipairs(medalIds) do
                local n = (i % 3 == 0) and 3 or 1
                lr.medalCounts[id] = n
                total = total + n
            end
            lr.medals = total
        end
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

local function cmd_objdump()
    local F = BGMeter.Format
    local CZ = BGMeter.zenimax.constants
    local m = BGMeter.History.most_recent()
    local ob = m and m.objectives
    if not ob or not ob.t or #ob.t == 0 then
        BGMeter.Log.say("no objective data in last match")
        return
    end
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    add(string.format("bgmeter objective dump -- %s (%s)", tostring(m.name), tostring(m.result)))
    add(string.format("gameType=%s  localTeam=%s  rounds=%s  events=%d",
        tostring(CZ.GAME_TYPE_LABEL[m.gameType] or m.gameType),
        tostring(m.localTeam), tostring(m.numRounds), #ob.t))
    for _, o in ipairs(ob.list) do
        add(string.format("[%s] %s (%s:%s)", tostring(o.letter), tostring(o.name),
            tostring(o.keepId), tostring(o.objectiveId)))
    end
    add("")
    for i = 1, #ob.t do
        local o = ob.list[ob.o[i]]
        add(string.format("%s r%s [%s] %s st=%s own=%s",
            F.duration(ob.t[i] or 0), tostring(ob.r and ob.r[i] or "?"),
            o and tostring(o.letter) or "?",
            tostring(CZ.OBJ_EVENT_LABEL[ob.ev[i]] or (ob.ev[i] == -1 and "initial" or ob.ev[i])),
            tostring(CZ.OBJ_STATE_LABEL[ob.st[i]] or ob.st[i]),
            tostring(ob.own[i])))
    end
    BGMeter.UI.export.show_text(table.concat(lines, "\n"))
end

local function cmd_report()
    local A = BGMeter.zenimax.api
    local F = BGMeter.Format
    local lines = {}
    local function add(fmt, ...)
        if select("#", ...) > 0 then lines[#lines + 1] = string.format(fmt, ...)
        else lines[#lines + 1] = fmt end
    end
    local function safe(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a = pcall(fn, ...)
        if not ok then return nil end
        return a
    end

    add("bgmeter diagnostic report -- v%s", K.VERSION)
    add("api=%s  world=%s", tostring(safe(A.get_api_version)), tostring(safe(GetWorldName)))
    local round = safe(A.get_bg_round_index)
    add("bg: active=%s  state=%s  round=%s  numRounds=%s",
        tostring(safe(A.is_active_bg)), tostring(safe(A.get_bg_state)),
        tostring(round), tostring(safe(A.get_num_rounds, safe(A.get_bg_id))))
    add("")

    add("--- live medal probe (local player) ---")
    round = round or 1
    local nEntries = safe(A.get_num_entries, round) or 0
    local localIdx = safe(A.get_local_entry_index, round)
    add("scoreboard entries=%d  localIndex=%s", nEntries, tostring(localIdx))
    if localIdx and localIdx > 0 and localIdx <= nEntries then
        safe(A.gen_cumulative_medals, localIdx, round)
        local last, found = nil, 0
        for _ = 1, 32 do
            local id = safe(A.get_next_cumulative_medal, last)
            if not id then break end
            found = found + 1
            local n = safe(A.get_cumulative_medal_count, id) or 1
            local info = BGMeter.Icons.medal_info(id)
            add("  cumulative: id=%d x%d  %s", id, n, info and info.name or "?")
            last = id
        end
        add("  cumulative path found: %d", found)
        last, found = nil, 0
        for _ = 1, 32 do
            local id = safe(A.get_next_entry_medal, localIdx, round, last)
            if not id then break end
            found = found + 1
            add("  per-round: id=%d", id)
            last = id
        end
        add("  per-round path found: %d", found)
    else
        add("  (no scoreboard data right now -- run this at match end or on the scoreboard screen)")
    end
    add("")

    local CZ = BGMeter.zenimax.constants
    add("--- objectives probe (live) ---")
    local nObj = safe(A.get_num_objectives) or 0
    add("numObjectives=%d", nObj)
    for i = 1, nObj do
        local ok, keepId, objectiveId, ctx = pcall(A.get_objective_ids, i)
        if ok and keepId and safe(A.is_bg_objective, keepId, objectiveId, ctx) then
            local otype = safe(A.get_objective_type, keepId, objectiveId, ctx)
            local name  = safe(A.get_objective_info, keepId, objectiveId, ctx)
            local desig = safe(A.get_objective_designation, keepId, objectiveId, ctx)
            local st    = safe(A.get_objective_control_state, keepId, objectiveId, ctx)
            local owner = safe(A.get_capture_area_owner, keepId, objectiveId, ctx)
            add("  [%s] %s  type=%s st=%s own=%s ids=%s:%s",
                tostring(desig ~= nil and CZ.OBJ_LETTER[desig] or "?"), tostring(name),
                tostring(otype), tostring(CZ.OBJ_STATE_LABEL[st] or st),
                tostring(owner), tostring(keepId), tostring(objectiveId))
        end
    end
    add("")

    add("--- last stored match ---")
    local m = BGMeter.History.most_recent()
    if m then
        local lr = BGMeter.Match.local_row(m)
        local tids = {}
        if m.teams then
            for _, t in ipairs(m.teams) do tids[#tids + 1] = tostring(t.team) end
        end
        add("name=%s  result=%s  rounds=%s  teams=%d (ids: %s)  rows=%d",
            tostring(m.name), tostring(m.result), tostring(m.numRounds),
            m.teams and #m.teams or 0, table.concat(tids, ","), #m.battle)
        add("gameType=%s  duration=%s  localTeam=%s",
            tostring(CZ.GAME_TYPE_LABEL[m.gameType] or m.gameType),
            F.duration(m.durationMs or 0), tostring(m.localTeam))
        add("local: medals=%s  medalIds=%d  timeline=%d samples  killfeed=%d",
            tostring(lr and lr.medals), lr and lr.medalIds and #lr.medalIds or 0,
            m.timeline and m.timeline.t and #m.timeline.t or 0,
            m.killfeed and #m.killfeed or 0)
        local ob = m.objectives
        if ob and ob.t and #ob.t > 0 then
            add("objectives: %d tracked, %d events", #ob.list, #ob.t)
            for _, o in ipairs(ob.list) do
                add("  [%s] %s (%s:%s)", tostring(o.letter), tostring(o.name),
                    tostring(o.keepId), tostring(o.objectiveId))
            end
            local counts = {}
            for i = 1, #ob.ev do
                local lbl = CZ.OBJ_EVENT_LABEL[ob.ev[i]]
                    or (ob.ev[i] == -1 and "initial" or tostring(ob.ev[i]))
                counts[lbl] = (counts[lbl] or 0) + 1
            end
            local parts = {}
            for k, v in pairs(counts) do parts[#parts + 1] = string.format("%s=%d", k, v) end
            table.sort(parts)
            add("  events by type: %s", table.concat(parts, "  "))
            local first = math.max(1, #ob.t - 39)
            if first > 1 then
                add("  (showing last %d of %d -- /bgmeter objdump for the full log)",
                    #ob.t - first + 1, #ob.t)
            end
            for i = first, #ob.t do
                local o = ob.list[ob.o[i]]
                add("  %s r%s [%s] %s st=%s own=%s",
                    F.duration(ob.t[i] or 0), tostring(ob.r and ob.r[i] or "?"),
                    o and tostring(o.letter) or "?",
                    tostring(CZ.OBJ_EVENT_LABEL[ob.ev[i]]
                        or (ob.ev[i] == -1 and "initial" or ob.ev[i])),
                    tostring(CZ.OBJ_STATE_LABEL[ob.st[i]] or ob.st[i]),
                    tostring(ob.own[i]))
            end
        else
            add("objectives: (none captured)")
        end
    else
        add("(none)")
    end
    add("")

    add("--- log tail (%d lines, [d]=debug [s]=say [e]=error) ---", #BGMeter.Log.lines())
    for _, l in ipairs(BGMeter.Log.lines()) do
        lines[#lines + 1] = l
    end

    BGMeter.UI.export.show_text(table.concat(lines, "\n"))
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
        cmd_demo(false)
    elseif args == "demo2" or args == "demo 2" then
        cmd_demo(true)
    elseif args == "last" then
        if BGMeter.History.count() == 0 then Log.say("no matches recorded yet")
        else BGMeter.UI.window.show_match(1) end
    elseif args == "export" then
        if BGMeter.History.count() == 0 then Log.say("no matches recorded yet")
        else BGMeter.UI.export.show(BGMeter.History.most_recent()) end
    elseif args == "layers" then
        BGMeter.UI.window.toggle_layers_debug()
    elseif args == "report" then
        cmd_report()
    elseif args == "objdump" then
        cmd_objdump()
    elseif args == "clear" then
        BGMeter.History.clear()
        Log.say("history cleared")
    elseif args == "debug" then
        Log.DEBUG = not Log.DEBUG
        Log.say("debug %s", Log.DEBUG and "ON" or "OFF")
    else
        Log.say("commands: |cFFFFFF/bgmeter|r [show|hide|toggle|bar|dock|fade|lock|last|export|report|objdump|demo|demo2|ap|dump|clear|debug|layers]")
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
