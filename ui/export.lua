BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local E = {}
local controls = nil
local MAX_CHARS = 200000

local function team_label(team)
    local A = BGMeter.zenimax.api
    if team == nil then return "" end
    local ok, name = pcall(A.get_team_name, team)
    if ok and name and name ~= "" then return name end
    return "Team " .. tostring(team)
end

local function pad(s, w)
    s = tostring(s or "")
    if #s >= w then return s end
    return s .. string.rep(" ", w - #s)
end

local function rpad(s, w)
    s = tostring(s or "")
    if #s >= w then return s end
    return string.rep(" ", w - #s) .. s
end

function E.build_text(m)
    local F = BGMeter.Format
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    add(string.format("bgmeter export -- %s", tostring(m.name or "Battleground")))
    add(string.format("result: %s  ·  duration: %s%s",
        tostring(m.result or "?"), F.duration(m.durationMs or 0),
        (m.numRounds and m.numRounds > 1) and ("  ·  rounds: " .. m.numRounds) or ""))
    add("")

    if m.teams and #m.teams > 0 then
        local parts = {}
        for _, t in ipairs(m.teams) do
            local seg = string.format("%s %s", team_label(t.team), F.commas(t.score or 0))
            if (m.numRounds or 1) > 1 then seg = seg .. string.format(" (%dR)", t.roundsWon or 0) end
            parts[#parts + 1] = seg
        end
        add("teams: " .. table.concat(parts, "  ·  "))
        add("")
    end

    local showCaps = (m.objectives and m.objectives.list and #m.objectives.list > 0) or false
    for _, r in ipairs(m.battle) do
        if (r.caps or 0) > 0 or (r.carried or 0) > 0 then showCaps = true end
    end
    local CZ = BGMeter.zenimax.constants
    local gt = CZ.GAME_TYPE_LABEL and CZ.GAME_TYPE_LABEL[m.gameType] or nil
    local hold = gt == "murderball"
    local function flagcell(r)
        if hold then return (r.carried or 0) > 0 and F.duration(r.carried * 1000) or "0" end
        local v = (r.caps or 0) + 0
        if gt == "capture_the_flag" then v = math.floor(v / 100 + 0.5) end
        return v
    end
    add(pad("PLAYER", 24) .. pad("TEAM", 13) .. rpad("DMG", 9) .. rpad("HEAL", 9)
        .. rpad("TAKEN", 9) .. rpad("K", 4) .. rpad("D", 4) .. rpad("A", 4)
        .. (showCaps and rpad(hold and "HOLD" or "CAP", 7) or "")
        .. rpad("PTS", 8) .. rpad("MEDALS", 8))
    add(string.rep("-", showCaps and 99 or 92))
    BGMeter.Match.sort(m, "damage", true)
    for _, r in ipairs(m.battle) do
        local nm = (r.displayName or r.charName or "?")
        if r.isLocal then nm = nm .. " *" end
        add(pad(nm, 24) .. pad(team_label(r.team), 13)
            .. rpad((r.damage or 0) + 0, 9) .. rpad((r.healing or 0) + 0, 9) .. rpad((r.taken or 0) + 0, 9)
            .. rpad((r.kills or 0) + 0, 4) .. rpad((r.deaths or 0) + 0, 4) .. rpad((r.assists or 0) + 0, 4)
            .. (showCaps and rpad(flagcell(r), 7) or "")
            .. rpad((r.score or 0) + 0, 8) .. rpad((r.medals or 0) + 0, 8))
    end
    add("")

    local h = m.haul or {}
    add(string.format("haul: +%s AP  ·  +%s XP  ·  +%s CP  ·  %d medals",
        F.commas(h.apGained or 0), F.commas(h.xpGained or 0), F.commas(h.cpGained or 0), h.medals or 0))
    add(string.format("rates: %s AP/min  ·  %s AP/kill  ·  %s XP/min",
        F.commas(h.apPerMin or 0), F.commas(h.apPerKill or 0), F.commas(h.xpPerMin or 0)))

    local vet = h.vetEnd
    if vet and vet.rank then
        add(string.format("veterancy: %s (tier %s)%s",
            vet.rankTitle or ("rank " .. tostring(vet.rank)), tostring(vet.tier or "?"),
            h.vetRankUp and "  ·  RANK UP this match" or ""))
    end

    local st = m.standing
    if st and st.rank and st.rank > 0 then
        add(string.format("standing: #%d  ·  rating %s%s", st.rank, F.commas(st.score or 0),
            (st.rankDelta and st.rankDelta ~= 0) and string.format("  ·  moved %+d", st.rankDelta) or ""))
    end

    local session = BGMeter.Session and BGMeter.Session.summary()
    if session then add(session) end

    return table.concat(lines, "\n")
end

local function build()
    if controls then return end
    local ui = BGMeter.zenimax.ui
    local K = BGMeter.Constants
    local P = BGMeter.Plot.primitives
    local S = BGMeter.Plot.style

    local win = ui.wm:CreateTopLevelWindow("BGMeterExportWindow")
    win:SetDimensions(640, 480)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetDrawTier(DT_HIGH)

    local bg = P.rect(win, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.98 })
    bg:SetAnchorFill(win)
    P.frame(win):SetAnchorFill(win)

    local strip = P.rect(win, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    local title = P.label(win, S.FONT.title, K.COLOR.text)
    title:SetText("bgmeter  ·  Export")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 14)

    local hint = P.label(win, S.FONT.small, K.COLOR.text_dim)
    hint:SetText("Select All, then Ctrl+C to copy")
    hint:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 4)

    local closeX = P.button(win, "EsoUI/Art/Buttons/decline_up.dds",
        "EsoUI/Art/Buttons/decline_down.dds", "EsoUI/Art/Buttons/decline_over.dds")
    closeX:SetDimensions(20, 20)
    closeX:SetAnchor(TOPRIGHT, win, TOPRIGHT, -14, 14)
    closeX:SetHandler("OnClicked", function() E.hide() end)

    local ebbg = ui.create_from_virtual(nil, win, "ZO_MultiLineEditBackdrop_Keyboard")
    ebbg:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 62)
    ebbg:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, -52)

    local edit = ui.create_from_virtual("BGMeterExportEdit", ebbg, "ZO_DefaultEditMultiLineForBackdrop")
    edit:SetMaxInputChars(MAX_CHARS)
    edit:SetFont("ZoFontChat")

    local selall = ui.create_from_virtual(nil, win, "ZO_DefaultButton")
    selall:SetDimensions(150, 28)
    selall:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 16, -14)
    selall:SetText("Select All")
    selall:SetHandler("OnClicked", function() edit:TakeFocus(); edit:SelectAll() end)

    local closebtn = ui.create_from_virtual(nil, win, "ZO_DefaultButton")
    closebtn:SetDimensions(120, 28)
    closebtn:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, -14)
    closebtn:SetText("Close")
    closebtn:SetHandler("OnClicked", function() E.hide() end)

    controls = { window = win, edit = edit }
end

function E.show_text(text)
    build()
    controls.edit:SetText(text or "")
    controls.window:SetHidden(false)
    controls.edit:TakeFocus()
    controls.edit:SelectAll()
end

function E.show(m)
    if not m then
        BGMeter.Log.say("no match to export")
        return
    end
    local ok, text = pcall(E.build_text, m)
    if not ok then
        BGMeter.Log.error("export failed: %s", tostring(text))
        return
    end
    E.show_text(text)
end

function E.hide()
    if controls then controls.window:SetHidden(true) end
end

function E.toggle(m)
    if controls and not controls.window:IsHidden() then E.hide() else E.show(m) end
end

BGMeter.UI.export = E
