#!/usr/bin/env bash
# Hyprland session: start hyprpaper, then restore the last Waypaper selection.
# hyprpaper.conf preload provides the first frame; Waypaper then applies the saved choice.

set -euo pipefail

APP_NAME="Wallpaper"

restore_failed() {
  notify-send -a "${APP_NAME}" -u critical "Restore failed" "waypaper --restore failed after 3 tries."
  exit 1
}

hyprpaper &

# exec-once returns before the daemon is listening; wait for the process, then
# give the IPC socket a moment to come up (usually tens of ms).
for _ in $(seq 1 100); do
  if pidof hyprpaper >/dev/null 2>&1; then
    sleep 0.2
    break
  fi
  sleep 0.05
done

# Restore runs post_command (wal + reload). Suppress success notifications on login —
# WAYPAPER_SILENT is inherited by the post_command shell (same as manual picks without it).
# Retry: rare timing issues on slow I/O; only notify if all attempts fail.
set +e
for attempt in $(seq 1 3); do
  if WAYPAPER_SILENT=1 waypaper --restore; then
    set -e
    exit 0
  fi
  if [[ "${attempt}" -lt 3 ]]; then
    sleep 0.35
  fi
done
set -e

restore_failed
