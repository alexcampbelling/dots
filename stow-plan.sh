#!/usr/bin/env bash
# stow-plan.sh — shared stow package planning for install.sh and restow.sh.
#
# Source-only; do not run directly. install.sh remains the single source of
# truth for the install pipeline; this file owns the one list of what gets
# stowed and which packages need an app installed first.
#
# Contract (keep in sync with AGENTS.md):
#   - Every top-level directory is a stow package, EXCEPT the structural dirs
#     in STOW_EXCLUDE below (hidden dirs are always ignored).
#   - A package whose app may be absent on a machine lists its required command
#     in STOW_REQUIRES. stow_package_available() reports whether that command is
#     present, so callers can skip the package with a warning instead of stowing
#     config for an app that is not installed.
#
# To add a new config package: drop a new top-level dir — no list edit needed.
# To make a package conditional on an app: add a STOW_REQUIRES entry.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  printf 'stow-plan.sh is a source-only library; source it, do not run it.\n' >&2
  exit 1
fi

: "${REPO_ROOT:="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"}"

# Structural top-level dirs that are NOT stow packages.
STOW_EXCLUDE=(
  assets        # wallpaper source; seeded, not stowed (install.sh)
  packages      # profile manifests; not deployed
  sddm-silent   # owns /etc/sddm.conf.d via its own install.sh
)

# package -> required command. Only listed here when the package should be
# skipped (with a warning) if that command is missing on the machine.
declare -A STOW_REQUIRES=(
  [opencode]=opencode
  [agents]=opencode
)

# Optional per-command install hint shown when a package is skipped.
declare -A STOW_REQUIRE_HINTS=(
  [opencode]="curl -fsSL https://opencode.ai/install | bash"
)

# Fill stow_all_packages[] with every stow package (derived from top-level
# dirs, not hand-maintained).
stow_plan_all() {
  stow_all_packages=()
  local dir name skip excluded
  for dir in "$REPO_ROOT"/*/; do
    name="${dir%/}"
    name="${name##*/}"
    [[ "$name" == .* ]] && continue
    skip=false
    for excluded in "${STOW_EXCLUDE[@]}"; do
      [[ "$name" == "$excluded" ]] && skip=true
    done
    $skip && continue
    stow_all_packages+=("$name")
  done
}

# True (0) when a package has no requirement, or its required command exists.
stow_package_available() {
  local cmd="${STOW_REQUIRES[$1]:-}"
  [[ -z "$cmd" ]] && return 0
  command -v "$cmd" >/dev/null 2>&1
}

# Loud banner for a package skipped because its app is not installed.
stow_skip_warning() {
  local name="$1"
  local cmd="${STOW_REQUIRES[$name]:-}"
  local hint="${STOW_REQUIRE_HINTS[$cmd]:-}"
  printf '\n\033[1;33m[!] SKIPPING %s\033[0m\n' "$name"
  printf '    %s is not installed on this machine, so there is nothing to stow yet.\n' "$cmd"
  [[ -n "$hint" ]] && printf '    Install it with: %s\n' "$hint"
  printf '    Then rerun to stow %s.\n\n' "$name"
}
