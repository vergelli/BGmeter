BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Log = {}
Log.DEBUG = false

local PREFIX = "|cE34234[bgmeter]|r "

local ring = {}
local RING_CAP = 600
local ring_n = 0

local function remember(tag, msg)
    ring_n = ring_n + 1
    ring[#ring + 1] = string.format("%04d %s %s", ring_n, tag, msg)
    if #ring > RING_CAP then table.remove(ring, 1) end
end

local function format_msg(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    return msg
end

local function chat(color, msg)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(PREFIX .. "|c" .. color .. msg .. "|r")
    end
end

function Log.say(fmt, ...)
    local msg = format_msg(fmt, ...)
    remember("[s]", msg)
    chat("FFFFFF", msg)
end

function Log.debug(fmt, ...)
    local msg = format_msg(fmt, ...)
    remember("[d]", msg)
    if Log.DEBUG then chat("AAAAAA", msg) end
end

function Log.error(fmt, ...)
    local msg = format_msg(fmt, ...)
    remember("[e]", msg)
    chat("FF4040", msg)
end

function Log.lines()
    local out = {}
    for i = 1, #ring do out[i] = ring[i] end
    return out
end

BGMeter.Log = Log
