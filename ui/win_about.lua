BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local K = BGMeter.Constants
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Drawer = BGMeter.UI.Drawer
local TX = U.TX
local set_text = U.set_text
local hexc = F.hexc

local AUTHOR = "Federico Vergelli"
local GITHUB = "github.com/vergelli/BGmeter"
local BAR_H = 7
local LINE_H = 30

local function storage_line(parent, y, w)
    local line = {}
    line.name = P.label(parent, S.FONT.small, K.COLOR.text_dim)
    line.name:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
    line.name:SetDimensions(70, 14)
    line.value = P.label(parent, S.FONT.small, K.COLOR.text)
    line.value:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, y)
    line.value:SetDimensions(w - 70, 14)
    line.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    U.clamp_line(line.value)
    line.bar = U.inset_bar(parent)
    line.bar.container:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y + 17)
    line.bar.container:SetDimensions(w, BAR_H + 2)
    line.barW = w
    return line
end

local function fill_line(line, label, used, cap, color)
    set_text(line.name, label)
    if cap and cap > 0 then
        set_text(line.value, string.format("%s / %s", F.bytes(used), F.bytes(cap)))
        U.inset_bar_set(line.bar, used / cap, color, line.barW)
    else
        set_text(line.value, F.bytes(used))
        U.inset_bar_set(line.bar, 0, color, line.barW)
    end
end

local D = Drawer.new({
    key = "about",
    index = 1,
    bottom = true,
    title = "About",
    icon = TX.about.n,
    icon_down = TX.about.p,
    icon_over = TX.about.o,
    drag_name = "BGMeterAboutDrag",
    panel_h = 14 + 2 * LINE_H,
    cache_key = function(self)
        local Storage = BGMeter.Storage
        local r = Storage and Storage.report()
        return tostring(BGMeter.History.count()) .. "|" .. tostring(r and r.faces.count or 0) .. "|" .. tostring(BGMeter.Prefs.get("max_history"))
    end,
    fetch = function(self)
        local Faces = BGMeter.Faces
        local cap = BGMeter.Prefs.get("max_history") or 50
        return {
            { k = "Version", v = K.VERSION, tip = "BGmeter " .. K.VERSION .. "\nPost-battle analytics for Battlegrounds" },
            { k = "Author", v = AUTHOR, tip = "Written and maintained by " .. AUTHOR .. " (@vergelli)" },
            { k = "Made with", v = "AI assistance", tip = "Built with AI assistance (Claude).\nReviewed, tested in-game and maintained by the author." },
            { k = "Thanks", v = "unit220", tip = "Familiar faces was unit220's idea,\nand the first bug reports came from them." },
            { k = "Matches kept", v = string.format("%d / %d", BGMeter.History.count(), cap),
              tip = "Change the cap under Settings, Matches kept.\nThe ten most recent matches keep their full timeline;\nolder ones keep the scoreboard only." },
            { k = "Faces known", v = string.format("%d / %d", Faces.count(), Faces.CAP or 1500),
              tip = "Players you have met. The oldest names make room\nwhen the ledger reaches its cap." },
            { k = "Commands", v = "/bgmeter", tip = "/bgmeter opens this Registry\n/bgmeter vet dumps the raw veterancy values" },
            { k = "Feedback", v = "ESOUI or GitHub", tip = "Bugs and ideas are welcome in the ESOUI comments\nor on " .. GITHUB },
            { k = "Disclaimer", v = "not affiliated", tip = "This add-on is not created by, affiliated with,\nor sponsored by ZeniMax Media Inc." },
        }
    end,
    row_make = function(self, r)
        r.name:ClearAnchors()
        r.name:SetAnchor(LEFT, r.container, LEFT, 10, 0)
        r.name:SetAnchor(RIGHT, r.container, RIGHT, -112, 0)
        S.color(r.name, K.COLOR.text_dim)
        r.count:SetDimensions(106, Drawer.row_h())
        U.clamp_line(r.count)
    end,
    row_fill = function(self, r, e)
        set_text(r.name, e.k)
        set_text(r.count, string.format("|c%s%s|r", hexc(K.COLOR.text), e.v))
    end,
    describe = function(self, e) return e.tip end,
    panel_build = function(self, panel, w)
        local p = {}
        p.heading = P.label(panel, S.FONT.small, K.COLOR.gold)
        p.heading:SetText("STORAGE")
        p.heading:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
        p.heading:SetDimensions(w, 14)
        p.matches = storage_line(panel, 14, w)
        p.faces = storage_line(panel, 14 + LINE_H, w)
        panel:SetHandler("OnMouseEnter", function()
            if p.tip and U.card_show then U.card_show(panel, LEFT, p.tip) end
        end)
        panel:SetHandler("OnMouseExit", function()
            if U.card_hide then U.card_hide() end
        end)
        self.storage = p
    end,
    panel_refresh = function(self)
        local p = self.storage
        local r = BGMeter.Storage and BGMeter.Storage.report()
        if not (p and r) then return end
        fill_line(p.matches, "matches", r.matches.used, r.matches.cap, K.COLOR.gold)
        fill_line(p.faces, "faces", r.faces.used, r.faces.cap, K.COLOR.veterancy)
        p.tip = string.format(
            "Bytes this addon keeps in your saved variables.\n"
            .. "Used is what the store holds today; available is not a game limit,\n"
            .. "it is the size the store would reach at the cap the addon sets itself\n"
            .. "(matches: Settings, Matches kept; faces: %d names).\n"
            .. "matches %s  ·  faces %s  ·  ledger %s  ·  whole store %s",
            r.faces.capCount, F.bytes(r.matches.used), F.bytes(r.faces.used), F.bytes(r.ledger.used), F.bytes(r.total))
    end,
    foot = function(self, list)
        local r = BGMeter.Storage and BGMeter.Storage.report()
        if not r then return "" end
        return string.format("%s in saved variables  ·  hover a line for more", F.bytes(r.total))
    end,
})

local M = {}
function M.invalidate() D:invalidate() end
function M.refresh() D:refresh() end
function M.is_open() return D:is_open() end
function M.toggle() D:toggle() end
function M.on_host_resized() D:on_host_resized() end
function M.on_menu_shown() D:on_menu_shown() end
function M.init(pw) D:init(pw) end
function M.controls() return D:controls() end
function M.storage() return D.storage end
M.drawer = D

BGMeter.UI.about = M
