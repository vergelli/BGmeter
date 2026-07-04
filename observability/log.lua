-- bgmeter :: observability/log.lua
-- Minimal structured logging. DEBUG-gated chat output with a coloured prefix.
-- Flip BGMeter.Log.DEBUG to true (or `/bgmeter debug`) to see internals.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Log = {}
Log.DEBUG = false

local PREFIX = "|cE34234[bgmeter]|r "   -- vermilion-ish red, brand placeholder

local function emit(color, fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(PREFIX .. "|c" .. color .. msg .. "|r")
    end
end

-- Always shown -- user-facing output (dump results, confirmations).
function Log.say(fmt, ...) emit("FFFFFF", fmt, ...) end

-- DEBUG-gated -- internal tracing.
function Log.debug(fmt, ...)
    if Log.DEBUG then emit("AAAAAA", fmt, ...) end
end

-- Always shown -- errors are never swallowed silently.
function Log.error(fmt, ...) emit("FF4040", fmt, ...) end

BGMeter.Log = Log
