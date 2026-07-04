-- bgmeter :: core/constants.lua
-- Domain constants: identity, version (kept in lockstep with the manifest at
-- release time), palette, layout, and the score-type tables that drive the
-- battle table columns.

BGMeter = BGMeter or {}
local BGMeter = BGMeter

local K = {}

K.ADDON_NAME = "bgmeter"
K.VERSION    = "0.1.0"          -- lockstep: manifest ## Version + ## AddOnVersion
K.SAVED_VARS = "BGMeterSavedVars"
K.SLASH      = "/bgmeter"

-- ── Palette ───────────────────────────────────────────────────────────────
-- Non-intrusive, dark, with a battle (warm) / haul (gold) split.
K.COLOR = {
    bg          = { 0.04, 0.04, 0.05, 0.92 },
    panel       = { 0.08, 0.08, 0.10, 0.95 },
    text        = { 0.90, 0.90, 0.92, 1.0 },
    text_dim    = { 0.55, 0.55, 0.60, 1.0 },
    accent      = { 0.89, 0.26, 0.20, 1.0 },  -- battle / damage (vermilion red)
    heal        = { 0.30, 0.78, 0.45, 1.0 },  -- healing (verdant green)
    gold        = { 0.95, 0.80, 0.35, 1.0 },  -- the haul / rewards
    veterancy   = { 0.55, 0.50, 0.95, 1.0 },  -- veterancy track (royal violet)
    you         = { 1.00, 0.90, 0.55, 1.0 },  -- local-player row highlight
    medal       = { 0.95, 0.80, 0.35, 1.0 },
    -- BG team tints (the 3-team arena system)
    team = {
        fire   = { 0.85, 0.35, 0.25, 1.0 },
        pit    = { 0.55, 0.45, 0.80, 1.0 },
        storm  = { 0.35, 0.65, 0.85, 1.0 },
    },
}

-- ── Layout ────────────────────────────────────────────────────────────────
-- The window is resizable; ui/window.lua reflows the battle table from the
-- current width. These are the defaults and the resize constraints.
K.LAYOUT = {
    window_w   = 760,
    window_h   = 600,
    min_w      = 660,   -- wide enough to keep the table columns spaced out
    min_h      = 560,   -- tall enough that the full haul panel always shows
    max_w      = 1240,
    max_h      = 980,
    row_h      = 28,
    margin     = 14,    -- outer padding inside the border
    header_h   = 66,    -- top chrome band (title / banner / buttons)
    footer_h   = 28,    -- bottom detail strip band
    gap        = 12,    -- gap between the battle table and the haul panel
    haul_w     = 218,   -- right-hand "haul" panel width
    resize_h   = 8,     -- edge grab size for resizing
}

-- ── Battle table columns (the scoreboard score types we surface) ──────────
-- Order here is render order. `bar` flags the column that drives the meter bar.
K.COLUMNS = {
    { key = "damage",  label = "DMG",  bar = true,  color = "accent" },
    { key = "healing", label = "HEAL", bar = false, color = "heal" },
    { key = "kills",   label = "K",    bar = false, color = "text" },
    { key = "deaths",  label = "D",    bar = false, color = "text_dim" },
    { key = "assists", label = "A",    bar = false, color = "text" },
    { key = "score",   label = "PTS",  bar = false, color = "gold" },
}

BGMeter.Constants = K
