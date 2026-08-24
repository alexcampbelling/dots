-- Window rules (hl.window_rule)

-- Ensure some quickly used windows start floating
-- pavucontrol: Wayland app_id is org.pulseaudio.pavucontrol (not "pavucontrol")
hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol)$" }, float = true, size = { "monitor_w*0.5", "monitor_h*0.7" } })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, size = { "monitor_w*0.5", "monitor_h*0.5" } })

-- RuneLite: float only the launcher (match:title uses initial title for static rules like float).
-- The game client has a different title/class — avoid rules that match all java/xwayland windows.
hl.window_rule({ match = { title = "^RuneLite Launcher$" }, float = true })
hl.window_rule({ match = { title = "^RuneLite Launcher$" }, center = true })
hl.window_rule({ match = { title = "^RuneLite Launcher$" }, size = { 600, 400 } })

-- Vesktop: float secondary windows; keep the main client tiled.
-- Hyprland uses RE2 — no (?!…) lookahead. Use negative: so the rule applies when title does NOT match.
-- Adjust ^Discord$ if your main window’s initial title differs (check: hyprctl clients).
hl.window_rule({ match = { class = "^vesktop$", title = "negative:^Discord$" }, float = true, center = true })

-- Connection and game-launcher utility windows are better as centered dialogs.
hl.window_rule({ match = { class = "^nm-connection-editor$" }, float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.5" } })
hl.window_rule({ match = { class = "^(Bolt|bolt-launcher)$" }, float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.7" } })

-- Default windowrules (moved from hyprland.conf)

-- Ignore maximize requests from all apps
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = { 20, "monitor_h-120" },
    float = true,
})
