# Shared helpers for the opencode permission/question queue.
# Sourced by opencode-perm.sh and opencode-perm-click.sh (do not run directly).
#
# Marker format (one file per pending interrupt in $PERM_DIR):
#   filename: <sessionID>.<kind>   (kind = perm | question)
#   line 1: plugin PID    line 2: project directory
#   line 3: epoch seconds line 4: session title / question header (may be empty)
# Never source/eval marker contents - $PERM_DIR is on world-writable /tmp.

PERM_DIR=/tmp/opencode-perm
PERM_STALE=600

# kind <filename> -> prints "perm" or "question"
kind() {
  case "$1" in
    *.question) printf 'question' ;;
    *) printf 'perm' ;;
  esac
}

# read_marker <path> -> fills globals MPID MDIR MTS MTITLE (no fork)
read_marker() {
  MPID=""; MDIR=""; MTS=""; MTITLE=""
  { IFS= read -r MPID; IFS= read -r MDIR; IFS= read -r MTS; IFS= read -r MTITLE; } < "$1" || true
}

# stale <pid> <ts> <now> -> 0 if the marker should be pruned, 1 otherwise
stale() {
  [ -n "$1" ] && ! kill -0 "$1" 2>/dev/null && return 0
  [ -n "$2" ] && [ "$2" -gt 0 ] 2>/dev/null && [ "$(( $3 - $2 ))" -gt "$PERM_STALE" ] && return 0
  return 1
}
