-- bgmeter :: core/format.lua
-- Presentation-time number/time formatting. Big combat numbers get abbreviated
-- (412331 -> "412k"), durations get mm:ss, seconds-remaining get "4d 11h".

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local F = {}

-- 412331 -> "412k", 1284000 -> "1.28M". Keeps small numbers exact.
function F.abbrev(n)
    n = n or 0
    if n < 1000 then
        return tostring(n)
    elseif n < 1000000 then
        local k = n / 1000
        if k < 10 then return string.format("%.1fk", k) end
        return string.format("%dk", math.floor(k + 0.5))
    else
        return string.format("%.2fM", n / 1000000)
    end
end

-- Exact thousands separator: 14200 -> "14,200".
function F.commas(n)
    local s = tostring(math.floor((n or 0) + 0.5))
    local out, count = "", 0
    for i = #s, 1, -1 do
        out = s:sub(i, i) .. out
        count = count + 1
        if count % 3 == 0 and i > 1 then out = "," .. out end
    end
    return out
end

-- ms duration -> "mm:ss".
function F.duration(ms)
    local total = math.floor((ms or 0) / 1000)
    local m = math.floor(total / 60)
    local s = total % 60
    return string.format("%d:%02d", m, s)
end

-- seconds -> "4d 11h" / "11h 30m" / "12m".
function F.countdown(seconds)
    seconds = seconds or 0
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then return string.format("%dd %dh", d, h) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

-- Signed delta for the haul: 14200 -> "+14,200", 0 -> "+0".
function F.signed(n)
    return "+" .. F.commas(n or 0)
end

-- Inline texture markup for a label string: F.icon(path, 16) -> "|t16:16:path|t".
-- Used instead of unicode glyphs (★ ▲ ▼) which render as boxes in several ESO
-- fonts; a real texture always draws. size defaults to 16px square.
function F.icon(path, size)
    if not path then return "" end
    size = size or 16
    return string.format("|t%d:%d:%s|t", size, size, path)
end

-- Rate with one decimal: F.rate(14200, durationMs) -> per-minute.
function F.per_minute(total, ms)
    local minutes = (ms or 0) / 60000
    if minutes <= 0 then return 0 end
    return total / minutes
end

BGMeter.Format = F
