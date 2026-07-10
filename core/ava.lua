-- bgmeter :: core/ava.lua
-- The AvA / Cyrodiil session engine -- the "transversal" half of bgmeter that
-- lives OUTSIDE the battleground scoreboard. In open-world AvA there is no
-- post-match moment, so we keep a rolling session: it opens when you enter an
-- AvA world (Cyrodiil / Imperial City), accumulates the AP you earn split BY
-- SOURCE (kills / keep offense / keep defense / resurrects / other), tracks XP,
-- and snapshots your veterancy at the start so the haul reads as "this session".
--
-- The veterancy reward-track itself is AvA-wide (the same season track in BGs
-- and Cyrodiil); this module owns the AP-by-source attribution and an observer
-- fan-out any consumer can subscribe to.
--
-- Everything is pcall-guarded and zero-alloc on the hot path is NOT a concern
-- here (AP events fire a few times a second at most), so clarity wins.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Ava = {}

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

-- ── source buckets ──────────────────────────────────────────────────────────
-- Render order + display metadata for the AP-by-source breakdown. `color` is a
-- self-contained RGBA swatch (kept here, not in K.COLOR, so the buckets own
-- their own identity) used for the HUD breakdown rows + the stacked mini-bar.
Ava.SOURCES = {
    { key = "kills",   label = "Kills",        color = { 0.89, 0.26, 0.20, 1 } },  -- vermilion
    { key = "offense", label = "Keep offense", color = { 0.95, 0.80, 0.35, 1 } },  -- gold
    { key = "defense", label = "Keep defense", color = { 0.35, 0.65, 0.85, 1 } },  -- storm blue
    { key = "rez",     label = "Resurrects",   color = { 0.30, 0.78, 0.45, 1 } },  -- verdant green
    { key = "bg",      label = "Battlegrounds",color = { 0.55, 0.50, 0.95, 1 } },  -- violet
    { key = "other",   label = "Other",        color = { 0.55, 0.55, 0.60, 1 } },  -- dim
}

-- reason enum -> bucket key. Built lazily (after constants load) and cached.
local _reason_map = nil
local function reason_map()
    if _reason_map then return _reason_map end
    local R = BGMeter.zenimax.constants.AP_REASON or {}
    local m = {}
    if R.KILL          ~= nil then m[R.KILL]          = "kills"   end
    if R.KILL_TRANSFER ~= nil then m[R.KILL_TRANSFER] = "kills"   end
    if R.KEEP_OFFENSE  ~= nil then m[R.KEEP_OFFENSE]  = "offense" end
    if R.KEEP_DEFENSE  ~= nil then m[R.KEEP_DEFENSE]  = "defense" end
    if R.RESURRECT     ~= nil then m[R.RESURRECT]     = "rez"     end
    if R.BATTLEGROUND  ~= nil then m[R.BATTLEGROUND]  = "bg"      end
    _reason_map = m
    return m
end

local function bucket_for(reason)
    if reason == nil then return "other" end
    return reason_map()[reason] or "other"
end

-- ── session state ───────────────────────────────────────────────────────────
-- A fresh, empty tally. `sources` holds per-bucket AP totals.
local function blank_session()
    return {
        active   = false,
        startMs  = safe(BGMeter.zenimax.api.now_ms) or 0,
        ap       = 0,            -- total AP gained this session
        xp       = 0,            -- total XP gained this session
        gains    = 0,            -- number of AP gain events (for sanity / probe)
        zone     = nil,
        vetStart = nil,          -- veterancy snapshot when the session opened
        sources  = { kills = 0, offense = 0, defense = 0, rez = 0, bg = 0, other = 0 },
    }
end

Ava.session = blank_session()

-- Debug probe toggle: when true, each AP gain is echoed to chat with its reason
-- so we can confirm the live `reason` codes BEFORE trusting the breakdown.
Ava.probe = false

-- ── AvA presence ────────────────────────────────────────────────────────────
function Ava.in_ava()
    local A = BGMeter.zenimax.api
    local v = safe(A.is_player_in_ava_world)
    if v == nil then v = safe(A.is_in_ava_zone) end
    return v and true or false
end

-- ── lifecycle ───────────────────────────────────────────────────────────────
function Ava.begin_session()
    local A = BGMeter.zenimax.api
    local s = blank_session()
    s.active   = true
    s.startMs  = safe(A.now_ms) or 0
    s.zone     = safe(A.get_zone_name)
    s.vetStart = BGMeter.Veterancy and BGMeter.Veterancy.snapshot() or nil
    Ava.session = s
    BGMeter.Log.debug("ava session begin: zone=%s", tostring(s.zone))
end

function Ava.end_session()
    if not Ava.session.active then return end
    Ava.session.active = false
    BGMeter.Log.debug("ava session end: ap=%d", Ava.session.ap)
end

-- Manual reset (slash command / settings): start a clean tally in place.
function Ava.reset()
    if Ava.in_ava() then Ava.begin_session()
    else Ava.session = blank_session() end
end

-- ── event handlers ──────────────────────────────────────────────────────────

-- AP changed. Signature: (eventCode, alliancePoints, playSound, difference, reason).
function Ava.on_ap(_, _alliancePoints, _playSound, difference, reason)
    if not difference or difference <= 0 then return end   -- ignore spends/zero
    if not Ava.in_ava() then
        -- Out of AvA (e.g. a quest reward in a city): never opens a session, but
        -- still echo for the probe so we can see every reason code in the wild.
        if Ava.probe then
            BGMeter.Log.say("|cffd700AP|r +%d  reason=%s (outside AvA)",
                difference, tostring(reason))
        end
        return
    end

    if not Ava.session.active then Ava.begin_session() end
    local s = Ava.session
    local bucket = bucket_for(reason)
    s.ap = s.ap + difference
    s.sources[bucket] = (s.sources[bucket] or 0) + difference
    s.gains = s.gains + 1

    if Ava.probe then
        BGMeter.Log.say("|cffd700AP|r +%d  reason=%s  -> %s  (session %s)",
            difference, tostring(reason), bucket, BGMeter.Format.commas(s.ap))
    end
end

-- XP changed. Signature: (eventCode, reason, level, previousXp, currentXp).
function Ava.on_xp(_, _reason, _level, prev, current)
    if not Ava.session.active then return end
    if not prev or not current then return end
    Ava.session.xp = Ava.session.xp + math.max(0, current - prev)
end


-- Player loaded a zone -- open or close the session as AvA presence changes.
function Ava.on_player_activated()
    if Ava.in_ava() then
        if not Ava.session.active then Ava.begin_session() end
    else
        Ava.end_session()
    end
end

-- ── derived read-outs (for the HUD + probe) ─────────────────────────────────

-- AP per hour at the current session pace (0 when the session is too young).
function Ava.ap_per_hour()
    local s = Ava.session
    local nowMs = safe(BGMeter.zenimax.api.now_ms) or s.startMs
    local hours = (nowMs - s.startMs) / 3600000
    if hours <= 0.0001 then return 0 end
    return s.ap / hours
end

-- The breakdown as an ordered list of { key, label, color, ap, pct } -- only the
-- buckets that actually earned something, biggest first.
function Ava.breakdown()
    local s = Ava.session
    local total = s.ap > 0 and s.ap or 1
    local out = {}
    for _, src in ipairs(Ava.SOURCES) do
        local ap = s.sources[src.key] or 0
        if ap > 0 then
            out[#out + 1] = { key = src.key, label = src.label, color = src.color,
                              ap = ap, pct = ap / total }
        end
    end
    table.sort(out, function(a, b) return a.ap > b.ap end)
    return out
end

-- One-line text summary for the probe / the main window footer.
function Ava.summary()
    local s = Ava.session
    if s.ap == 0 and not s.active then return nil end
    local F = BGMeter.Format
    return string.format("AvA session: %s AP  ·  %s AP/hr  ·  %s XP%s",
        F.commas(s.ap), F.commas(Ava.ap_per_hour()), F.commas(s.xp),
        s.active and "" or "  (ended)")
end

-- ── init ────────────────────────────────────────────────────────────────────
function Ava.init()
    local E = BGMeter.zenimax.events
    local C = BGMeter.zenimax.constants
    local P = "BGMeterAva_"

    E.register(P .. "AP",   C.EVENT_ALLIANCE_POINT_UPDATE,        Ava.on_ap)
    E.register(P .. "XP",   C.EVENT_EXPERIENCE_GAIN,              Ava.on_xp)
    E.register(P .. "Zone", C.EVENT_PLAYER_ACTIVATED,             Ava.on_player_activated)

    -- If we reload while already standing in Cyrodiil, open the session now.
    if Ava.in_ava() then Ava.begin_session() end
    BGMeter.Log.debug("ava engine wired (in_ava=%s)", tostring(Ava.in_ava()))
end

BGMeter.Ava = Ava
