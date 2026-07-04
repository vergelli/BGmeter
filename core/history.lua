-- bgmeter :: core/history.lua
-- The match history store, backed by SavedVars. Keeps a rolling list of recent
-- finished matches (newest first), trimmed to prefs.max_history. Match records
-- are plain tables, so they serialize straight into SavedVars with no encoding.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local History = {}

local function sv()
    return BGMeter.zenimax.savedvars.get()
end

-- Prepend a finished match; trim to the configured cap.
function History.push(match)
    local data = sv()
    if not data then return end
    data.matches = data.matches or {}
    table.insert(data.matches, 1, match)
    local cap = (data.prefs and data.prefs.max_history) or 50
    while #data.matches > cap do
        table.remove(data.matches)
    end
    BGMeter.Log.debug("history push -> %d stored", #data.matches)
end

function History.count()
    local data = sv()
    return (data and data.matches) and #data.matches or 0
end

-- 1 = most recent.
function History.get(index)
    local data = sv()
    if not data or not data.matches then return nil end
    return data.matches[index]
end

function History.most_recent()
    return History.get(1)
end

function History.clear()
    local data = sv()
    if data then data.matches = {} end
end

BGMeter.History = History
