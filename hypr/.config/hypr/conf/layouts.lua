-- Layout options (dwindle, master, misc)

local misc = {
    force_default_wallpaper = -1,
    disable_hyprland_logo = false,
}

-- Desktop-only companion to the Firefox XWayland fix in environment.lua:
-- focus X11/XWayland apps when they request activation. Without this, a link
-- opened from another app briefly focuses Firefox and then focus bounces back,
-- so the link looks like it never opened.
if require("conf/hosts") == "pcarch" then
    misc.focus_on_activate = true
end

hl.config({
    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = misc,
})
