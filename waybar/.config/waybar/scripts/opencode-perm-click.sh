#!/usr/bin/env bash
# Waybar on-click handler for the opencode permission/question queue.
# usage: opencode-perm-click.sh <perm|question>
# Focuses the Kitty window with the oldest pending interrupt of the kind,
# cycling on repeat clicks. The only place hyprctl runs.

set -u -o pipefail

KIND="${1:-perm}"
case "$KIND" in perm | question) ;; *) KIND=perm ;; esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/opencode-perm-lib.sh"

CURSOR="$PERM_DIR/.cursor.$KIND"

mkdir -p "$PERM_DIR" 2>/dev/null
chmod 700 "$PERM_DIR" 2>/dev/null || true
command -v hyprctl >/dev/null 2>&1 || exit 0

now="$(date +%s)"
entries=()

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
  entries+=("$(printf '%020d\t%s' "${MTS:-0}" "$name")")
done

[ "${#entries[@]}" -gt 0 ] || exit 0

readarray -t sorted < <(printf '%s\n' "${entries[@]}" | sort -n)
names=()
for e in "${sorted[@]}"; do names+=("${e#*$'\t'}"); done

target=0
cursor=""
[ -f "$CURSOR" ] && cursor="$(cat "$CURSOR" 2>/dev/null)"
if [ -n "$cursor" ]; then
  idx=0
  for n in "${names[@]}"; do
    if [ "$n" = "$cursor" ]; then
      target=$(( (idx + 1) % ${#names[@]} ))
      break
    fi
    idx=$((idx + 1))
  done
fi

name="${names[$target]}"
read_marker "$PERM_DIR/$name"

# Snapshot Hyprland client PIDs, then walk /proc ancestry from the plugin PID.
declare -A PID_SET=()
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r p; do PID_SET[$p]=1; done < <(hyprctl clients -j 2>/dev/null | jq -r '.[].pid' 2>/dev/null)
else
  while IFS= read -r p; do PID_SET[$p]=1; done < <(hyprctl clients -j 2>/dev/null | grep -oE '"pid": *[0-9]+' | grep -oE '[0-9]+')
fi

read_ppid() {
  local line rest
  IFS= read -r line < "/proc/$1/stat" 2>/dev/null || return 1
  rest="${line#*)}"
  set -- $rest
  printf '%s' "$2"
}

resolve_client_pid() {
  local p="$1" ppid i
  for ((i = 0; i < 30; i++)); do
    [ -n "${PID_SET[$p]:-}" ] && { printf '%s' "$p"; return 0; }
    ppid="$(read_ppid "$p")" || return 1
    [ -n "$ppid" ] && [ "$ppid" -gt 1 ] || return 1
    p="$ppid"
  done
  return 1
}

client_pid="$(resolve_client_pid "$MPID")" || client_pid=""

if [ -n "$client_pid" ]; then
  hyprctl dispatch "hl.dsp.focus({ window = \"pid:$client_pid\" })" >/dev/null 2>&1
else
  printf 'opencode-perm: could not resolve a client PID for %s (plugin pid %s)\n' "$name" "$MPID" >&2
fi

printf '%s\n' "$name" > "$CURSOR.tmp" 2>/dev/null && mv "$CURSOR.tmp" "$CURSOR" 2>/dev/null
