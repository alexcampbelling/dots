-- ═══════════════════════════════════════════════════════════════════════════
-- Hyprland Lua config — converted from the deprecated hyprlang hyprland.conf.
--
-- Since Hyprland 0.55, hyprlang is deprecated in favor of Lua. When this file
-- exists, Hyprland loads it and ignores hyprland.conf and every conf/*.conf
-- entirely. Each conf/*.conf has been rewritten as conf/*.lua and is required()
-- here in the same order it was previously source'd.
--
-- require() paths are relative to this file (~/.config/hypr/).
-- ═══════════════════════════════════════════════════════════════════════════

require("conf/autostart")
require("conf/keybinds")
require("conf/windows")
require("conf/environment")

-- Monitor layout is per-machine (see conf/monitors.lua, keyed off conf/hosts.lua).
require("conf/monitors")

require("conf/layouts")
require("conf/input")
require("conf/windowrules")
require("conf/animations")
