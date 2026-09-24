-- Keybindings
--
-- todo:alex — verify these still feel right after the Lua conversion. The
-- trickiest mappings (old hyprlang → Lua dispatcher) are flagged inline below;
-- spot-check them once live:
--   * Super+F fullscreen   (fullscreen, 0        → window.fullscreen({ mode = "fullscreen" }))
--   * Super+Shift+arrows   resize windows        (resizeactive, dx dy  → window.resize({ x, y, relative = true }))
--   * Super+Alt+arrows     swap windows          (swapwindow, dir      → window.swap({ direction = dir }))
--   * Ctrl+Alt+Super+Shift+comma/period          (movecurrentworkspacetomonitor → workspace.move({ monitor = dir }))
--   * Super+S / Super+R    special workspaces    (togglespecialworkspace → workspace.toggle_special(...))
--   * Super+LMB / Super+RMB move/resize windows  (bindm → { mouse = true })
--   * volume/brightness keys hold-to-repeat + work while locked
--   * Super+Ctrl+1..9      moveTo.sh still moves all windows

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "thunar"
local browser     = "firefox"
-- Vicinae app launcher (replaces rofi drun); requires hl.exec_cmd("vicinae server") in autostart.lua
local menu        = "vicinae toggle"
local SCRIPTS     = "$HOME/.config/hypr/scripts"

-- Applications
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd(menu))

-- Windows
-- Dwindle layout split controls
hl.bind(mainMod .. " + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" })) -- todo:alex check — was "fullscreen, 0"
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
-- todo:alex check — was "resizeactive, dx dy"
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 100,  y = 0,    relative = true }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -100, y = 0,    relative = true }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0,    y = 100,  relative = true }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0,    y = -100, relative = true }))
-- todo:alex check — was "swapwindow, dir"
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "down" }))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + K", hl.dsp.layout("swapsplit"))

-- Mouse binds
-- todo:alex check — was "bindm" movewindow/resizewindow
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Actions
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("hyprctl reload"))
-- todo:alex check — was "movecurrentworkspacetomonitor, l/r"
hl.bind("CTRL + ALT + " .. mainMod .. " + SHIFT + comma",  hl.dsp.workspace.move({ monitor = "left" }))
hl.bind("CTRL + ALT + " .. mainMod .. " + SHIFT + period", hl.dsp.workspace.move({ monitor = "right" }))

-- Special workspaces: Super+Letter toggles; Super+Shift+Letter sends window there
-- todo:alex check — was "togglespecialworkspace" (no arg = default "special")
hl.bind(mainMod .. " + S",        hl.dsp.workspace.toggle_special(""))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + R",        hl.dsp.workspace.toggle_special("osrs"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.window.move({ workspace = "special:osrs" }))

-- Workspaces (1-9)
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,          hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,  hl.dsp.window.move({ workspace = i }))

    -- Move all windows from the active workspace to workspace i.
    hl.bind(mainMod .. " + CTRL + " .. i,   hl.dsp.exec_cmd("bash " .. SCRIPTS .. "/moveTo.sh " .. i))
end

hl.bind(mainMod .. " + Tab",        hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))

-- Whisper speech-to-text: Super+M starts and stops recording.
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(SCRIPTS .. "/whisper-toggle.sh"))

-- Screenshot menu
hl.bind("Print", hl.dsp.exec_cmd(SCRIPTS .. "/screenshot-menu.sh"))

-- Power menu (lock · sleep · reboot · shutdown)
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(SCRIPTS .. "/power-menu.sh"))

-- Brightness Control (using brightnessctl)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 10%+"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"))

-- Volume Control (using wireplumber)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
