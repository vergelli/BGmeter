-- bgmeter :: zenimax/ui.lua
-- WINDOW_MANAGER / pooling aliases. Control creation and ZO_ObjectPool live
-- here so lib/plot and ui/ never touch the raw managers directly.

BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.zenimax = BGMeter.zenimax or {}

local WM = WINDOW_MANAGER
local M = {}

M.wm = WM

-- Anonymous controls still need a unique name in ESO; auto-generate when nil.
local _seq = 0
local function auto_name(name)
    if name and name ~= "" then return name end
    _seq = _seq + 1
    return "BGMeterAnon" .. _seq
end

function M.create_control(name, parent, ctype)
    return WM:CreateControl(auto_name(name), parent, ctype)
end

function M.create_from_virtual(name, parent, template)
    return WM:CreateControlFromVirtual(auto_name(name), parent, template)
end

function M.get_control(name)
    return WM:GetControlByName(name)
end

-- ZO_ObjectPool factory. factory_fn(pool) creates one object; reset_fn(obj)
-- clears it on release. Returns the pool.
function M.new_pool(factory_fn, reset_fn)
    return ZO_ObjectPool:New(factory_fn, reset_fn)
end

BGMeter.zenimax.ui = M
