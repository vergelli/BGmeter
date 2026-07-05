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
    team = {
        fire   = { 0.92, 0.48, 0.22, 1.0 },
        pit    = { 0.45, 0.82, 0.35, 1.0 },
        storm  = { 0.62, 0.46, 0.92, 1.0 },
    },
}

K.TEAM_ART = {
    fire  = "orange",
    pit   = "green",
    storm = "purple",
}

-- ── Layout ────────────────────────────────────────────────────────────────
-- The window is resizable; ui/window.lua reflows the battle table from the
-- current width. These are the defaults and the resize constraints.
K.LAYOUT = {
    window_w   = 760,
    window_h   = 620,
    min_w      = 700,
    min_h      = 600,
    max_w      = 1240,
    max_h      = 980,
    row_h      = 28,
    margin     = 16,
    header_h   = 68,
    footer_h   = 32,
    gap        = 16,
    haul_w     = 220,
    resize_h   = 8,
    chart_h    = 96,
    pad        = 16,
}

BGMeter.Constants = K
