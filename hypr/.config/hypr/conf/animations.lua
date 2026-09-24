-- Animations — single source of truth (required at end of hyprland.lua)
--
-- todo:alex — this is the Lua rewrite of animations.conf. To prove Hyprland is
-- reading Lua (and ignoring the old .conf), try editing the `speed` on the
-- `global` animation below (e.g. 10 -> 2.5 makes every animation ~4x slower),
-- save the file, and watch it apply live. Revert when you're satisfied.

hl.config({
    animations = {
        enabled = true,
    },
})

-- Bezier curves:  NAME | P0(x,y) | P1(x,y)
hl.curve("wind",           { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } }) -- decelerate, settle — no overshoot
hl.curve("winIn",          { type = "bezier", points = { {0.1, 1.1}, {0.1, 1.1} } })  -- aggressive overshoot (open)
hl.curve("winOut",         { type = "bezier", points = { {0.3, -0.3}, {0, 1} } })     -- back-swing (close)
hl.curve("liner",          { type = "bezier", points = { {1, 1}, {1, 1} } })          -- perfectly linear (no easing)

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })    -- fast start, gentle settle
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } }) -- smooth in + out
hl.curve("linear",         { type = "bezier", points = { {0, 0}, {1, 1} } })          -- uniform speed
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })   -- near-linear, soft tail
hl.curve("quick",          { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })     -- instant kick, fast settle

-- Global — scales speed of all other animations (lower = slower)
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })

-- Border — colour transition + chasing-light rotation
hl.animation({ leaf = "border",      enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner", style = "once" })

-- Windows — open(appear) / close(disappear) / move(reposition or resize)
hl.animation({ leaf = "windows",     enabled = true, speed = 6, bezier = "wind",  style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5, bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind",  style = "slide" })

-- Fade — crossfade (fadeIn/Out = slow reveal/vanish; fade = generic)
hl.animation({ leaf = "fadeIn",  enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",    enabled = true, speed = 3.03, bezier = "quick" })

-- Layers — overlay panels (rofi, wofi, launcher, etc.)
hl.animation({ leaf = "layers",    enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",  enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })

-- Fade-layers — floating / modal sub-layers
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })

-- Workspaces — switching desktops (slide = pan L/R into view)
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2, bezier = "wind", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 2, bezier = "wind", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2, bezier = "wind", style = "slide" })

-- Special workspaces — scratchpad toggle (very quick fade)
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.25, bezier = "almostLinear", style = "fade" })

-- Zoom-factor — MOD+scroll zoom
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
