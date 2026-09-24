-- monitors.lua — per-machine monitor layout, keyed off the hostname from hosts.lua.
-- To add a machine: copy an existing branch, swap the hostname + monitor lines.
-- Laptops keep a fallback `output = ""` rule so any plugged-in external auto-docks.

local host = require("conf/hosts")

if host == "laparch" then
    -- ── Laptop: internal eDP-1, externals dock on the right ─────────────────
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0",    scale = 1 })
    hl.monitor({ output = "",      mode = "preferred", position = "auto-right", scale = 1 })

elseif host == "pcarch" then
    -- ── Desktop: DP-1 (left) + HDMI-A-1 (right) ────────────────────────────
    hl.monitor({ output = "DP-1",     mode = "1920x1080@60", position = "0x0",    scale = 1 })
    hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })

    -- Pin workspaces to monitors: 1 → left, 2 → right
    hl.workspace_rule({ workspace = "1", monitor = "DP-1" })
    hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })

else
    -- ── Unknown machine: let Hyprland pick everything ───────────────────────
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
end
