#!/usr/bin/env bash
# One resume hook restarts the whole bar so every module re-inits (timers, network, etc.).
set -uo pipefail

if ! command -v dbus-monitor >/dev/null 2>&1; then
  exit 0
fi

(
  dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" 2>/dev/null |
    while true; do
      IFS= read -r line || exit 0
      [[ "$line" == *member=PrepareForSleep* ]] || continue
      IFS= read -r line || exit 0
      [[ "$line" == *"boolean false"* ]] || continue
      pkill -x waybar 2>/dev/null || true
      sleep 0.2
      waybar &
    done
) &

exit 0
