-- bgmeter :: zenimax/scene.lua
-- SCENE_MANAGER helpers. bgmeter's window is a free-floating HUD-style panel;
-- we only need to know whether we're in a "safe to show" scene so the panel
-- doesn't float over menus.

BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.zenimax = BGMeter.zenimax or {}

local M = {}

function M.current_name()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    return scene and scene:GetName() or nil
end

-- True when we're on the world HUD (not in inventory, map, menus, etc.).
function M.is_hud_scene()
    local name = M.current_name()
    return name == "hud" or name == "hudui"
end

BGMeter.zenimax.scene = M
