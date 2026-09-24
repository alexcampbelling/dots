-- Windows / look-and-feel (decoration, general, layer rules)

hl.config({
    decoration = {
        rounding = 10,
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = true,
            size = 3,
            passes = 1,

            vibrancy = 0.1696,
        },
    },

    general = {
        gaps_in = 2,
        gaps_out = 1,
        border_size = 1,
        col = {
            active_border = "rgba(ccccccff)",
        },
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },
})

-- Vicinae layer-shell launcher (see https://docs.vicinae.com/quickstart/hyprland)
hl.layer_rule({
    name = "vicinae-blur",
    blur = true,
    ignore_alpha = 0,
    match = { namespace = "vicinae" },
})

hl.layer_rule({
    name = "vicinae-no-animation",
    no_anim = true,
    match = { namespace = "vicinae" },
})
