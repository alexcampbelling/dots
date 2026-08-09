#!/bin/bash
# Pause hypridle for N minutes, then auto-resume
# Usage: idle-pause.sh [minutes]   (default: 60)

DURATION_MINS="${1:-60}"
PID=$(pgrep -x hypridle)

if [ -z "$PID" ]; then
    notify-send "hypridle" "Not running"
    exit 1
fi

kill -STOP "$PID"
notify-send -t 3000 "Idle paused" "Auto-resume in ${DURATION_MINS}m"

(sleep "${DURATION_MINS}m" && kill -CONT "$PID" && notify-send -t 3000 "Idle resumed" "Back to 25min lock / 30min suspend") &
