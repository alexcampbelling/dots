#!/usr/bin/env bash
# Restart Waybar after the machine wakes from sleep so every module re-inits.
#
# Notes on why this is not just `pkill waybar && waybar`:
#   * Waybar 0.15.0 can segfault in libpulse's teardown if it receives SIGTERM
#     shortly after resume, so the old bar is killed with SIGKILL instead.
#   * Hyprland may not accept Wayland clients for a moment after resume, so we
#     wait until `hyprctl monitors` answers before starting the replacement.
#   * One launch can be too early (compositor still settling), so retry until a
#     Waybar process is actually alive.
#   * A lock prevents duplicate listeners from a previous login fighting.
set -uo pipefail

log_file="${XDG_RUNTIME_DIR:-/tmp}/waybar-resume.log"
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$log_file"; }

restart_waybar() {
  local i

  # Give Hyprland a chance to finish resuming before any client connects.
  for i in {1..30}; do
    command -v hyprctl >/dev/null 2>&1 &&
      hyprctl monitors >/dev/null 2>&1 && break
    sleep 0.5
  done

  # SIGTERM triggers a libpulse shutdown race in Waybar 0.15.0. SIGKILL skips
  # that path; Hyprland removes the stale layer surfaces when the client dies.
  pkill -KILL -x waybar 2>/dev/null || true
  for i in {1..50}; do
    pgrep -x waybar >/dev/null 2>&1 || break
    sleep 0.1
  done

  # Start detached and retry until the process survives.
  for i in {1..10}; do
    pgrep -x waybar >/dev/null 2>&1 && return 0
    setsid -f waybar >>"${XDG_RUNTIME_DIR:-/tmp}/waybar.log" 2>&1
    sleep 1
  done

  if pgrep -x waybar >/dev/null 2>&1; then
    return 0
  fi
  log "waybar did not come back after 10 attempts"
  return 1
}

# Manual test/repair entry point:
#   ~/.config/hypr/scripts/waybar-restart-on-resume.sh --restart-now
if [[ "${1:-}" == "--restart-now" ]]; then
  if restart_waybar; then
    log "waybar restarted manually (pid $(pgrep -x waybar | head -n1))"
    exit 0
  fi
  exit 1
fi

if ! command -v dbus-monitor >/dev/null 2>&1; then
  exit 0
fi

# Single listener per user session.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-resume.lock"
flock -n 9 || exit 0

dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" 2>/dev/null |
  while IFS= read -r line; do
    [[ "$line" == *member=PrepareForSleep* ]] || continue
    IFS= read -r line || break
    [[ "$line" == *"boolean false"* ]] || continue

    log "resume detected; restarting waybar"
    if restart_waybar; then
      log "waybar restarted (pid $(pgrep -x waybar | head -n1))"
    fi
  done
