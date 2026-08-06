#!/usr/bin/env bash

: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
STATE_DIR="$XDG_RUNTIME_DIR/whisper"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

STATE_FILE="$STATE_DIR/state"
BACKEND_FILE="$STATE_DIR/backend"

STATE="idle"
if [ -f "$STATE_FILE" ]; then
    STATE=$(cat "$STATE_FILE")
fi

BACKEND="cloud"
if [ -f "$BACKEND_FILE" ]; then
    BACKEND=$(cat "$BACKEND_FILE")
fi

case "$STATE" in
    recording)
        echo "{\"text\":\"\uf130\",\"tooltip\":\"Whisper: recording ($BACKEND)\",\"class\":\"recording\"}"
        ;;
    transcribing)
        echo "{\"text\":\"\uf252\",\"tooltip\":\"Whisper: transcribing ($BACKEND)\",\"class\":\"transcribing\"}"
        ;;
    error)
        echo "{\"text\":\"\uf131\",\"tooltip\":\"Whisper: error ($BACKEND)\",\"class\":\"error\"}"
        ;;
    idle|*)
        case "$BACKEND" in
            cloud)
                echo "{\"text\":\"\uf131\",\"tooltip\":\"Whisper: idle — cloud mode (right-click to switch)\",\"class\":\"inactive\"}"
                ;;
            *)
                echo "{\"text\":\"\uf131\",\"tooltip\":\"Whisper: idle — local mode (right-click to switch)\",\"class\":\"inactive\"}"
                ;;
        esac
        ;;
esac
