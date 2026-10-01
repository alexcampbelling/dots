#!/usr/bin/env bash
set -euo pipefail

: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
STATE_DIR="$XDG_RUNTIME_DIR/whisper"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

STATE_FILE="$STATE_DIR/state"
RECORDING="$STATE_DIR/recording.raw"
PIDFILE="$STATE_DIR/record.pid"
WAV="$STATE_DIR/recording.wav"
LOG="$STATE_DIR/whisper.log"
MIC="@DEFAULT_SOURCE@"
BACKEND_FILE="$STATE_DIR/backend"

# Waybar's custom/whisper module uses "signal": 9, so every state change must
# poke it to re-run whisper-status.sh (otherwise the icon waits up to 1s).
refresh_waybar() {
    pkill -RTMIN+9 -x waybar 2>/dev/null || true
}

set_state() {
    printf '%s\n' "$1" > "$STATE_FILE"
    refresh_waybar
}

BACKEND="${WHISPER_BACKEND:-cloud}"
if [ -f "$BACKEND_FILE" ]; then
    BACKEND=$(cat "$BACKEND_FILE")
fi

LOCAL_MODEL="${WHISPER_MODEL:-$HOME/.local/share/whisper-models/ggml-tiny.en-q5_1.bin}"

local_whisper_ready() {
    command -v whisper-cli >/dev/null 2>&1 && [ -r "$LOCAL_MODEL" ]
}

if [ "$BACKEND" = "local" ] && ! local_whisper_ready; then
    echo "[$(date -Iseconds)] ERROR: Local Whisper is not configured" >> "$LOG"
    set_state error
    echo "cloud" > "$BACKEND_FILE"
    notify-send -t 7000 "Whisper local mode unavailable" \
        "Run install.sh with --profile local-whisper, then download the tiny.en model to ~/.local/share/whisper-models/. Switched back to cloud mode." \
        --icon=dialog-error
    exit 1
fi

# --- If already recording: stop, transcribe, paste ---
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    RECORD_PID=$(cat "$PIDFILE")

    # The user has stopped, so show the transcribing spinner right away.
    set_state transcribing

    # Keep recording briefly longer to catch the audio tail still in the
    # PipeWire pipeline; 0.3s was verified not to clip the last word.
    sleep 0.3

    kill "$RECORD_PID" 2>/dev/null || true
    rm -f "$PIDFILE"
    # Wait for pw-record to exit and close the file instead of a fixed 0.2s
    # sleep; it normally exits within a few milliseconds. The loop caps the
    # wait at 0.5s in case it ignores SIGTERM.
    for _ in {1..50}; do
        kill -0 "$RECORD_PID" 2>/dev/null || break
        sleep 0.01
    done

    echo "[$(date -Iseconds)] Stopped recording (backend: $BACKEND)" >> "$LOG"

    if [ ! -s "$RECORDING" ]; then
        echo "[$(date -Iseconds)] WARNING: No audio captured" >> "$LOG"
        rm -f "$RECORDING"
        set_state idle
        exit 0
    fi

    RAW_BYTES=$(stat -c%s "$RECORDING" 2>/dev/null || echo 0)
    DURATION_TENTHS=$((RAW_BYTES * 10 / 32000))
    DURATION="$((DURATION_TENTHS / 10)).$((DURATION_TENTHS % 10))"
    echo "[$(date -Iseconds)] Raw audio: $RAW_BYTES bytes (~${DURATION}s)" >> "$LOG"

    if ! ffmpeg -y -f s16le -ar 16000 -ac 1 -i "$RECORDING" "$WAV" 2>>"$LOG"; then
        echo "[$(date -Iseconds)] ERROR: Failed to convert recording" >> "$LOG"
        rm -f "$RECORDING" "$WAV"
        set_state error
        exit 1
    fi
    rm -f "$RECORDING"

    case "$BACKEND" in
        cloud)
            if ! RESULT=$("$HOME/.config/hypr/scripts/whisper-cloud.sh" "$WAV"); then
                rm -f "$WAV"
                set_state error
                exit 1
            fi
            ;;
        local)
            if ! RESULT=$(whisper-cli -m "$LOCAL_MODEL" -f "$WAV" --no-timestamps --language en 2>>"$LOG"); then
                rm -f "$WAV"
                set_state error
                notify-send -t 5000 "Whisper local mode failed" "Check the local model and whisper.cpp installation." --icon=dialog-error
                exit 1
            fi
            ;;
        *)
            rm -f "$WAV"
            set_state error
            notify-send -t 5000 "Whisper backend error" "Unknown backend: $BACKEND" --icon=dialog-error
            exit 1
            ;;
    esac
    rm -f "$WAV"

    RESULT=$(echo "$RESULT" | sed 's/^\[.*\] *//' | sed 's/^ *//;s/ *$//' | tr -s '[:space:]' ' ')

    echo "[$(date -Iseconds)] Transcription: ${RESULT:-<empty>}" >> "$LOG"

    if [ -n "$RESULT" ]; then
        # ydotool injects through uinput, so every client (Chromium, Firefox,
        # X11, terminals) receives real key events. wtype is the fallback for
        # machines where the ydotool daemon is not available.
        if command -v ydotool >/dev/null 2>&1; then
            printf '%s' "$RESULT" | ydotool type -H 2 -d 2 -f -
        else
            printf '%s' "$RESULT" | wtype -
        fi
    fi

    set_state idle
    exit 0
fi

# --- Not recording: start recording ---
if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
fi

echo "[$(date -Iseconds)] Recording started (mic: $MIC, backend: $BACKEND)" >> "$LOG"
set_state recording

# Native PipeWire capture (pw-record): goes straight through PipeWire's own
# protocol. Replaces `parec`, which negotiated a PulseAudio-compat shm
# stream through pipewire-pulse first — that extra layer does its own
# memfd/SCM_RIGHTS passing. Fewer fd transports = fewer in-flight fds.
if [ "$MIC" = "@DEFAULT_SOURCE@" ]; then
    pw-record --format=s16 --rate=16000 --channels=1 "$RECORDING" 2>>"$LOG" &
else
    pw-record --target="$MIC" --format=s16 --rate=16000 --channels=1 "$RECORDING" 2>>"$LOG" &
fi
RECORD_PID=$!
echo "$RECORD_PID" > "$PIDFILE"

sleep 0.1
if ! kill -0 "$RECORD_PID" 2>/dev/null; then
    set_state error
    echo "[$(date -Iseconds)] ERROR: Recording failed to start" >> "$LOG"
    exit 1
fi

echo "[$(date -Iseconds)] Record PID: $RECORD_PID" >> "$LOG"
