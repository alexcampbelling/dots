#!/usr/bin/env bash
# Waybar JSON poller for the opencode permission/question queue.
# usage: opencode-perm.sh <perm|question>

set -u -o pipefail

KIND="${1:-perm}"
case "$KIND" in perm | question) ;; *) KIND=perm ;; esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/opencode-perm-lib.sh"

mkdir -p "$PERM_DIR" 2>/dev/null
chmod 700 "$PERM_DIR" 2>/dev/null || true

now="$(date +%s)"
count=0
oldest_ts=""
oldest_dir=""
oldest_title=""

for f in "$PERM_DIR"/*; do
  [ -e "$f" ] || continue
  name="${f##*/}"
  case "$name" in .*) continue ;; esac
  [ -f "$f" ] || continue
  [ "$(kind "$name")" = "$KIND" ] || continue

  read_marker "$f"
  if stale "$MPID" "$MTS" "$now"; then
    rm -f "$f" 2>/dev/null
    continue
  fi

  count=$((count + 1))
  if [ -z "$oldest_ts" ] || { [ -n "$MTS" ] && [ "$MTS" -lt "$oldest_ts" ] 2>/dev/null; }; then
    oldest_ts="$MTS"
    oldest_dir="$MDIR"
    oldest_title="$MTITLE"
  fi
done

if [ "$count" -eq 0 ]; then
  printf '%s\n' '{"text":"","tooltip":"","class":"empty"}'
  exit 0
fi

tip="$oldest_title"
[ -n "$tip" ] && [ -n "$oldest_dir" ] && tip="$tip — $oldest_dir"
[ -z "$tip" ] && tip="$oldest_dir"

if command -v python3 >/dev/null 2>&1; then
  tip_json="$(printf '%s' "$tip" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
else
  tip_json="$(printf '"%s"' "$tip" | sed 's/\\/\\\\/g; s/"/\\"/g')"
fi

if [ "$KIND" = "question" ]; then glyph="◆"; else glyph="●"; fi

printf '{"text":"%s %s","tooltip":%s,"class":"pending"}\n' "$glyph" "$count" "$tip_json"
