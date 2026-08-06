#!/usr/bin/env bash
# ── Dunst Notification Test Suite ───────────────────────────────────────────
# Tests all three urgency levels so you can review theming.
# Usage:  bash ~/.config/dunst/test-notifications.sh
#         bash ~/.config/dunst/test-notifications.sh --stack     (stack them)
#         bash ~/.config/dunst/test-notifications.sh --action    (interactive)
#         bash ~/.config/dunst/test-notifications.sh --all       (everything)
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

APP="Dunst Test"

test_low() {
  notify-send -a "$APP" -u low \
    "Low Urgency" \
    "This is a low-priority notification.\nFades after ${1:-4}s — muted title, dim body, subtle border."
  sleep 0.4
}

test_normal() {
  notify-send -a "$APP" -u normal \
    "Normal Urgency" \
    "Standard notification. White title, light body, default border.\nTimeout: ${1:-6}s"
  sleep 0.4
}

test_critical() {
  notify-send -a "$APP" -u critical \
    "Critical Urgency" \
    "Critical notification stays until dismissed.\nRed-tinted title, brighter border."
  sleep 0.4
}

test_action() {
  result=$(dunstify -a "Dunst Action" -u normal -t 10000 -w \
    "Interactive — hover for buttons" \
    "Hover the cursor over this notification. Action buttons appear at the bottom.\nClick the button itself, not the body." \
    --action="okay,Confirm" \
    --action="dismiss,Ignore")
  case "$result" in
    okay)
      notify-send -a "Dunst Action" -u normal \
        "Confirmed" \
        "You pressed Confirm."
      ;;
    dismiss)
      notify-send -a "Dunst Action" -u low \
        "Ignored" \
        "You pressed Ignore."
      ;;
    *)
      echo "Action result: '$result' (timeout or closed without clicking)"
      ;;
  esac
}

test_progress() {
  notify-send -a "$APP" -u normal \
    "Download Progress" \
    "Progress bar at 65%." \
    -h int:value:65
  sleep 0.4
}

test_long() {
  notify-send -a "$APP" -u normal \
    "Long Message Wrapping" \
    "This notification has a longer body to check text wrapping, line-height, and padding at the configured width of 360px. A quick brown fox jumps over the lazy dog."
  sleep 0.4
}

case "${1:-}" in
  --stack)
    test_low; test_normal; test_critical
    ;;
  --action)
    test_action
    ;;
  --all)
    test_low; test_normal; test_critical; test_action; test_progress; test_long
    echo "All tests sent. Check your notification history (history_length = 20)."
    ;;
  *)
    echo "Sending low -> normal -> critical in sequence (dismiss each first)."
    echo "Use --stack to stack them, --action for interactive, --all for everything."
    echo ""
    test_low 10
    sleep 3
    test_normal 10
    sleep 3
    test_critical
    ;;
esac
