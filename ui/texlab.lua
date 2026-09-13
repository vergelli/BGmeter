BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local M = {}

local SLOTS = {
    tab = {
        label = "bookmark icon",
        list = {
            "EsoUI/Art/Contacts/social_note_up.dds",
            "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_up.dds",
            "EsoUI/Art/Journal/journal_tabIcon_leaderboard_up.dds",
            "EsoUI/Art/Journal/journal_tabIcon_achievements_up.dds",
            "EsoUI/Art/Journal/journal_rumors_tabIcon_up.dds",
            "EsoUI/Art/Journal/journal_quests_tabIcon_up.dds",
            "EsoUI/Art/Journal/leaderboard_indexIcon_ava_up.dds",
            "EsoUI/Art/Contacts/tabIcon_friends_up.dds",
            "EsoUI/Art/Guild/tabIcon_roster_up.dds",
            "EsoUI/Art/Guild/tabIcon_history_up.dds",
            "EsoUI/Art/Guild/tabIcon_heraldry_up.dds",
            "EsoUI/Art/Crafting/smithing_tabIcon_research_up.dds",
            "EsoUI/Art/Crafting/formulae_tabIcon_up.dds",
            "EsoUI/Art/Crafting/scribing_tabIcon_recent_up.dds",
            "EsoUI/Art/Collections/collections_categoryIcon_unlocked_up.dds",
            "EsoUI/Art/Help/help_tabIcon_overview_up.dds",
        },
    },
    title = {
        label = "drawer title icon",
        list = {
            "EsoUI/Art/Contacts/social_note_up.dds",
            "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_up.dds",
            "EsoUI/Art/Contacts/tabIcon_friends_up.dds",
            "EsoUI/Art/Guild/tabIcon_roster_up.dds",
            "EsoUI/Art/Guild/tabIcon_history_up.dds",
            "EsoUI/Art/Journal/leaderboard_indexIcon_ava_up.dds",
            "EsoUI/Art/Journal/journal_rumors_tabIcon_up.dds",
            "EsoUI/Art/Crafting/formulae_tabIcon_up.dds",
        },
    },
    bg = {
        label = "drawer background",
        list = {
            "esoui/art/loadingscreens/loadscreen_battleground_ularra_01.dds",
            "esoui/art/lorelibrary/lorelibrary_paperbook.dds",
            "esoui/art/lorelibrary/lorelibrary_skinbook.dds",
            "esoui/art/lorelibrary/lorelibrary_dwemerbook.dds",
            "esoui/art/lorelibrary/lorelibrary_rubbingbook.dds",
            "esoui/art/lorelibrary/lorelibrary_paperbookbloody.dds",
            "esoui/art/lorelibrary/lorelibrary_letter.dds",
            "esoui/art/lorelibrary/lorelibrary_note.dds",
            "esoui/art/lorelibrary/lorelibrary_scroll.dds",
            "esoui/art/lorelibrary/lorelibrary_dwemerpage.dds",
            "esoui/art/lorelibrary/lorelibrary_stonetablet.dds",
            "esoui/art/loadingscreens/loadscreen_battleground_deepingdrome_01.dds",
            "esoui/art/loadingscreens/loadscreen_battleground_ald_carac_01.dds",
            "esoui/art/loadingscreens/loadscreen_battleground_foyadaquarry_01.dds",
            "esoui/art/loadingscreens/loadscreen_battleground_arcaneuniversity_01.dds",
            "esoui/art/loadingscreens/loadscreen_battleground_eld_angavar_01.dds",
        },
    },
    frame = {
        label = "drawer and bookmark frame",
        list = {
            { "EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 8 },
            { "EsoUI/Art/Miscellaneous/borderedInset_edgeFile.dds", 128, 16, 8 },
            { "EsoUI/Art/Miscellaneous/borderedInsetTransparent_white_edgeFile.dds", 128, 16, 8 },
            { "EsoUI/Art/Miscellaneous/dark_edgeFrame_8_thin.dds", 64, 8, 4 },
            { "EsoUI/Art/ChatWindow/chat_BG_edge.dds", 256, 256, 32 },
            { "EsoUI/Art/Miscellaneous/centerscreen_floating_edge.dds", 256, 256, 32 },
            { "EsoUI/Art/ChatWindow/textEntry_edge.dds", 64, 8, 4 },
            { "EsoUI/Art/Market/market_highlightEdge16.dds", 128, 16, 8 },
            { "EsoUI/Art/Miscellaneous/Gamepad/gp_emptyFrame_gold_edge.dds", 128, 16, 8 },
            { "EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds", 128, 16, 8 },
            { "EsoUI/Art/Miscellaneous/Gamepad/gp_toolTip_edge_semiTrans_16.dds", 128, 16, 8 },
        },
    },
    alpha = {
        label = "drawer background alpha",
        list = { 0.30, 0.18, 0.45, 0.60, 0.80, 1.00 },
    },
}

local ORDER = { "tab", "title", "bg", "frame", "alpha" }

local function store()
    local data = BGMeter.zenimax.savedvars.get()
    if not data then return nil end
    data.prefs = data.prefs or {}
    data.prefs.texlab = data.prefs.texlab or {}
    return data.prefs.texlab
end

local function index_of(slot)
    local data = BGMeter.zenimax.savedvars.get()
    local st = data and data.prefs and data.prefs.texlab or nil
    local i = st and st[slot] or 1
    local n = #SLOTS[slot].list
    if i < 1 or i > n then i = 1 end
    return i
end

local function entry(slot, i)
    return SLOTS[slot].list[i]
end

local function name_of(v)
    if type(v) == "table" then return v[1] end
    return tostring(v)
end

function M.current(slot)
    return entry(slot, index_of(slot))
end

function M.apply_all()
    local F = BGMeter.UI.faces
    if not F or not F.set_texture then return end
    for _, slot in ipairs(ORDER) do
        F.set_texture(slot, M.current(slot))
    end
end

function M.set(slot, i)
    local spec = SLOTS[slot]
    if not spec then return nil end
    local n = #spec.list
    if i < 1 then i = n end
    if i > n then i = 1 end
    local st = store()
    if st then st[slot] = i end
    local F = BGMeter.UI.faces
    if F and F.set_texture then F.set_texture(slot, entry(slot, i)) end
    return i
end

function M.step(slot, dir)
    return M.set(slot, index_of(slot) + dir)
end

function M.reset()
    local data = BGMeter.zenimax.savedvars.get()
    if data and data.prefs then data.prefs.texlab = nil end
    M.apply_all()
end

function M.report()
    local lines = { "texture lab  ·  /bgmeter tex <slot> next|prev|<n>|reset" }
    for _, slot in ipairs(ORDER) do
        local spec = SLOTS[slot]
        local i = index_of(slot)
        lines[#lines + 1] = string.format("%-6s %2d/%d  %s  (%s)", slot, i, #spec.list, name_of(entry(slot, i)), spec.label)
    end
    return table.concat(lines, "\n")
end

function M.list(slot)
    local spec = SLOTS[slot]
    if not spec then return "unknown slot " .. tostring(slot) end
    local cur = index_of(slot)
    local lines = { string.format("%s  ·  %s", slot, spec.label) }
    for i, v in ipairs(spec.list) do
        lines[#lines + 1] = string.format("%s%2d  %s", (i == cur) and ">" or " ", i, name_of(v))
    end
    return table.concat(lines, "\n")
end

function M.command(args)
    local slot, what = args:match("^(%a+)%s*(.*)$")
    if not slot or slot == "" then return M.report() end
    if slot == "reset" then M.reset() return M.report() end
    if not SLOTS[slot] then return "slots: " .. table.concat(ORDER, ", ") end
    if what == "" or what == "list" then return M.list(slot) end
    local i
    if what == "next" then i = M.step(slot, 1)
    elseif what == "prev" then i = M.step(slot, -1)
    elseif what == "reset" then i = M.set(slot, 1)
    else
        local n = tonumber(what)
        if not n then return "usage: /bgmeter tex " .. slot .. " next|prev|<n>|reset" end
        i = M.set(slot, math.floor(n))
    end
    return string.format("%s -> %d/%d  %s", slot, i, #SLOTS[slot].list, name_of(entry(slot, i)))
end

function M.slots() return SLOTS, ORDER end

BGMeter.UI.texlab = M
