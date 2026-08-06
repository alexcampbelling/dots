#!/usr/bin/env bash
set -euo pipefail

WAV_FILE="$1"
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
STATE_DIR="$XDG_RUNTIME_DIR/whisper"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
LOG="$STATE_DIR/whisper.log"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
KEY_DIR="$CONFIG_HOME/whisper"
KEY_FILE="$KEY_DIR/groq-key"

fail() {
    echo "[$(date -Iseconds)] Cloud: $1" >> "$LOG"
    notify-send -t 5000 "Whisper Cloud" "$1" --icon=dialog-error
    exit 1
}

secure_owner_only_directory() {
    local path="$1"
    local mode owner

    [ -d "$path" ] && [ ! -L "$path" ] || return 1
    owner=$(stat -c '%u' "$path")
    mode=$((8#$(stat -c '%a' "$path")))
    [ "$owner" -eq "$UID" ] && (( (mode & 8#077) == 0 ))
}

secure_owner_only_file() {
    local path="$1"
    local mode owner

    [ -e "$path" ] && [ ! -L "$path" ] && [ -f "$path" ] || return 1
    owner=$(stat -c '%u' "$path")
    mode=$((8#$(stat -c '%a' "$path")))
    [ "$owner" -eq "$UID" ] && (( (mode & 8#077) == 0 ))
}

if [ ! -f "$WAV_FILE" ]; then
    fail "No audio file was supplied."
fi

API_KEY="${GROQ_API_KEY:-}"
if [ -z "$API_KEY" ]; then
    if ! secure_owner_only_directory "$KEY_DIR"; then
        fail "Groq key directory must be owned by you and mode 0700. Run: chmod 700 $KEY_DIR"
    fi
    if ! secure_owner_only_file "$KEY_FILE"; then
        fail "Groq key file must be owned by you and mode 0600. Run: chmod 600 $KEY_FILE"
    fi
    API_KEY=$(<"$KEY_FILE")
fi

if [ -z "$API_KEY" ]; then
    fail "The Groq API key is empty."
fi

echo "[$(date -Iseconds)] Cloud: sending to Groq ($(stat -c%s "$WAV_FILE") bytes)" >> "$LOG"
if ! RESPONSE=$(curl -fsS --max-time 30 \
    -H "Authorization: Bearer $API_KEY" \
    -F "file=@$WAV_FILE" \
    -F "model=whisper-large-v3-turbo" \
    -F "response_format=json" \
    -F "language=en" \
    "https://api.groq.com/openai/v1/audio/transcriptions" 2>>"$LOG"); then
    fail "The Groq transcription request failed."
fi

if ! RESULT=$(printf '%s' "$RESPONSE" | jq -er '.text // empty' 2>>"$LOG"); then
    fail "Groq returned an invalid transcription response."
fi

echo "[$(date -Iseconds)] Cloud result received" >> "$LOG"
printf '%s\n' "$RESULT"
