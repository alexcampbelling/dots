#!/usr/bin/env bash
# Screenshot menu — 3x2 grid launched from Hyprland on Print key.
# Row 1 (copy): Full Screen · Active Window · Selected Area
# Row 2 (save): Full Screen  · Active Window  · Selected Area

set -u

readonly SCREENSHOT_DIR="${HOME}/Pictures/Screenshots"
readonly ROFI_MENU_THEME="${HOME}/.config/rofi/screenshot-menu.rasi"

pick="$(printf "%s\n" \
  "📸 Copy Full Screen" \
  "💾 Save Full Screen" \
  "📸 Copy Active Window" \
  "💾 Save Active Window" \
  "📸 Copy Selected Area" \
  "💾 Save Selected Area" \
  | rofi -dmenu -i -no-custom -p "" -config "${ROFI_MENU_THEME}")" || exit 0

[[ -z "${pick}" ]] && exit 0

case "${pick}" in
  "📸 Copy Full Screen")
    grim - | wl-copy
    ;;
  "📸 Copy Active Window")
    grim -g "$(hyprctl activewindow -j | jq -j '.at[0], ",", .at[1], " ", .size[0], "x", .size[1]')" - | wl-copy
    ;;
  "📸 Copy Selected Area")
    grim -g "$(slurp)" - | wl-copy
    ;;
  "💾 Save Full Screen")
    mkdir -p "${SCREENSHOT_DIR}"
    grim "${SCREENSHOT_DIR}/$(date +%Y-%m-%d_%H-%M-%S).png"
    ;;
  "💾 Save Active Window")
    mkdir -p "${SCREENSHOT_DIR}"
    grim -g "$(hyprctl activewindow -j | jq -j '.at[0], ",", .at[1], " ", .size[0], "x", .size[1]')" "${SCREENSHOT_DIR}/$(date +%Y-%m-%d_%H-%M-%S).png"
    ;;
  "💾 Save Selected Area")
    mkdir -p "${SCREENSHOT_DIR}"
    grim -g "$(slurp)" "${SCREENSHOT_DIR}/$(date +%Y-%m-%d_%H-%M-%S).png"
    ;;
  *)
    exit 0
    ;;
esac
