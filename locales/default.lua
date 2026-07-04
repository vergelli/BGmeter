-- bgmeter :: locales/default.lua
-- Fallback strings (English). Language-specific overrides live in
-- locales/<lang>.lua and are loaded after this via the manifest's $(language).

BGMeter = BGMeter or {}

-- Keybind label (must be SI_BINDING_NAME_<ACTIONNAME> to match bindings.xml).
ZO_CreateStringId("SI_BINDING_NAME_BGMETER_TOGGLE", "Toggle bgmeter window")
