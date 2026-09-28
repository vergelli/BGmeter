BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Diag = { on = false }

local now = GetGameTimeMilliseconds
local gcc = collectgarbage

local STALL_MS = 1000

local frame = { n = 0, ms = 0, max = 0, maxAt = 0, b8 = 0, b16 = 0, b25 = 0, b33 = 0, bx = 0, last = 0,
                stalls = 0, stallMs = 0, stallMax = 0 }
local heap = { cur = 0, min = math.huge, max = 0, alloc = 0, cycles = 0, last = 0 }
local gp = { active = false, result = nil }
local armedAt = 0

local function on_frame()
    local t = now()
    local last = frame.last
    frame.last = t
    if last == 0 then return end
    local dt = t - last
    if dt > STALL_MS then
        frame.stalls = frame.stalls + 1
        frame.stallMs = frame.stallMs + dt
        if dt > frame.stallMax then frame.stallMax = dt end
    else
        frame.n = frame.n + 1
        frame.ms = frame.ms + dt
        if dt > frame.max then frame.max = dt; frame.maxAt = t - armedAt end
        if dt <= 8 then frame.b8 = frame.b8 + 1
        elseif dt <= 16 then frame.b16 = frame.b16 + 1
        elseif dt <= 25 then frame.b25 = frame.b25 + 1
        elseif dt <= 33 then frame.b33 = frame.b33 + 1
        else frame.bx = frame.bx + 1 end
    end

    if gp.active then
        local kb = gcc("count")
        local d = kb - gp.last
        gp.last = kb
        gp.frames = gp.frames + 1
        if d >= 0 then
            gp.kb = gp.kb + d
            if d > gp.maxKb then gp.maxKb = d end
        else
            gp.cycles = gp.cycles + 1
        end
        if t >= gp.tEnd then
            gp.active = false
            local secs = (t - gp.t0) / 1000
            gp.result = string.format(
                "gcprobe: %.1f KB alloc in %.1fs over %d frames  ·  %.0f B/frame  ·  %.1f KB/s  ·  %d GC cycles  ·  worst frame %.1f KB",
                gp.kb, secs, gp.frames,
                gp.frames > 0 and (gp.kb * 1024 / gp.frames) or 0,
                secs > 0 and (gp.kb / secs) or 0,
                gp.cycles, gp.maxKb)
            BGMeter.Log.say(gp.result)
        end
    end
end

local function on_heap()
    local kb = gcc("count")
    if heap.last > 0 then
        local d = kb - heap.last
        if d >= 0 then heap.alloc = heap.alloc + d else heap.cycles = heap.cycles + 1 end
    end
    heap.last = kb
    heap.cur = kb
    if kb < heap.min then heap.min = kb end
    if kb > heap.max then heap.max = kb end
end

function Diag.gcprobe(sec)
    if not Diag.on then return end
    sec = sec or 10
    gp.active = true
    gp.t0 = now()
    gp.tEnd = gp.t0 + sec * 1000
    gp.frames, gp.kb, gp.cycles, gp.maxKb = 0, 0, 0, 0
    gp.last = gcc("count")
    BGMeter.Log.say("gcprobe armed for %ds -- play normally, result prints when done", sec)
end

function Diag.reset()
    BGMeter.Prof.reset()
    BGMeter.Validate.reset()
    frame.n, frame.ms, frame.max, frame.maxAt = 0, 0, 0, 0
    frame.b8, frame.b16, frame.b25, frame.b33, frame.bx, frame.last = 0, 0, 0, 0, 0, 0
    frame.stalls, frame.stallMs, frame.stallMax = 0, 0, 0
    heap.min, heap.max, heap.alloc, heap.cycles, heap.last = math.huge, 0, 0, 0, 0
    gp.result = nil
    armedAt = now()
end

function Diag.lines()
    local F = BGMeter.Format
    local L = {}
    local function add(fmt, ...)
        if select("#", ...) > 0 then L[#L + 1] = string.format(fmt, ...)
        else L[#L + 1] = fmt end
    end

    add("--- diag layer (dev build)  ·  armed %s ago ---", F.duration(now() - armedAt))

    if frame.n > 0 then
        local avg = frame.ms / frame.n
        add("frames: %d sampled  ·  avg %.1fms (%.0f fps)  ·  worst %dms at %s",
            frame.n, avg, avg > 0 and (1000 / avg) or 0, frame.max, F.duration(frame.maxAt))
        add("  histogram: <=8ms %d%%  ·  <=16ms %d%%  ·  <=25ms %d%%  ·  <=33ms %d%%  ·  >33ms %d (%d%%)",
            math.floor(frame.b8 / frame.n * 100 + 0.5),
            math.floor(frame.b16 / frame.n * 100 + 0.5),
            math.floor(frame.b25 / frame.n * 100 + 0.5),
            math.floor(frame.b33 / frame.n * 100 + 0.5),
            frame.bx, math.floor(frame.bx / frame.n * 100 + 0.5))
        if frame.stalls > 0 then
            add("  stalls >%ds (loading screens etc, excluded above): %d  ·  worst %.1fs",
                math.floor(STALL_MS / 1000), frame.stalls, frame.stallMax / 1000)
        end
    else
        add("frames: (no samples yet)")
    end

    add("heap: %.0f KB now  ·  min %.0f  max %.0f  ·  +%.0f KB churned  ·  %d GC cycles seen",
        heap.cur, heap.min == math.huge and 0 or heap.min, heap.max, heap.alloc, heap.cycles)

    if gp.result then add(gp.result) end
    if gp.active then add("gcprobe: RUNNING") end

    for _, l in ipairs(BGMeter.Prof.lines()) do L[#L + 1] = l end
    for _, l in ipairs(BGMeter.Validate.lines()) do L[#L + 1] = l end
    return L
end

function Diag.install()
    if Diag.on then return end
    local K = BGMeter.Constants
    if not (K and K.dev_tools and K.dev_tools()) then return end
    Diag.on = true
    armedAt = now()

    local Prof = BGMeter.Prof
    local E = BGMeter.zenimax.events
    local reg, regu = E.register, E.register_update
    E.register = function(name, code, handler)
        return reg(name, code, Prof.wrap("ev:" .. name, handler))
    end
    E.register_update = function(name, ms, handler)
        return regu(name, ms, Prof.wrap("up:" .. name, handler))
    end
    Prof.install()

    regu("BGMeterDiagFrame", 0, on_frame)
    regu("BGMeterDiagHeap", 1000, on_heap)

    BGMeter.Log.debug("diag layer armed (frame + heap samplers, profiler spans, validation layer)")
end

BGMeter.Diag = Diag
