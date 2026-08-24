-- Autostart — processes launched once Hyprland starts.
-- hl.exec_cmd() spawns asynchronously (sh -c), so no `& disown` needed.

hl.on("hyprland.start", function()
    -- Polkit agent for GUI auth (IDE saves, pkexec, etc.)
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Wallpaper: hyprpaper + Waypaper restore
    hl.exec_cmd("$HOME/.config/hypr/scripts/wallpaper-autostart.sh")

    -- Vicinae launcher daemon (Super+Space toggles via $menu in keybinds.lua)
    hl.exec_cmd("vicinae server")

    -- Waybar
    hl.exec_cmd("waybar")
    hl.exec_cmd("$HOME/.config/hypr/scripts/waybar-restart-on-resume.sh")

    -- Hypridle — auto-lock + suspend
    hl.exec_cmd("hypridle")
end)
