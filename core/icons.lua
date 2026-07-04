-- bgmeter :: core/icons.lua
-- Texture-path helpers. Uses only stock ESO art (guaranteed present) so the UI
-- looks native with zero authored assets. Class icons come from the engine;
-- role icons are the LFG art used everywhere in the base UI.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Icons = {}

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return v
end

-- Class icon for a scoreboard entry's classId (DK, Sorc, NB, Templar, Warden,
-- Necro, Arcanist...). Returns a texture path or nil.
function Icons.class(classId)
    if not classId or classId == 0 then return nil end
    return safe(GetClassIcon, classId)
end

Icons.ROLE = {
    dps    = "EsoUI/Art/LFG/LFG_icon_dps.dds",
    healer = "EsoUI/Art/LFG/LFG_icon_healer.dds",
    tank   = "EsoUI/Art/LFG/LFG_icon_tank.dds",
}

-- Progression icons -- the actual in-game art the user asked for.
Icons.XP  = "EsoUI/Art/Icons/Icon_Experience.dds"
Icons.CP  = "EsoUI/Art/Champion/champion_icon_32.dds"

-- The green Alliance-Points currency icon, straight from the engine.
function Icons.ap()
    local C = BGMeter.zenimax.constants
    return safe(BGMeter.zenimax.api.get_currency_icon, C.CURT_ALLIANCE_POINTS)
end

-- A medal's icon texture, from its id.
function Icons.medal(medalId)
    if not medalId or type(GetMedalInfo) ~= "function" then return nil end
    local ok, _name, icon = pcall(GetMedalInfo, medalId)
    if not ok then return nil end
    return icon
end

BGMeter.Icons = Icons
