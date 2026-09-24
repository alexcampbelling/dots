-- Environment variables (hl.env) — set before the display server initializes

-- Core Wayland
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Toolkit Backends
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- App fixes (Firefox and Electron applications)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("BROWSER", "firefox")

-- Desktop-only: force Firefox to XWayland. Its native Wayland backend
-- double-scrolls with high-res wheels (G502 X + kernel 6.19+) — only an issue
-- on the desktop's mouse. The laptop keeps native Wayland Firefox.
if require("conf/hosts") == "pcarch" then
    hl.env("MOZ_ENABLE_WAYLAND", "0")
end

-- UI Consistency
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
