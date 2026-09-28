BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local Warm = { done = false, running = false, made = 0, ticks = 0 }

local NAME = "BGMeterWarmup"
local TICK_MS = 50
local STEP = 8

local TARGETS = {
    { "row_pool",       "battle.rows",   18 },
    { "dot_pool",       "chart.rects",   600 },
    { "line_pool",      "chart.lines",   700 },
    { "skull_pool",     "chart.skulls",  40 },
    { "ribbon_pool",    "ribbon.rects",  260 },
    { "pin_pool",       "ribbon.pins",   60 },
    { "occ_pool",       "occupation",    12 },
    { "race_pool",      "race.fill",     650 },
    { "race_line_pool", "race.lines",    1300 },
    { "mom_pool",       "momentum",      160 },
    { "kills_pool",     "kills",         220 },
    { "hit_pool",       "hits",          220 },
}

Warm.TARGETS = TARGETS
Warm.STEP = STEP

local function label_pools(b)
    for _, t in ipairs(TARGETS) do
        local pool = b[t[1]]
        if pool then pool.label = t[2] end
    end
end

local function busy()
    local W = BGMeter.UI.window
    if BGMeter.Capture and BGMeter.Capture.is_active() then return true end
    if W and W.in_combat and W.in_combat() then return true end
    return false
end

local function finish()
    BGMeter.zenimax.events.unregister_update(NAME)
    Warm.running = false
    Warm.done = true
    BGMeter.Log.debug("warm-up done: %d controls reserved in %d ticks", Warm.made, Warm.ticks)
end

local function tick()
    if busy() then return end
    local W = BGMeter.UI.window
    local b = W and W.battle
    if not b then finish() return end
    Warm.ticks = Warm.ticks + 1
    local budget = STEP
    for _, t in ipairs(TARGETS) do
        local pool = b[t[1]]
        if pool then
            local need = t[3] - pool:total()
            if need > 0 then
                local n = math.min(need, budget)
                Warm.made = Warm.made + pool:reserve(pool:total() + n)
                budget = budget - n
                if budget <= 0 then return end
            end
        end
    end
    finish()
end

function Warm.start()
    if Warm.done or Warm.running then return end
    local W = BGMeter.UI.window
    if not (W and W.ensure_built) then return end
    W.ensure_built()
    if not W.battle then return end
    label_pools(W.battle)
    Warm.running = true
    BGMeter.zenimax.events.register_update(NAME, TICK_MS, tick)
end

function Warm.tick_now() tick() end

function Warm.reset()
    if Warm.running then BGMeter.zenimax.events.unregister_update(NAME) end
    Warm.done, Warm.running, Warm.made, Warm.ticks = false, false, 0, 0
end

BGMeter.UI.warmup = Warm
