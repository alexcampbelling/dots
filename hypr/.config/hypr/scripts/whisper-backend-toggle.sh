#!/usr/bin/env bash
set -euo pipefail

: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
STATE_DIR="$XDG_RUNTIME_DIR/whisper"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
BACKEND_FILE="$STATE_DIR/backend"

BACKEND="cloud"
if [ -f "$BACKEND_FILE" ]; then
    BACKEND=$(cat "$BACKEND_FILE")
fi

if [ "$BACKEND" = "cloud" ]; then
    echo "local" > "$BACKEND_FILE"
    notify-send -t 3000 "Whisper" "Backend: local (checked when you start recording)" --icon=audio-input-microphone
else
    echo "cloud" > "$BACKEND_FILE"
    notify-send -t 2000 "Whisper" "Backend: cloud (Groq)" --icon=audio-input-microphone
fi
