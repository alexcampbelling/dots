#!/usr/bin/env bash
# @vicinae.schemaVersion 1
# @vicinae.title Cancel Idle Pause
# @vicinae.icon ⏹
# @vicinae.mode silent
# @vicinae.description Cancel any active idle pause (from the "Idle Pause" command) right away: releases every held idle inhibitor and stops the pause timer, so lock/suspend timers resume immediately.
# @vicinae.keywords ["cancel","stop","undo","resume","idle","pause","sleep","lock","awake","hypridle"]

# Cancels a running "Idle Pause": kills every `systemd-inhibit --what=idle`
# launched with --who=idle-pause (plus its `sleep` child), releasing the
# logind idle inhibitor(s) immediately. Any still-alive pause wrapper script
# then exits via `set -e` when its inhibit call returns, so no misleading
# "Idle resumed" notification fires.
#
# Safety: only processes whose executable is `systemd-inhibit` are touched, so
# this can never kill an unrelated shell even if one mentions these strings.
# Note: undoes ALL active idle pauses (more than one can be running).

set -u

NOTIFY_APP="Idle Pause"
found=0

for pid in $(pgrep -f -- "systemd-inhibit --what=idle --who=idle-pause"); do
    [ "$(ps -o comm= -p "$pid" 2>/dev/null)" = "systemd-inhibit" ] || continue
    # Kill the sleep child first so the inhibitor is released promptly.
    for child in $(pgrep -P "$pid"); do
        kill "$child" 2>/dev/null && found=1
    done
    kill "$pid" 2>/dev/null && found=1
done

if [ "$found" -eq 1 ]; then
    echo "Idle pause cancelled"
    notify-send -a "$NOTIFY_APP" -t 5000 "Idle pause cancelled" \
        "Idle timer is back to normal (25 min lock / 30 min suspend)."
else
    echo "No active idle pause"
    notify-send -a "$NOTIFY_APP" -t 5000 "No active idle pause" \
        "Nothing to cancel."
fi
