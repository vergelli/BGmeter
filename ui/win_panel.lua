BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local set_text, mk_button = U.set_text, U.mk_button
local TX = U.TX

local K = BGMeter.Constants
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prefs = BGMeter.Prefs

local Panel = {}

local TELVAR = CURT_TELVAR_STONES
local LINK_SIZE = 22
local CLAIM_SIZE = 20

local stats = nil
local host = nil

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function clean(s)
    if not s or s == "" then return nil end
    return (tostring(s):gsub("%^.*$", ""))
end

local PODIUM = { name = "BGMeterPodiumGlow", ms = 40, period_ms = 1200, on = false, t0 = 0 }

local function podium_now()
    if GetGameTimeMilliseconds then return GetGameTimeMilliseconds() end
    return os.clock() * 1000
end

local function hue_rgb(h)
    local x = (h % 1) * 6
    local i = math.floor(x)
    local f = x - i
    if i == 0 then return 1, f, 0 end
    if i == 1 then return 1 - f, 1, 0 end
    if i == 2 then return 0, 1, f end
    if i == 3 then return 0, 1 - f, 1 end
    if i == 4 then return f, 0, 1 end
    return 1, 0, 1 - f
end

function Panel.podium_stop()
    if not PODIUM.on then return end
    PODIUM.on = false
    BGMeter.zenimax.events.unregister_update(PODIUM.name)
end

local function podium_tick()
    local st = stats and stats.stand
    if not (st and st.glow) or host.win:IsHidden() then Panel.podium_stop() return end
    local t = ((podium_now() - PODIUM.t0) % PODIUM.period_ms) / PODIUM.period_ms
    local r, g, b = hue_rgb(t)
    st.glow:SetColor(0.45 + 0.55 * r, 0.45 + 0.55 * g, 0.45 + 0.55 * b, 0.90)
    local r2, g2, b2 = hue_rgb(t + 0.5)
    st.icon:SetColor(0.80 + 0.20 * r2, 0.80 + 0.20 * g2, 0.80 + 0.20 * b2, 1)
end

local function podium_start()
    if PODIUM.on then return end
    PODIUM.on = true
    PODIUM.t0 = podium_now()
    BGMeter.zenimax.events.register_update(PODIUM.name, PODIUM.ms, podium_tick)
    podium_tick()
end

function Panel.podium_on() return PODIUM.on end

local function trophy_tier(rank)
    if rank <= 3 then return { 0.97, 0.97, 1.00 }, 0.90, "Champion!" end
    if rank <= 10 then return { 1.00, 0.55, 0.15 }, 0.60, "Mythic!" end
    if rank <= 50 then return { 1.00, 0.84, 0.30 }, 0.50, "Legendary" end
    return { 0.72, 0.53, 0.98 }, 0.42, "Epic"
end

local function refresh_ava()
    local A = BGMeter.zenimax.api
    local st = stats.ava
    local rank = safe(A.get_ava_rank)
    if not (rank and rank > 0) then st.c:SetHidden(true) return end
    st.c:SetHidden(false)
    local gender = safe(A.get_gender) or 1
    local rname = clean(safe(A.get_ava_rank_name, gender, rank)) or "?"
    if st.icon then st.icon:SetTexture(safe(A.get_ava_rank_icon, rank) or "") end
    set_text(st.label, string.format("%s  %d", rname, rank))
    local pts = safe(A.get_ava_rank_points) or 0
    local base = safe(A.get_ava_points_needed, rank) or 0
    local nextNeed = safe(A.get_ava_points_needed, rank + 1)
    if nextNeed and nextNeed > pts then
        st.tip = string.format("Alliance War rank %d\n%s AP to the next rank", rank, F.commas(nextNeed - pts))
    else
        st.tip = string.format("Alliance War rank %d", rank)
    end
    if st.bar then
        if nextNeed and nextNeed > base then
            local pct = math.max(0, math.min(1, (pts - base) / (nextNeed - base)))
            U.inset_bar_set(st.bar, pct, K.COLOR.gold, st.barW)
            st.bar.container:SetHidden(false)
        else
            st.bar.container:SetHidden(true)
        end
    end
end

local function refresh_vet()
    local A = BGMeter.zenimax.api
    local st = stats.vet
    local snap = BGMeter.Veterancy and BGMeter.Veterancy.snapshot()
    if st.link then st.link:SetHidden(not (snap and snap.rank)) end
    if not (snap and snap.rank) then st.c:SetHidden(true) return end
    st.c:SetHidden(false)
    if st.icon then
        st.icon:SetTexture(safe(A.get_veterancy_rank_icon, snap.iconRank or snap.rank, snap.seasonId)
            or snap.rankIcon or "")
    end
    local laps = snap.laps or 0
    set_text(st.label, string.format("%s  %d%s", clean(snap.rankTitle) or "Veterancy", snap.rank,
        laps > 0 and (" ×" .. laps) or ""))
    local waiting = snap.claimable or 0
    if st.claim then
        st.claim:SetHidden(waiting <= 0)
        st.claim_tip = string.format("Claim your veterancy rewards (%d waiting)", waiting)
        st.label:ClearAnchors()
        st.label:SetAnchor(TOPLEFT, st.c, TOPLEFT, st.textX, 3)
        st.label:SetAnchor(TOPRIGHT, st.c, TOPRIGHT, waiting > 0 and -(LINK_SIZE + CLAIM_SIZE + 4) or -(LINK_SIZE + 2), 3)
    end
    local season = clean(snap.seasonName)
    local seasonLine = season and ("\n" .. season) or ""
    if snap.tierTotal and snap.tierTotal > 0 then
        st.tip = string.format("Veterancy rank %d%s\n%s / %s to the next %s%s",
            snap.rank, laps > 0 and string.format("  ·  max rank, reward ×%d", laps) or "",
            F.commas(snap.progressToNext or 0), F.commas(snap.tierTotal),
            snap.pastMax and "reward" or "rank", seasonLine)
    else
        st.tip = string.format("Veterancy rank %d%s", snap.rank, seasonLine)
    end
    if st.bar then
        if snap.percent then
            local pct = math.max(0, math.min(1, snap.percent))
            U.inset_bar_set(st.bar, pct, K.COLOR.veterancy, st.barW)
            st.bar.container:SetHidden(false)
        else
            st.bar.container:SetHidden(true)
        end
    end
end

local function refresh_standing()
    local st = stats.stand
    local sv = BGMeter.zenimax.savedvars.get()
    local standing = sv and sv.standing
    local demo = BGMeter.UI.menu and BGMeter.UI.menu._demo_rank
    if demo then standing = { rank = demo, score = 123456 } end
    st.c:SetHidden(false)
    if st.link then st.link:SetHidden(false) end
    if standing and (standing.rank or 0) > 0 then
        local top = standing.rank <= 100
        if st.icon then
            st.icon:SetTexture(top and "EsoUI/Art/Inventory/inventory_tabIcon_trophy_up.dds"
                or "EsoUI/Art/Journal/journal_tabIcon_leaderboard_up.dds")
            local tierTag = ""
            if top then
                local col, glowA, word = trophy_tier(standing.rank)
                st.icon:SetColor(col[1], col[2], col[3], 1)
                if not st.glow then
                    st.glow = P.icon(st.c, "bgmeter/assets/glow.dds")
                    st.glow:SetAnchor(CENTER, st.icon, CENTER, 0, 0)
                    st.glow:SetDimensions(64, 64)
                    if st.glow.SetBlendMode then st.glow:SetBlendMode(TEX_BLEND_MODE_ADD) end
                    if st.glow.SetDrawLevel then st.glow:SetDrawLevel(1) end
                    if st.icon.SetDrawLevel then st.icon:SetDrawLevel(2) end
                end
                st.glow:SetColor(col[1], col[2], col[3], glowA)
                st.glow:SetHidden(false)
                if standing.rank <= 3 and Prefs.get("animate") then podium_start() else Panel.podium_stop() end
                tierTag = string.format("  ·  |c%s%s|r", F.hexc(col), word)
            else
                Panel.podium_stop()
                st.icon:SetColor(1, 1, 1, 1)
                if st.glow then st.glow:SetHidden(true) end
            end
            st.tierTag = tierTag
        end
        set_text(st.label, "#" .. F.commas(standing.rank) .. (st.tierTag or ""))
        S.color(st.label, K.COLOR.gold)
        st.tip = string.format("Competitive standing\nrating %s", F.commas(standing.score or 0))
    else
        Panel.podium_stop()
        if st.icon then
            st.icon:SetTexture("EsoUI/Art/Journal/journal_tabIcon_leaderboard_up.dds")
            st.icon:SetColor(1, 1, 1, 1)
            if st.glow then st.glow:SetHidden(true) end
        end
        set_text(st.label, "unranked")
        S.color(st.label, K.COLOR.text_dim)
        if standing and (standing.score or 0) > 0 then
            st.tip = string.format("Competitive standing\nrating %s", F.commas(standing.score))
        else
            st.tip = "Competitive standing\nplay a ranked battleground to appear"
        end
    end
end

local function refresh_currencies()
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local st = stats.ap
    st.c:SetHidden(false)
    if st.icon then st.icon:SetTexture(safe(A.get_currency_icon, C.CURT_ALLIANCE_POINTS) or "") end
    set_text(st.label, F.commas(safe(A.get_alliance_points) or 0))
    st.tip = "Alliance Points"

    st = stats.telvar
    if TELVAR then
        st.c:SetHidden(false)
        if st.icon then st.icon:SetTexture(safe(A.get_currency_icon, TELVAR) or "") end
        set_text(st.label, F.commas(safe(A.get_currency, TELVAR, C.CURRENCY_LOCATION_CHARACTER) or 0))
        st.tip = "Tel Var Stones"
    else
        st.c:SetHidden(true)
    end
end

local function refresh_session()
    local st = stats.session
    local sess = BGMeter.Session
    if sess and sess.matches > 0 then
        if (sess.streak or 0) >= 2 then
            set_text(st.label, string.format("%dW-%dL  ·  %dx streak", sess.wins, sess.losses, sess.streak))
        else
            set_text(st.label, string.format("%dW-%dL tonight", sess.wins, sess.losses))
        end
        local col = K.COLOR.text_dim
        if sess.wins > sess.losses then col = K.COLOR.heal
        elseif sess.losses > sess.wins then col = K.COLOR.accent end
        S.color(st.label, col)
        st.tip = string.format("This play session\n%d battlegrounds%s\n%s AP  ·  %s XP earned",
            sess.matches,
            (sess.streak or 0) >= 2 and string.format("\n%d wins in a row", sess.streak) or "",
            F.commas(sess.ap), F.commas(sess.xp))
    else
        local tot = BGMeter.Ledger and BGMeter.Ledger.totals() or { n = 0, w = 0, l = 0, t = 0 }
        local n, aw, al = tot.n, tot.w, tot.l
        if n == 0 then
            local Hist = BGMeter.History
            n = Hist.count()
            for i = 1, n do
                local m = Hist.get(i)
                if m.result == "WIN" then aw = aw + 1 elseif m.result == "LOSS" then al = al + 1 end
            end
        end
        if n > 0 then
            set_text(st.label, string.format("%dW-%dL all time", aw, al))
            local col = K.COLOR.text_dim
            if aw > al then col = K.COLOR.heal elseif al > aw then col = K.COLOR.accent end
            S.color(st.label, col)
            st.tip = string.format("Every battleground recorded since the ledger began\n%d battles%s\nNo battles yet this session", n,
                (tot.t > 0) and string.format("  ·  %d tied", tot.t) or "")
        else
            set_text(st.label, "no battles yet")
            S.color(st.label, K.COLOR.text_dim)
            st.tip = "This play session (since login)"
        end
    end
    st.c:SetHidden(false)
end

function Panel.refresh()
    if not stats then return end
    refresh_ava()
    refresh_vet()
    refresh_standing()
    refresh_currencies()
    refresh_session()
end

local function make_stat(pw, rowi, right, withIcon, withBar, link)
    local c = BGMeter.zenimax.ui.create_control(nil, pw, CT_CONTROL)
    local rowH = right and 28 or 38
    local iconS = right and 26 or 38
    local pad = right and 6 or 9
    c:SetHeight(rowH)
    c:SetMouseEnabled(true)
    local y = host.head_h + (rowi - 1) * (right and 30 or 40)
    if right then
        c:SetAnchor(TOPRIGHT, pw, TOPRIGHT, -(host.inset_pad + 2), y)
        c:SetWidth(126)
    else
        c:SetAnchor(TOPLEFT, pw, TOPLEFT, host.inset_pad + 2, y)
        c:SetWidth(200)
    end
    local st = { c = c }
    if withIcon then
        st.icon = P.icon(c)
        st.icon:SetDimensions(iconS, iconS)
        st.icon:SetAnchor(LEFT, c, LEFT, 0, 0)
    end
    local textX = withIcon and (iconS + pad) or 2
    st.label = P.label(c, right and S.FONT.small or S.FONT.row, K.COLOR.text)
    U.clamp_line(st.label)
    local linkInset = link and -(LINK_SIZE + 2) or 0
    if withBar then
        st.label:SetAnchor(TOPLEFT, c, TOPLEFT, textX, 3)
        st.label:SetAnchor(TOPRIGHT, c, TOPRIGHT, linkInset, 3)
        st.label:SetHeight(20)
        if link then
            st.link = mk_button(c, link.tx, LINK_SIZE, link.fn, link.tip)
            st.link:SetAnchor(TOPRIGHT, c, TOPRIGHT, 2, 1)
            st.link:SetHidden(true)
            if link.claim then
                st.textX = textX
                st.claim = mk_button(c, TX.satchel, CLAIM_SIZE, link.claim, nil)
                st.claim:SetAnchor(TOPRIGHT, c, TOPRIGHT, -(LINK_SIZE + 2), 3)
                st.claim:SetHidden(true)
                st.claim:SetHandler("OnMouseEnter", function(b)
                    if U.card_show then U.card_show(b, BOTTOM, st.claim_tip or "") end
                end)
                st.claim:SetHandler("OnMouseExit", function()
                    if U.card_hide then U.card_hide() end
                end)
            end
        end
        st.bar = U.inset_bar(c)
        st.bar.container:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, textX, -3)
        st.bar.container:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, 0, -3)
        st.bar.container:SetHeight(9)
        st.barW = 200 - textX
    else
        st.label:SetAnchor(LEFT, c, LEFT, textX, 0)
        st.label:SetAnchor(RIGHT, c, RIGHT, linkInset, 0)
        st.label:SetHeight(rowH)
        if link then
            st.link = mk_button(c, link.tx, LINK_SIZE, link.fn, link.tip)
            st.link:SetAnchor(RIGHT, c, RIGHT, 2, 0)
            st.link:SetHidden(true)
        end
    end
    c:SetHandler("OnMouseEnter", function()
        if st.tip and U.card_show then U.card_show(c, BOTTOM, st.tip) end
    end)
    c:SetHandler("OnMouseExit", function()
        if U.card_hide then U.card_hide() end
    end)
    return st
end

function Panel.build(pw, opts)
    host = { win = pw, head_h = opts.head_h, inset_pad = opts.inset_pad }
    stats = {
        ava     = make_stat(pw, 1, false, true, true),
        vet     = make_stat(pw, 2, false, true, true, { tx = TX.vet, fn = opts.open_veterancy, tip = "View veterancy",
                                                      claim = opts.claim_veterancy }),
        stand   = make_stat(pw, 3, false, true, false, { tx = TX.board, fn = opts.open_leaderboard, tip = "View competitive leaderboard" }),
        ap      = make_stat(pw, 1, true, true),
        telvar  = make_stat(pw, 2, true, true),
        session = make_stat(pw, 3, true, false),
    }
    for _, key in ipairs({ "ap", "telvar" }) do
        local lbl = stats[key].label
        if lbl.SetFont then lbl:SetFont(S.FONT.row) end
    end
    return stats
end

function Panel.stats() return stats end

function Panel.stat_text(key) return stats and stats[key] and stats[key].label:GetText() or nil end

function Panel.stat_link_hidden(key)
    local st = stats and stats[key]
    return not (st and st.link) or st.link:IsHidden()
end

function Panel.stat_link_texture(key)
    local st = stats and stats[key]
    return st and st.link and st.link._tex_normal or nil
end

function Panel.stat_claim_hidden(key)
    local st = stats and stats[key]
    return not (st and st.claim) or st.claim:IsHidden()
end

function Panel.stat_claim_tip(key)
    local st = stats and stats[key]
    return st and st.claim_tip or nil
end

BGMeter.UI.panel = Panel
