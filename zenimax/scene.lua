
BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.zenimax = BGMeter.zenimax or {}

local M = {}

function M.current_name()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    return scene and scene:GetName() or nil
end

function M.is_hud_scene()
    local name = M.current_name()
    return name == "hud" or name == "hudui"
end

function M.register_top_level(control)
    local s = SCENE_MANAGER
    if not s or type(s.RegisterTopLevel) ~= "function" then return false end
    return pcall(function() s:RegisterTopLevel(control, false) end)
end

function M.show_top_level(control)
    local s = SCENE_MANAGER
    if s and type(s.ShowTopLevel) == "function" then pcall(function() s:ShowTopLevel(control) end) end
    if control:IsHidden() then control:SetHidden(false) end
end

function M.hide_top_level(control)
    local s = SCENE_MANAGER
    if s and type(s.HideTopLevel) == "function" then pcall(function() s:HideTopLevel(control) end) end
    if not control:IsHidden() then control:SetHidden(true) end
end

function M.push(name)
    local s = SCENE_MANAGER
    if not s or type(s.Push) ~= "function" then return false end
    return pcall(function() s:Push(name) end)
end

function M.next_is_hud()
    local sm = SCENE_MANAGER
    if not sm or type(sm.GetNextScene) ~= "function" then return false end
    local ok, nxt = pcall(function() return sm:GetNextScene() end)
    if not ok or not nxt or type(nxt.GetName) ~= "function" then return false end
    local name = nxt:GetName()
    return name == "hud" or name == "hudui"
end

BGMeter.zenimax.scene = M
