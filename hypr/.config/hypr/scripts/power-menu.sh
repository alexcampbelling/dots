#!/usr/bin/env bash
# Power menu — rofi launcher, actions inspired by desktop wlogout script.
#   Lock  ·  Sleep
#   Reboot · Shutdown
#
# Lock / Sleep: direct hyprlock / systemctl — hypridle handles the rest.
# Reboot / Shutdown: gracefully SIGTERM all clients first.

set -euo pipefail

readonly ROFI_THEME="${HOME}/.config/rofi/power-menu.rasi"

# ── Gracefully terminate all Hyprland clients ──────────────────────────

terminate_clients() {
    local timeout=5
    local pids
    pids=$(hyprctl clients -j | jq -r '.[] | .pid' 2>/dev/null) || return 0

    for pid in $pids; do
        echo "Sending SIGTERM to PID $pid"
        kill -15 "$pid" 2>/dev/null || true
    done

    local start_time
    start_time=$(date +%s)

    for pid in $pids; do
        while kill -0 "$pid" 2>/dev/null; do
            local elapsed
            elapsed=$(($(date +%s) - start_time))
            if (( elapsed >= timeout )); then
                echo "Timeout reached waiting for PID $pid"
                break
            fi
            sleep 1
        done
    done
}

# ── Rofi menu ──────────────────────────────────────────────────────────

pick="$(printf "%s\n" \
    "Lock" \
    "Sleep" \
    "Reboot" \
    "Shutdown" \
    | rofi -dmenu -i -no-custom -p "" -config "${ROFI_THEME}")" || exit 0

[[ -z "${pick}" ]] && exit 0

# ── Dispatch ───────────────────────────────────────────────────────────

case "${pick}" in
    "Lock")
        hyprlock
        ;;
    "Sleep")
        systemctl suspend
        ;;
    "Reboot")
        terminate_clients
        sleep 0.5
        systemctl reboot
        ;;
    "Shutdown")
        terminate_clients
        sleep 0.5
        systemctl poweroff
        ;;
    *)
        exit 0
        ;;
esac
