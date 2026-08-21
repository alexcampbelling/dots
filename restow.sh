#!/usr/bin/env bash
# Restow dotfiles only — no package installs, no services, no seeding.
#
# Stows every package (see stow-plan.sh for the list). Packages whose required
# app is not installed are skipped with a loud warning; install the app and
# rerun to pick them up.

set -Eeuo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/stow-plan.sh"

dry_run=false
declare -a stow_packages=()
declare -a skipped_packages=()

usage() {
  cat <<'EOF'
Usage: bash ./restow.sh [--dry-run]

Restows all dotfiles. No packages, services, or seeded files are touched.
Packages whose app is not installed are skipped with a warning; install the
app and rerun to stow them.

--dry-run simulates the link changes without modifying anything.
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '\n==> %s\n' "$*"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  stow_packages=()
  skipped_packages=()
  stow_plan_all
  local name
  for name in "${stow_all_packages[@]}"; do
    if stow_package_available "$name"; then
      stow_packages+=("$name")
    else
      skipped_packages+=("$name")
      stow_skip_warning "$name"
    fi
  done

  ((${#stow_packages[@]})) || die "Nothing to stow: every package was skipped"

  log "Stow preflight: simulating link changes (no files will be changed)"
  if ! stow --simulate --restow --no-folding --dir "$REPO_ROOT" --target "$HOME" "${stow_packages[@]}"; then
    die "Stow preflight failed. Resolve the conflicts above manually, then rerun"
  fi

  if $dry_run; then
    log "Dry run: no changes were made"
    return 0
  fi

  log "Stow deployment: creating or updating dotfile links in $HOME"
  stow --restow --no-folding --dir "$REPO_ROOT" --target "$HOME" "${stow_packages[@]}"

  if ((${#skipped_packages[@]})); then
    log "Skipped packages — install the missing app, then rerun to stow them"
    printf '    %s\n' "${skipped_packages[@]}"
  fi
}

main "$@"
