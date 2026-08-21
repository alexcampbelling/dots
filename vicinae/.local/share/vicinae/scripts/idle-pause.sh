#!/usr/bin/env bash
# @vicinae.schemaVersion 1
# @vicinae.title Idle Pause
# @vicinae.icon 🌙
# @vicinae.mode silent
# @vicinae.description Hold an idle inhibitor for N minutes so hypridle won't lock or suspend while a long process runs. When released, hypridle restarts idle detection from zero (no overdue-timer fire).
# @vicinae.keywords ["sleep","lock","suspend","idle","awake","hypridle","hold","pause","stay-awake","keep-awake"]
# @vicinae.argument1 { "type": "text", "placeholder": "minutes (default 60)", "optional": true }

# Pause hypridle's lock/suspend for N minutes, then auto-resume.
#
# Mechanism: hold a logind "idle" inhibitor via systemd-inhibit. hypridle
# respects these because `ignore_systemd_inhibit` defaults to false (and
# `ignore_dbus_inhibit = false` in hypridle.conf). While the inhibitor is held
# hypridle treats the session as active; when it is released the idle clock
# restarts from zero. This avoids the old kill -STOP / SIGCONT approach, which
# fired every overdue timeout (25m lock + 30m suspend) the instant hypridle
# was unpaused.
#
# The inhibitor also survives a manual sleep: if the machine is put to sleep
# mid-pause, the hold resumes on wake with no overdue-timer side effects.
#
# Usage: idle-pause.sh [minutes]   (default: 60)

set -eu

NOTIFY_APP="Idle Pause"

DURATION_MINS="${1:-60}"
DURATION_MINS="${DURATION_MINS%m}"                     # tolerate "90m"
DURATION_MINS="$(printf '%s' "$DURATION_MINS" | tr -d '[:space:]')"

if ! [[ "$DURATION_MINS" =~ ^[0-9]+$ ]] || [ "$DURATION_MINS" -lt 1 ]; then
    echo "invalid duration: minutes must be a positive number"
    notify-send -a "$NOTIFY_APP" -u critical "Invalid duration" \
        "Minutes must be a positive number, got: '${DURATION_MINS:-empty}'"
    exit 1
fi

if ! command -v systemd-inhibit >/dev/null 2>&1; then
    echo "systemd-inhibit not available"
    notify-send -a "$NOTIFY_APP" -u critical "systemd-inhibit missing" \
        "Cannot hold an idle inhibitor"
    exit 1
fi

echo "Idle held off for ${DURATION_MINS} min"
notify-send -a "$NOTIFY_APP" -t 5000 "Idle paused" \
    "Lock/suspend held off for ${DURATION_MINS} min."

systemd-inhibit --what=idle --who=idle-pause --why="manual ${DURATION_MINS}m" \
    sleep "${DURATION_MINS}m"

notify-send -a "$NOTIFY_APP" -t 5000 "Idle resumed" \
    "Back to 25 min lock / 30 min suspend."
echo "Idle resumed after ${DURATION_MINS} min"
