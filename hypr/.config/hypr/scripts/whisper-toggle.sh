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
    echo "error" > "$STATE_FILE"
    echo "cloud" > "$BACKEND_FILE"
    notify-send -t 7000 "Whisper local mode unavailable" \
        "Run install.sh with --profile local-whisper, then download the tiny.en model to ~/.local/share/whisper-models/. Switched back to cloud mode." \
        --icon=dialog-error
    exit 1
fi

# --- If already recording: stop, transcribe, paste ---
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    RECORD_PID=$(cat "$PIDFILE")

    # Keep recording 0.8s longer to catch audio tail in PipeWire pipeline.
    # State stays "recording" (red mic visible) during the buffer.
    sleep 0.8

    echo "transcribing" > "$STATE_FILE"
    kill "$RECORD_PID" 2>/dev/null || true
    rm -f "$PIDFILE"
    sleep 0.2

    echo "[$(date -Iseconds)] Stopped recording (backend: $BACKEND)" >> "$LOG"

    if [ ! -s "$RECORDING" ]; then
        echo "[$(date -Iseconds)] WARNING: No audio captured" >> "$LOG"
        rm -f "$RECORDING"
        echo "idle" > "$STATE_FILE"
        exit 0
    fi

    RAW_BYTES=$(stat -c%s "$RECORDING" 2>/dev/null || echo 0)
    DURATION_TENTHS=$((RAW_BYTES * 10 / 32000))
    DURATION="$((DURATION_TENTHS / 10)).$((DURATION_TENTHS % 10))"
    echo "[$(date -Iseconds)] Raw audio: $RAW_BYTES bytes (~${DURATION}s)" >> "$LOG"

    if ! ffmpeg -y -f s16le -ar 16000 -ac 1 -i "$RECORDING" "$WAV" 2>>"$LOG"; then
        echo "[$(date -Iseconds)] ERROR: Failed to convert recording" >> "$LOG"
        rm -f "$RECORDING" "$WAV"
        echo "error" > "$STATE_FILE"
        exit 1
    fi
    rm -f "$RECORDING"

    case "$BACKEND" in
        cloud)
            if ! RESULT=$("$HOME/.config/hypr/scripts/whisper-cloud.sh" "$WAV"); then
                rm -f "$WAV"
                echo "error" > "$STATE_FILE"
                exit 1
            fi
            ;;
        local)
            if ! RESULT=$(whisper-cli -m "$LOCAL_MODEL" -f "$WAV" --no-timestamps --language en 2>>"$LOG"); then
                rm -f "$WAV"
                echo "error" > "$STATE_FILE"
                notify-send -t 5000 "Whisper local mode failed" "Check the local model and whisper.cpp installation." --icon=dialog-error
                exit 1
            fi
            ;;
        *)
            rm -f "$WAV"
            echo "error" > "$STATE_FILE"
            notify-send -t 5000 "Whisper backend error" "Unknown backend: $BACKEND" --icon=dialog-error
            exit 1
            ;;
    esac
    rm -f "$WAV"

    RESULT=$(echo "$RESULT" | sed 's/^\[.*\] *//' | sed 's/^ *//;s/ *$//' | tr -s '[:space:]' ' ')

    echo "[$(date -Iseconds)] Transcription: ${RESULT:-<empty>}" >> "$LOG"

    if [ -n "$RESULT" ]; then
        echo -n "$RESULT" | wtype -
    fi

    echo "idle" > "$STATE_FILE"
    exit 0
fi

# --- Not recording: start recording ---
if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
fi

echo "[$(date -Iseconds)] Recording started (mic: $MIC, backend: $BACKEND)" >> "$LOG"
echo "recording" > "$STATE_FILE"

parec --device="$MIC" --format=s16le --rate=16000 --channels=1 > "$RECORDING" 2>>"$LOG" &
RECORD_PID=$!
echo "$RECORD_PID" > "$PIDFILE"

sleep 0.1
if ! kill -0 "$RECORD_PID" 2>/dev/null; then
    echo "error" > "$STATE_FILE"
    echo "[$(date -Iseconds)] ERROR: Recording failed to start" >> "$LOG"
    exit 1
fi

echo "[$(date -Iseconds)] Record PID: $RECORD_PID" >> "$LOG"
