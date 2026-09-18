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
local CREDITS = { "unit220", "TattoozNbooZ" }
local BAR_H = 7
local LINE_H = 30

local function storage_line(parent, y, w)
    local line = {}
    line.name = P.label(parent, S.FONT.small, K.COLOR.text_dim)
    line.name:SetAnchor(TOPLEFT, parent, TOPLEFT, 4, y)
    line.name:SetDimensions(70, 14)
    line.value = P.label(parent, S.FONT.small, K.COLOR.text)
    line.value:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -4, y)
    line.value:SetDimensions(w - 78, 14)
    line.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    U.clamp_line(line.value)
    line.bar = U.inset_bar(parent)
    line.bar.container:SetAnchor(TOPLEFT, parent, TOPLEFT, 4, y + 17)
    line.bar.container:SetDimensions(w - 8, BAR_H + 2)
    line.barW = w - 8
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
    row_h = 40,
    list_heading = "ADDON",
    panel_h = 18 + 2 * LINE_H,
    cache_key = function(self)
        local Storage = BGMeter.Storage
        local r = Storage and Storage.report()
        return tostring(BGMeter.History.count()) .. "|" .. tostring(BGMeter.History.pinned_count()) .. "|"
            .. tostring(r and r.faces.count or 0) .. "|" .. tostring(BGMeter.Prefs.get("max_history"))
    end,
    fetch = function(self)
        local Faces, History = BGMeter.Faces, BGMeter.History
        local cap = BGMeter.Prefs.get("max_history") or 50
        local pinned = History.pinned_count()
        return {
            { k = "VERSION", v = K.VERSION, tip = "BGmeter " .. K.VERSION },
            { k = "AUTHOR", v = AUTHOR, tip = "@vergelli" },
            { k = "CREDITS", v = table.concat(CREDITS, ", "), tip = table.concat(CREDITS, "\n") },
            { k = "MATCHES KEPT", v = string.format("%d / %d%s", History.count() - pinned, cap,
                pinned > 0 and string.format("  ·  %d saved", pinned) or ""),
              tip = string.format("The cap is under Settings, Matches kept.\nThe ten most recent keep their charts; older ones keep the scoreboard.\nSaved matches (up to %d) sit outside the cap and keep whatever they had.", History.PIN_CAP) },
            { k = "FACES KNOWN", v = string.format("%d / %d", Faces.count(), Faces.CAP or 1500),
              tip = "The oldest names make room when the ledger is full." },
        }
    end,
    row_make = function(self, r)
        r.base:SetHidden(true)
        r.highlight:ClearAnchors()
        r.highlight:SetAnchor(TOPLEFT, r.container, TOPLEFT, 0, 2)
        r.highlight:SetAnchor(BOTTOMRIGHT, r.container, BOTTOMRIGHT, 0, -2)
        r.name:ClearAnchors()
        r.name:SetAnchor(TOPLEFT, r.container, TOPLEFT, 4, 5)
        r.name:SetAnchor(TOPRIGHT, r.container, TOPRIGHT, -4, 5)
        r.name:SetHeight(13)
        if r.name.SetFont then r.name:SetFont(S.FONT.small) end
        S.color(r.name, K.COLOR.text_dim)
        r.count:ClearAnchors()
        r.count:SetAnchor(BOTTOMLEFT, r.container, BOTTOMLEFT, 4, -5)
        r.count:SetAnchor(BOTTOMRIGHT, r.container, BOTTOMRIGHT, -4, -5)
        r.count:SetHeight(17)
        r.count:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        U.clamp_line(r.count)
        r.rule = P.rect(r.container, { 1, 1, 1, 0.08 })
        r.rule:SetAnchor(BOTTOMLEFT, r.container, BOTTOMLEFT, 0, 0)
        r.rule:SetAnchor(BOTTOMRIGHT, r.container, BOTTOMRIGHT, 0, 0)
        r.rule:SetHeight(1)
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
        p.rule = P.rect(panel, { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.22 })
        p.rule:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 17)
        p.rule:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 17)
        p.rule:SetHeight(1)
        p.matches = storage_line(panel, 22, w)
        p.faces = storage_line(panel, 22 + LINE_H, w)
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
            "Bytes in your saved variables.\nAvailable is the store at the addon's own caps, not a game limit.\nwhole store %s",
            F.bytes(r.total))
    end,
    foot = function(self, list)
        local r = BGMeter.Storage and BGMeter.Storage.report()
        if not r then return "" end
        return string.format("%s in saved variables", F.bytes(r.total))
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
