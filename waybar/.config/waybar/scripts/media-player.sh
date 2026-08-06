#!/usr/bin/env bash
set -u -o pipefail

# HTML entity escape function
html_escape() {
    # Escape ampersands first, then other special characters
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&#39;/g'
}

# For display text, we want to keep quotes as-is but properly escape other entities
display_clean() {
    # First escape ampersands, then handle other entities
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\\"/"/g; s/"/\&quot;/g'
}

# Check if playerctl is installed
if ! command -v playerctl >/dev/null 2>&1; then
    echo '{"text": "⚠️", "tooltip": "playerctl not installed", "class": "error"}'
    exit 1
fi

# Check for active players
PLAYERS=$(playerctl -l 2>/dev/null || true)
if [ -z "$PLAYERS" ]; then
    echo '{"text": "", "class": "stopped"}'
    exit 0
fi

# Initialize variables
SPOTIFY_RUNNING=false
FIREFOX_RUNNING=false
ACTIVE_PLAYER=""
STATUS=""
CLASS=""
BOTH_ACTIVE=false
SPOTIFY_STATUS=""
FIREFOX_STATUS=""

# Track pause times in the per-user runtime directory. Do not source state from
# a shared temporary directory: another user could turn it into shell code.
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
STATE_DIR="$XDG_RUNTIME_DIR/waybar-media"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
PAUSE_TIMES_FILE="$STATE_DIR/pause-times"
SPOTIFY_PAUSED_AT=0
FIREFOX_PAUSED_AT=0

if [ -r "$PAUSE_TIMES_FILE" ]; then
    while IFS='=' read -r key value; do
        case "$key:$value" in
            SPOTIFY_PAUSED_AT:[0-9]*) SPOTIFY_PAUSED_AT="$value" ;;
            FIREFOX_PAUSED_AT:[0-9]*) FIREFOX_PAUSED_AT="$value" ;;
        esac
    done < "$PAUSE_TIMES_FILE"
fi

# Store data for both players to use in the tooltip
SPOTIFY_DATA=()
FIREFOX_DATA=()

# Check if Spotify is running and playing/paused
if echo "$PLAYERS" | grep -q "spotify"; then
    SPOTIFY_RUNNING=true
    
    # Get Spotify status
    SPOTIFY_STATUS=$(playerctl -p spotify status 2>/dev/null)
    
    # Get Spotify metadata
    SPOTIFY_DATA[0]=$(playerctl -p spotify metadata artist 2>/dev/null)
    SPOTIFY_DATA[1]=$(playerctl -p spotify metadata title 2>/dev/null)
    SPOTIFY_DATA[2]=$(playerctl -p spotify metadata album 2>/dev/null)
    SPOTIFY_DATA[3]=$(playerctl -p spotify position 2>/dev/null | cut -d'.' -f1)
    SPOTIFY_DATA[4]=$(playerctl -p spotify metadata mpris:length 2>/dev/null)
    
    # Track when Spotify was paused
    if [ "$SPOTIFY_STATUS" = "Paused" ]; then
        [ "$SPOTIFY_PAUSED_AT" -eq 0 ] 2>/dev/null && SPOTIFY_PAUSED_AT=$(date +%s)
    else
        SPOTIFY_PAUSED_AT=0
    fi
    
    if [ "$SPOTIFY_STATUS" = "Playing" ]; then
        ACTIVE_PLAYER="spotify"
        STATUS="$SPOTIFY_STATUS"
        CLASS="playing"
    elif [ "$SPOTIFY_STATUS" = "Paused" ]; then
        ACTIVE_PLAYER="spotify"
        STATUS="$SPOTIFY_STATUS"
        CLASS="paused"
    fi
fi

# Check if Firefox is running
if echo "$PLAYERS" | grep -q "firefox"; then
    FIREFOX_RUNNING=true
    
    # Get Firefox status
    FIREFOX_STATUS=$(playerctl -p firefox status 2>/dev/null)
    
    # Get Firefox metadata
    FIREFOX_DATA[0]=$(playerctl -p firefox metadata artist 2>/dev/null)
    FIREFOX_DATA[1]=$(playerctl -p firefox metadata title 2>/dev/null)
    FIREFOX_DATA[2]=$(playerctl -p firefox metadata album 2>/dev/null)
    FIREFOX_DATA[3]=$(playerctl -p firefox position 2>/dev/null | cut -d'.' -f1)
    FIREFOX_DATA[4]=$(playerctl -p firefox metadata mpris:length 2>/dev/null)
    FIREFOX_DATA[5]=$(playerctl -p firefox metadata url 2>/dev/null)
    
    # Track when Firefox was paused
    if [ "$FIREFOX_STATUS" = "Paused" ]; then
        [ "$FIREFOX_PAUSED_AT" -eq 0 ] 2>/dev/null && FIREFOX_PAUSED_AT=$(date +%s)
    else
        FIREFOX_PAUSED_AT=0
    fi
    
    # Check for both active condition first, regardless of order
    if [ "$FIREFOX_STATUS" = "Playing" ] && [ "$SPOTIFY_STATUS" = "Playing" ]; then
        BOTH_ACTIVE=true
        # Keep Spotify as primary for now, but mark both as active
        ACTIVE_PLAYER="spotify"
        STATUS="$SPOTIFY_STATUS"
        CLASS="playing-both"
    # Prioritize Firefox if it's playing (and Spotify isn't)
    elif [ "$FIREFOX_STATUS" = "Playing" ]; then
        ACTIVE_PLAYER="firefox"
        STATUS="$FIREFOX_STATUS"
        CLASS="playing-firefox"
    # Use Firefox if it's paused and Spotify isn't playing
    elif [ "$FIREFOX_STATUS" = "Paused" ] && [ "$SPOTIFY_STATUS" != "Playing" ]; then
        # Only switch to Firefox if Spotify is not active or also paused
        if [ -z "$ACTIVE_PLAYER" ] || [ "$SPOTIFY_STATUS" = "Paused" ]; then
            # If both are paused, show whichever was paused most recently
            if [ "$SPOTIFY_STATUS" = "Paused" ] && [ "$SPOTIFY_PAUSED_AT" -gt "$FIREFOX_PAUSED_AT" ] 2>/dev/null; then
                :  # keep Spotify (already set as ACTIVE_PLAYER above)
            else
                ACTIVE_PLAYER="firefox"
                STATUS="$FIREFOX_STATUS"
                CLASS="paused-firefox"
            fi
        fi
    fi
fi

# Save pause timestamps atomically.
pause_times_tmp=$(mktemp "$STATE_DIR/pause-times.XXXXXX")
{
    echo "SPOTIFY_PAUSED_AT=$SPOTIFY_PAUSED_AT"
    echo "FIREFOX_PAUSED_AT=$FIREFOX_PAUSED_AT"
} > "$pause_times_tmp"
mv "$pause_times_tmp" "$PAUSE_TIMES_FILE"

# If nothing is active, exit
if [ -z "$ACTIVE_PLAYER" ]; then
    echo '{"text": "", "class": "stopped"}'
    exit 0
fi

# Get track info for active player
if [ "$ACTIVE_PLAYER" = "spotify" ]; then
    ARTIST="${SPOTIFY_DATA[0]}"
    TITLE="${SPOTIFY_DATA[1]}"
    ALBUM="${SPOTIFY_DATA[2]}"
    POSITION_SEC="${SPOTIFY_DATA[3]}"
    LENGTH_MICROSEC="${SPOTIFY_DATA[4]}"
    # Only set class if not in both_active mode
    if [ "$BOTH_ACTIVE" != "true" ]; then
        CLASS="playing"
        if [ "$SPOTIFY_STATUS" = "Paused" ]; then
            CLASS="paused"
        fi
    fi
else
    ARTIST="${FIREFOX_DATA[0]}"
    TITLE="${FIREFOX_DATA[1]}"
    ALBUM="${FIREFOX_DATA[2]}"
    POSITION_SEC="${FIREFOX_DATA[3]}"
    LENGTH_MICROSEC="${FIREFOX_DATA[4]}"
    URL="${FIREFOX_DATA[5]}"
    # Only set class if not in both_active mode
    if [ "$BOTH_ACTIVE" != "true" ]; then
        if [ "$FIREFOX_STATUS" = "Playing" ]; then
            CLASS="playing-firefox"
        elif [ "$FIREFOX_STATUS" = "Paused" ]; then
            CLASS="paused-firefox"
        fi
    fi
fi

# Set status icon
if [ "$STATUS" = "Playing" ]; then
    STATUS_ICON="▶"
elif [ "$STATUS" = "Paused" ]; then
    STATUS_ICON="⏸"
else
    STATUS_ICON="⏹"
fi

# Format time values if available
format_time() {
    local seconds=$1
    local microseconds=$2
    
    if [ -n "$seconds" ] && [ -n "$microseconds" ] && [ "$microseconds" != "0" ]; then
        # Convert length from microseconds to seconds
        local length_sec=$((microseconds / 1000000))
        
        # Format position
        local min=$((seconds / 60))
        local sec=$((seconds % 60))
        local pos_fmt=$(printf "%d:%02d" $min $sec)
        
        # Format length
        local length_min=$((length_sec / 60))
        local length_sec=$((length_sec % 60))
        local length_fmt=$(printf "%d:%02d" $length_min $length_sec)
        
        echo "$pos_fmt / $length_fmt"
    else
        echo ""
    fi
}

POSITION_FORMATTED=""
LENGTH_FORMATTED=""

# Format active player time
TIME_FORMATTED=$(format_time "$POSITION_SEC" "$LENGTH_MICROSEC")

# Create formatted output based on active player
if [ "$ACTIVE_PLAYER" = "spotify" ]; then
    # Format for Spotify
    ARTIST_TITLE="$ARTIST - $TITLE"
    if [ ${#ARTIST_TITLE} -gt 30 ]; then
        ARTIST_TITLE="${ARTIST_TITLE:0:27}..."
    fi
    
    # Clean display text for HTML output
    DISPLAY_TEXT=$(display_clean "$ARTIST_TITLE")
    
    # Create formatted text with Font Awesome icon (without time info)
    FORMATTED_TEXT="<span font_family='Font Awesome 6 Brands'>&#xf1bc;</span> $DISPLAY_TEXT"
    SOURCE_NAME="Spotify"
    SOURCE_EMOJI="🎵"
else
    # Format for Firefox/YouTube
    # Detect if it's likely YouTube
    YOUTUBE_TITLE=false
    if [[ "$TITLE" == *"YouTube"* ]] || [[ "$URL" == *"youtube"* ]]; then
        YOUTUBE_TITLE=true
    fi
    
    # Setup text based on YouTube detection
    if [ "$YOUTUBE_TITLE" = true ]; then
        # Remove " - YouTube" suffix if present
        CLEAN_TITLE=$(echo "$TITLE" | sed 's/ - YouTube$//')
    else
        CLEAN_TITLE="$TITLE"
    fi
    
    # Add artist if available
    if [ -n "$ARTIST" ]; then
        DISPLAY_TEXT="$ARTIST - $CLEAN_TITLE"
    else
        DISPLAY_TEXT="$CLEAN_TITLE"
    fi
    
    # Truncate if too long
    if [ ${#DISPLAY_TEXT} -gt 30 ]; then
        DISPLAY_TEXT="${DISPLAY_TEXT:0:27}..."
    fi
    
    # Clean display text for HTML output
    DISPLAY_TEXT=$(display_clean "$DISPLAY_TEXT")
    
    # Create formatted text with YouTube icon
    FORMATTED_TEXT="<span font_family='Font Awesome 6 Brands'>&#xf167;</span> $DISPLAY_TEXT"
    
    # Set appropriate source name
    if [ "$YOUTUBE_TITLE" = true ]; then
        SOURCE_NAME="YouTube"
        SOURCE_EMOJI="🎬"
    else
        SOURCE_NAME="Firefox Media"
        SOURCE_EMOJI="🎬"
    fi
fi

# Create tooltip based on what's playing
if [ "$BOTH_ACTIVE" = true ]; then
    # When both are playing, show both players' info
    
    # First format Firefox/YouTube info
    FIREFOX_TITLE=$(html_escape "${FIREFOX_DATA[1]}")
    FIREFOX_ARTIST=$(html_escape "${FIREFOX_DATA[0]}")
    FIREFOX_TIME=$(format_time "${FIREFOX_DATA[3]}" "${FIREFOX_DATA[4]}")
    
    if [[ "${FIREFOX_DATA[1]}" == *"YouTube"* ]] || [[ "${FIREFOX_DATA[5]}" == *"youtube"* ]]; then
        FIREFOX_TITLE=$(echo "$FIREFOX_TITLE" | sed 's/ - YouTube$//')
        FIREFOX_SOURCE="YouTube"
    else
        FIREFOX_SOURCE="Firefox Media"
    fi
    
    # Then format Spotify info
    SPOTIFY_TITLE=$(html_escape "${SPOTIFY_DATA[1]}")
    SPOTIFY_ARTIST=$(html_escape "${SPOTIFY_DATA[0]}")
    SPOTIFY_ALBUM=$(html_escape "${SPOTIFY_DATA[2]}")
    SPOTIFY_TIME=$(format_time "${SPOTIFY_DATA[3]}" "${SPOTIFY_DATA[4]}")
    
    # Build combined tooltip
    TOOLTIP="🎬 $FIREFOX_TITLE"
    
    if [ -n "$FIREFOX_ARTIST" ]; then
        TOOLTIP="$TOOLTIP
👤 $FIREFOX_ARTIST"
    fi
    
    if [ -n "$FIREFOX_TIME" ]; then
        TOOLTIP="$TOOLTIP
🕒 $FIREFOX_TIME"
    fi
    
    TOOLTIP="$TOOLTIP
📊 Playing on $FIREFOX_SOURCE

🎵 $SPOTIFY_TITLE"
    
    if [ -n "$SPOTIFY_ARTIST" ]; then
        TOOLTIP="$TOOLTIP
👤 $SPOTIFY_ARTIST"
    fi
    
    if [ -n "$SPOTIFY_ALBUM" ]; then
        TOOLTIP="$TOOLTIP
💿 $SPOTIFY_ALBUM"
    fi
    
    if [ -n "$SPOTIFY_TIME" ]; then
        TOOLTIP="$TOOLTIP
🕒 $SPOTIFY_TIME"
    fi
    
    TOOLTIP="$TOOLTIP
📊 Playing on Spotify"
else
    # Single player tooltip
    TOOLTIP="$SOURCE_EMOJI $(html_escape "$TITLE")"
    
    # Add artist if available
    if [ -n "$ARTIST" ]; then
        TOOLTIP="$TOOLTIP
👤 $(html_escape "$ARTIST")"
    fi
    
    # Add album if available
    if [ -n "$ALBUM" ]; then
        TOOLTIP="$TOOLTIP
💿 $(html_escape "$ALBUM")"
    fi
    
    # Add URL if it's YouTube
    if [ "$ACTIVE_PLAYER" = "firefox" ] && [ -n "$URL" ]; then
        # Truncate URL if too long
        SHORT_URL=$(echo "$URL" | cut -c 1-60)
        if [ ${#URL} -gt 60 ]; then
            SHORT_URL="${SHORT_URL}..."
        fi
        
        # Escape the URL for HTML
        SHORT_URL=$(html_escape "$SHORT_URL")
        
        TOOLTIP="$TOOLTIP
🔗 $SHORT_URL"
    fi
    
    # Add timing info if available
    if [ -n "$TIME_FORMATTED" ]; then
        TOOLTIP="$TOOLTIP
🕒 $TIME_FORMATTED"
    fi
    
    # Add playback status and click instructions
    TOOLTIP="$TOOLTIP
📊 $STATUS_ICON $STATUS on $SOURCE_NAME"
fi

# Better JSON escape function - avoids double escaping
json_escape() {
    # First remove any existing escapes to prevent double escaping
    local cleaned=$(echo "$1" | sed 's/\\"/"/g')
    # Then properly escape for JSON
    printf '%s' "$cleaned" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# Get escaped values for JSON
TEXT_JSON=$(json_escape "$FORMATTED_TEXT")
TOOLTIP_JSON=$(json_escape "$TOOLTIP")

# Output JSON for waybar
echo "{\"text\": $TEXT_JSON, \"tooltip\": $TOOLTIP_JSON, \"class\": \"$CLASS\"}"
