#!/usr/bin/env bash
# Select the package-provided SilentSDDM theme without modifying package files.

set -Eeuo pipefail

readonly DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_THEME="/usr/share/sddm/themes/silent"
readonly DROP_IN_DIR="/etc/sddm.conf.d"
readonly DROP_IN="${DROP_IN_DIR}/90-dots-silent.conf"
readonly CONFIG_SOURCE="${DOTS_DIR}/configs/90-dots-silent.conf"

dry_run=false
new_drop_in=""

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$new_drop_in" ]] && sudo rm -f "$new_drop_in" 2>/dev/null || true
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: bash ./sddm-silent/install.sh [--dry-run]

Selects the package-provided SilentSDDM theme by writing only the repository-
managed /etc/sddm.conf.d/90-dots-silent.conf drop-in.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run)
        dry_run=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
    shift
  done
}

preflight() {
  [[ $EUID -ne 0 ]] || die "Run this script as your normal user, not root"
  [[ -d "$SOURCE_THEME" ]] || die "SilentSDDM theme not found. Install sddm-silent-theme first."
  [[ -f "$SOURCE_THEME/metadata.desktop" ]] || die "Theme metadata is missing: $SOURCE_THEME/metadata.desktop"
  [[ -r "$CONFIG_SOURCE" ]] || die "Missing SDDM drop-in template: $CONFIG_SOURCE"

  # A monolithic config overrides drop-ins and may contain user-owned settings.
  [[ ! -e /etc/sddm.conf ]] || die "Existing /etc/sddm.conf overrides drop-ins; preserve it and migrate its theme settings manually first."
}

print_dry_run() {
  printf '==> Dry run: no changes will be made.\n'
  printf '    Keep the package theme at %s unchanged.\n' "$SOURCE_THEME"
  printf '    Atomically write only %s to select Current=silent.\n' "$DROP_IN"
  printf '    /usr/share, /usr/local, and /etc/sddm.conf will not be modified.\n'
}

install_theme_selection() {
  sudo -v
  sudo install -d -m 755 "$DROP_IN_DIR"
  new_drop_in="${DROP_IN}.new.$$"
  sudo install -m 644 "$CONFIG_SOURCE" "$new_drop_in"
  sudo mv "$new_drop_in" "$DROP_IN"
  new_drop_in=""
}

main() {
  parse_args "$@"
  preflight
  if $dry_run; then
    print_dry_run
    return 0
  fi

  install_theme_selection
  printf '==> SilentSDDM selected for the next display-manager start.\n'
}

main "$@"
