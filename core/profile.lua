BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Profile = {}

Profile.AXES = { "killer", "brawler", "anchor", "medic", "team", "objective" }
Profile.NAMES = { killer = "Killer", brawler = "Brawler", anchor = "Anchor", medic = "Medic", team = "Team", objective = "Objective" }
Profile.PAIR = {
    killer    = { brawler = "Slayer" },
    brawler   = { anchor = "Bruiser" },
    anchor    = { medic = "Guardian" },
    medic     = { team = "Healer" },
    team      = { objective = "Captain" },
    objective = { killer = "Hunter" },
}
Profile.BALANCED = "Balanced"
Profile.SPREAD = 0.15
Profile.NEAR = 0.10

local function mode_key(m)
    local C = BGMeter.zenimax.constants
    if m and m.gameType ~= nil and C.GAME_TYPE_LABEL then
        return C.GAME_TYPE_LABEL[m.gameType] or "none"
    end
    return "none"
end
Profile.mode_key = mode_key

function Profile.objective(row, key)
    if key == "capture_the_flag" then
        return (row.caps or 0) * 3 + (row.carrierKills or 0) + (row.carried or 0) / 30
    elseif key == "murderball" then
        return (row.carried or 0) / 10 + (row.carrierKills or 0)
    elseif key == "domination" or key == "crazy_king" or key == "king_of_the_hill" then
        return row.defPts or 0
    end
    return 0
end

function Profile.raw(row, key, out)
    out = out or {}
    out[1] = row.kills or 0
    out[2] = row.damage or 0
    out[3] = row.taken or 0
    out[4] = row.healing or 0
    out[5] = row.assists or 0
    out[6] = Profile.objective(row, key)
    return out
end

function Profile.compute(m)
    if not (m and m.battle and #m.battle >= 2) then return nil end
    local key = mode_key(m)
    local n = #m.battle
    local raws = {}
    local has_obj = false
    for i = 1, n do
        raws[i] = Profile.raw(m.battle[i], key)
        if raws[i][6] > 0 then has_obj = true end
    end
    local axes = {}
    local na = (key == "deathmatch" or not has_obj) and 5 or 6
    for a = 1, na do axes[a] = Profile.AXES[a] end
    local players = {}
    for i = 1, n do
        players[i] = { row = m.battle[i], team = m.battle[i].team or 0, v = {} }
    end
    for a = 1, na do
        for i = 1, n do
            local mine, below = raws[i][a], 0
            for j = 1, n do
                if raws[j][a] < mine then below = below + 1 end
            end
            players[i].v[a] = below / (n - 1)
        end
    end
    local teams = {}
    for i = 1, n do
        local t = players[i].team
        local tm = teams[t]
        if not tm then
            tm = { v = {}, n = 0 }
            for a = 1, na do tm.v[a] = 0 end
            teams[t] = tm
        end
        tm.n = tm.n + 1
        for a = 1, na do tm.v[a] = tm.v[a] + players[i].v[a] end
    end
    for _, tm in pairs(teams) do
        for a = 1, na do tm.v[a] = tm.v[a] / tm.n end
    end
    local me = nil
    for i = 1, n do
        if players[i].row.isLocal then me = i end
    end
    return { mode = key, axes = axes, players = players, teams = teams, me = me, n = n }
end

function Profile.index_of(data, row)
    if not (data and row) then return nil end
    for i = 1, data.n do
        local r = data.players[i].row
        if r == row then return i end
    end
    local dn, cn = row.displayName, row.charName
    for i = 1, data.n do
        local r = data.players[i].row
        if (dn and dn ~= "" and r.displayName == dn) or (cn and cn ~= "" and r.charName == cn) then return i end
    end
    return nil
end

function Profile.label(v, axes)
    local na = axes and #axes or 0
    if na == 0 then return Profile.BALANCED end
    local sum, top, ti = 0, -1, 1
    for a = 1, na do
        local x = v[a] or 0
        sum = sum + x
        if x > top then top, ti = x, a end
    end
    if top - sum / na < Profile.SPREAD then return Profile.BALANCED end
    local nxt = (ti % na) + 1
    local prv = ((ti - 2) % na) + 1
    local vn, vp = v[nxt] or 0, v[prv] or 0
    local best, with = nil, nil
    if vn >= top - Profile.NEAR then best, with = vn, nxt end
    if vp >= top - Profile.NEAR and (best == nil or vp > best) then best, with = vp, prv end
    if with then
        local a, b = axes[ti], axes[with]
        local pair = (Profile.PAIR[a] and Profile.PAIR[a][b]) or (Profile.PAIR[b] and Profile.PAIR[b][a])
        if pair then return pair end
    end
    return Profile.NAMES[axes[ti]]
end

function Profile.career(matches, limit)
    local sum, cnt = {}, {}
    for a = 1, 6 do sum[a], cnt[a] = 0, 0 end
    local used = 0
    for i = 1, #matches do
        if limit and used >= limit then break end
        local data = Profile.compute(matches[i])
        if data and data.me then
            used = used + 1
            local v = data.players[data.me].v
            for a = 1, #data.axes do
                sum[a] = sum[a] + v[a]
                cnt[a] = cnt[a] + 1
            end
        end
    end
    if used == 0 then return nil end
    local v, axes = {}, {}
    local na = 0
    for a = 1, 6 do
        if cnt[a] > 0 then
            na = na + 1
            axes[na] = Profile.AXES[a]
            v[na] = sum[a] / cnt[a]
        end
    end
    return { v = v, axes = axes, n = used }
end

BGMeter.Profile = Profile
