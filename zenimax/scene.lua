
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

function M.next_is_hud()
    local sm = SCENE_MANAGER
    if not sm or type(sm.GetNextScene) ~= "function" then return false end
    local ok, nxt = pcall(function() return sm:GetNextScene() end)
    if not ok or not nxt or type(nxt.GetName) ~= "function" then return false end
    local name = nxt:GetName()
    return name == "hud" or name == "hudui"
end

BGMeter.zenimax.scene = M
