#!/usr/bin/env bash
# Install composable package profiles and deploy dotfiles after Archinstall.
#
# Reading order: turn CLI options into a plan, optionally print that plan,
# then install packages, seed local state, Stow configs, and enable services.

set -Eeuo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROFILE_ROOT="$REPO_ROOT/packages/profiles"
readonly MONITOR_CONFIG="$REPO_ROOT/hypr/.config/hypr/conf/monitors.conf"
readonly MONITOR_EXAMPLE="$REPO_ROOT/hypr/.config/hypr/conf/monitors.conf.example"
readonly DEFAULT_WALLPAPER="$REPO_ROOT/assets/wallpapers/pillars.jpg"
readonly SDDM_INSTALLER="$REPO_ROOT/sddm-silent/install.sh"
readonly SDDM_DROP_IN_TEMPLATE="$REPO_ROOT/sddm-silent/configs/90-dots-silent.conf"
readonly STOW_PACKAGES=(
  bash dunst fontconfig gtk-3.0 hypr kitty lazygit mimeapps.list
  rofi theme Thunar waybar waypaper xfce4
)
readonly NETWORK_CONFLICT_UNITS=(
  systemd-networkd.service dhcpcd.service connman.service netctl.service wicd.service
)

yay_build_dir=""
dry_run=false
non_interactive=false
skip_services=false
deploy_opencode=false
optional_profile_requested=false
enable_networkmanager=false
enable_bluetooth=false
enable_ufw=false
enable_cups=false
enable_avahi=false
enable_sddm=false
enable_tailscale=false
enable_syncthing=false
declare -a requested_profiles=()
declare -a resolved_profiles=()
declare -a pacman_packages=()
declare -a aur_packages=()
declare -a stow_packages=()
declare -a optional_pacman_candidates=()
declare -a optional_aur_candidates=()
declare -a selected_optional_packages=()

usage() {
  cat <<'EOF'
Usage: bash ./install.sh [--profile <name>]... [--dry-run] [--non-interactive] [--skip-services]

System and desktop are always installed. Available optional profiles:
  optional, code, local-whisper

Repeat --profile to add capabilities. Duplicate profiles are installed once.

--dry-run validates repository inputs and prints the install plan without
running sudo, pacman, yay, systemctl, Stow, or making any file changes.

--non-interactive automatically accepts Pacman and Yay package prompts.
Optional application and service choices remain interactive.

--skip-services makes no system-service or boot-target changes and skips the
service questions. It does not skip required package-repository configuration.
Use it when adding profiles to an already configured machine.

--profile optional asks about each home-machine application individually.
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '\n==> %s\n' "$*"
}

cleanup() {
  if [[ -n "$yay_build_dir" && -d "$yay_build_dir" ]]; then
    rm -rf "$yay_build_dir"
  fi
}

trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

is_supported_profile() {
  case "$1" in
    system|desktop|optional|code|local-whisper) return 0 ;;
    *) return 1 ;;
  esac
}

parse_args() {
  while (($#)); do
    case "$1" in
      --profile)
        (($# >= 2)) || die "--profile requires a value"
        requested_profiles+=("$2")
        shift 2
        ;;
      --profile=*)
        requested_profiles+=("${1#--profile=}")
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --non-interactive)
        non_interactive=true
        shift
        ;;
      --skip-services)
        skip_services=true
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

  local profile
  for profile in "${requested_profiles[@]}"; do
    is_supported_profile "$profile" || die "Unsupported profile: $profile"
  done
}

read_manifest() {
  local manifest="$1"
  local -n destination="$2"
  local line

  [[ -f "$manifest" ]] || die "Manifest not found: ${manifest#$REPO_ROOT/}"
  destination=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && destination+=("$line")
  done < "$manifest"
  return 0
}

append_unique() {
  local -n destination="$1"
  local entry="$2"
  local existing

  for existing in "${destination[@]}"; do
    [[ "$existing" == "$entry" ]] && return 0
  done
  destination+=("$entry")
}

contains() {
  local needle="$1"
  shift
  local entry
  for entry in "$@"; do
    [[ "$entry" == "$needle" ]] && return 0
  done
  return 1
}

resolve_profiles() {
  local profile

  resolved_profiles=()
  for profile in system desktop "${requested_profiles[@]}"; do
    if [[ "$profile" == "optional" ]]; then
      optional_profile_requested=true
      continue
    fi
    append_unique resolved_profiles "$profile"
  done
}

collect_packages() {
  local source="$1"
  local -n packages="$2"
  local -a entries
  local profile entry

  packages=()
  for profile in "${resolved_profiles[@]}"; do
    read_manifest "$PROFILE_ROOT/$profile/$source.txt" entries
    for entry in "${entries[@]}"; do
      append_unique packages "$entry"
    done
  done
}

build_install_plan() {
  local -a aur_candidates=()
  local package

  collect_packages pacman pacman_packages
  collect_packages aur aur_candidates
  aur_packages=()
  for package in "${aur_candidates[@]}"; do
    contains "$package" "${pacman_packages[@]}" || append_unique aur_packages "$package"
  done

  optional_pacman_candidates=()
  optional_aur_candidates=()
  if $optional_profile_requested; then
    read_manifest "$PROFILE_ROOT/optional/pacman.txt" optional_pacman_candidates
    read_manifest "$PROFILE_ROOT/optional/aur.txt" optional_aur_candidates
  fi
}

profile_requires_multilib() {
  contains steam "${pacman_packages[@]}"
}

build_stow_plan() {
  stow_packages=("${STOW_PACKAGES[@]}")
  deploy_opencode=false

  if contains code "${resolved_profiles[@]}"; then
    if command -v opencode >/dev/null 2>&1; then
      stow_packages+=(opencode agents)
      deploy_opencode=true
    fi
  fi
}

validate_repository_inputs() {
  local package

  [[ -r "$DEFAULT_WALLPAPER" ]] || die "Default wallpaper is missing: ${DEFAULT_WALLPAPER#$REPO_ROOT/}"
  [[ -r "$MONITOR_EXAMPLE" ]] || die "Monitor example is missing: ${MONITOR_EXAMPLE#$REPO_ROOT/}"
  [[ -f "$SDDM_INSTALLER" ]] || die "SDDM theme installer is missing: ${SDDM_INSTALLER#$REPO_ROOT/}"
  [[ -r "$SDDM_DROP_IN_TEMPLATE" ]] || die "SDDM drop-in template is missing: ${SDDM_DROP_IN_TEMPLATE#$REPO_ROOT/}"

  for package in "${stow_packages[@]}"; do
    [[ -d "$REPO_ROOT/$package" ]] || die "Stow package directory is missing: $package"
  done
}

print_package_list() {
  local label="$1"
  shift

  printf '    %s:' "$label"
  if (($# == 0)); then
    printf ' (none)\n'
    return
  fi
  printf '\n'
  printf '      %s\n' "$@"
}

print_dry_run() {
  log "Dry run: no changes will be made"
  print_package_list "Profiles" "${resolved_profiles[@]}"
  print_package_list "Pacman packages" "${pacman_packages[@]}"
  print_package_list "AUR packages" "${aur_packages[@]}"

  if ((${#aur_packages[@]})); then
    printf '    Yay: install yay-bin if yay is unavailable, then install the AUR packages above.\n'
  else
    printf '    Yay: not needed for these profiles.\n'
  fi

  printf '    Wallpaper: seed ~/wallpaper/pillars.jpg only when it is missing.\n'
  printf '    Monitors: seed the ignored hypr/.config/hypr/conf/monitors.conf only when it is missing.\n'
  printf '    Whisper: ensure ~/.config/whisper exists with owner-only permissions; API keys are never read or created.\n'
  print_package_list "Stow packages" "${stow_packages[@]}"
  if contains code "${resolved_profiles[@]}" && ! $deploy_opencode; then
    printf '    OpenCode: skip its config and skills because opencode is not installed.\n'
    printf '      Install upstream with: curl -fsSL https://opencode.ai/install | bash\n'
    printf '      Then rerun with --profile code.\n'
  fi
  if [[ -e /etc/sddm.conf ]]; then
    printf '    SDDM theme: preserve existing /etc/sddm.conf; do not add a drop-in.\n'
  else
    printf '    SDDM theme: select the package-provided SilentSDDM theme with a managed drop-in.\n'
  fi
  if $skip_services; then
    printf '    Services: skipped; no services or boot target will be changed.\n'
  else
    printf '    Services: a real install asks before enabling NetworkManager, Bluetooth, UFW, CUPS, Avahi, Tailscale, or SDDM with graphical boot.\n'
  fi
  if $optional_profile_requested; then
    print_package_list "Optional Pacman candidates (not selected in dry run)" "${optional_pacman_candidates[@]}"
    print_package_list "Optional AUR candidates (not selected in dry run)" "${optional_aur_candidates[@]}"
    printf '    Optional packages: a real install asks about each candidate; Steam enables multilib and Syncthing offers its user service only when selected.\n'
  fi
  if $non_interactive; then
    printf '    Package prompts: automatically accepted; Yay build cleanup and diff prompts are skipped.\n'
  else
    printf '    Package prompts: Pacman and Yay will ask before installing packages.\n'
  fi
  if contains rustup "${pacman_packages[@]}"; then
    printf '    Rustup: configure stable as the default toolchain only when none is configured.\n'
  fi
}

prompt_yes_no() {
  local question="$1"
  local consequence="$2"
  local answer

  while true; do
    printf '\n%s\n%s [y/n]: ' "$consequence" "$question"
    if ! IFS= read -r answer </dev/tty; then
      die "Could not read a choice from the terminal; run the installer interactively"
    fi

    case "$answer" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      *) printf 'Please answer y or n.\n' >&2 ;;
    esac
  done
}

collect_optional_package_choices() {
  local package

  $optional_profile_requested || return 0
  selected_optional_packages=()
  log "Choose optional packages"

  for package in "${optional_pacman_candidates[@]}"; do
    if prompt_yes_no "Install $package?" "Adds the optional package $package."; then
      append_unique pacman_packages "$package"
      append_unique selected_optional_packages "$package"
    fi
  done

  for package in "${optional_aur_candidates[@]}"; do
    if prompt_yes_no "Install $package from the AUR?" "Adds the optional AUR package $package."; then
      contains "$package" "${pacman_packages[@]}" || append_unique aur_packages "$package"
      append_unique selected_optional_packages "$package"
    fi
  done

  return 0
}

collect_service_choices() {
  log "Choose system-wide services"
  prompt_yes_no \
    "Enable NetworkManager?" \
    "Starts NetworkManager at boot so this computer can manage Wi-Fi and Ethernet." \
    && enable_networkmanager=true
  prompt_yes_no \
    "Enable Bluetooth?" \
    "Starts the Bluetooth daemon at boot for pairing and using Bluetooth devices." \
    && enable_bluetooth=true
  prompt_yes_no \
    "Enable UFW firewall?" \
    "Enables UFW now and at boot, applying its current/default inbound firewall policy." \
    && enable_ufw=true
  prompt_yes_no \
    "Enable CUPS printing?" \
    "Starts the CUPS printing service at boot." \
    && enable_cups=true
  prompt_yes_no \
    "Enable Avahi network discovery?" \
    "Starts mDNS/DNS-SD discovery at boot, allowing local-network service discovery." \
    && enable_avahi=true
  prompt_yes_no \
    "Enable Tailscale?" \
    "Starts the Tailscale daemon at boot. You must still run 'sudo tailscale up' and authenticate to join a tailnet." \
    && enable_tailscale=true
  prompt_yes_no \
    "Enable SDDM graphical login at boot?" \
    "Enables SDDM and makes graphical.target the default boot mode, so this computer starts at the graphical login screen." \
    && enable_sddm=true

  if contains syncthing "${pacman_packages[@]}"; then
    prompt_yes_no \
      "Enable Syncthing for this user?" \
      "Enables the Syncthing user service for future logins. Device pairing and folder setup remain manual." \
      && enable_syncthing=true
  fi

  return 0
}

install_yay() {
  local -a makepkg_args=(-si)

  if command -v yay >/dev/null 2>&1; then
    log "Yay is already installed"
    return
  fi

  $non_interactive && makepkg_args+=(--noconfirm)

  log "Installing Yay"
  yay_build_dir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay-bin.git "$yay_build_dir/yay-bin"
  (
    cd "$yay_build_dir/yay-bin"
    makepkg "${makepkg_args[@]}"
  )
}

install_packages() {
  local -a pacman_args=(-Syu --needed)
  local -a yay_args=(-S --needed)

  log "Selected profiles"
  printf '    %s\n' "${resolved_profiles[*]}"

  if $non_interactive; then
    pacman_args+=(--noconfirm)
    yay_args+=(--noconfirm --answerclean None --answerdiff None)
  fi

  log "Updating the system and installing official packages"
  sudo pacman "${pacman_args[@]}" "${pacman_packages[@]}"

  ((${#aur_packages[@]})) || return 0
  install_yay
  log "Installing AUR packages"
  yay "${yay_args[@]}" "${aur_packages[@]}"
}

ensure_rustup_default_toolchain() {
  contains rustup "${pacman_packages[@]}" || return 0

  if rustup default >/dev/null 2>&1; then
    log "Rustup default toolchain is already configured"
    return
  fi

  log "Configuring Rustup stable toolchain"
  rustup default stable
}

assert_no_unmanaged_typescript() {
  contains typescript "${pacman_packages[@]}" || return 0

  if [[ -e /usr/bin/tsc ]] && ! pacman -Qo /usr/bin/tsc >/dev/null 2>&1; then
    die "Unmanaged TypeScript files are present at /usr/bin/tsc. Remove the global npm package with 'sudo npm uninstall -g typescript', then rerun the installer"
  fi
}

ensure_multilib_for_selected_packages() {
  profile_requires_multilib || return 0

  if pacman-conf --repo-list | grep -qx 'multilib'; then
    log "Arch multilib repository is already enabled"
    return
  fi

  if ! grep -Eq '^[[:space:]]*#\[multilib\][[:space:]]*$' /etc/pacman.conf \
    || ! grep -Eq '^[[:space:]]*#Include = /etc/pacman\.d/mirrorlist[[:space:]]*$' /etc/pacman.conf; then
    die "Steam requires Arch's [multilib] repository. Enable a valid [multilib] stanza in /etc/pacman.conf, run sudo pacman -Syu, then rerun the installer"
  fi

  log "Enabling Arch multilib repository for Steam"
  sudo sed -i \
    '/^[[:space:]]*#\[multilib\][[:space:]]*$/,/^[[:space:]]*#Include = \/etc\/pacman\.d\/mirrorlist[[:space:]]*$/ s/^[[:space:]]*#//' \
    /etc/pacman.conf

  pacman-conf --repo-list | grep -qx 'multilib' \
    || die "Could not enable Arch's [multilib] repository; check /etc/pacman.conf before continuing"
}

seed_wallpaper() {
  local wallpaper_dir="$HOME/wallpaper"
  local destination="$wallpaper_dir/pillars.jpg"

  [[ -r "$DEFAULT_WALLPAPER" ]] || die "Default wallpaper is missing: ${DEFAULT_WALLPAPER#$REPO_ROOT/}"
  mkdir -p "$wallpaper_dir"
  if [[ -e "$destination" || -L "$destination" ]]; then
    log "Preserving existing wallpaper: $destination"
    return
  fi

  log "Installing default wallpaper: $destination"
  install -m 644 "$DEFAULT_WALLPAPER" "$destination"
}

seed_monitor_config() {
  [[ -r "$MONITOR_EXAMPLE" ]] || die "Monitor example is missing: ${MONITOR_EXAMPLE#$REPO_ROOT/}"
  if [[ -e "$MONITOR_CONFIG" || -L "$MONITOR_CONFIG" ]]; then
    log "Preserving local monitor configuration: $MONITOR_CONFIG"
    return
  fi

  log "Seeding local monitor configuration"
  install -m 644 "$MONITOR_EXAMPLE" "$MONITOR_CONFIG"
}

prepare_whisper_key_directory() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local key_dir="$config_home/whisper"

  if [[ -e "$key_dir" || -L "$key_dir" ]]; then
    [[ -d "$key_dir" && ! -L "$key_dir" && -O "$key_dir" ]] \
      || die "Whisper key directory must be an ordinary directory owned by the current user: $key_dir"
  else
    mkdir -p "$key_dir"
  fi

  log "Securing Whisper key directory: $key_dir"
  chmod 700 "$key_dir"
}

configure_sddm_theme() {
  [[ -f "$SDDM_INSTALLER" ]] || die "SDDM theme installer is missing: ${SDDM_INSTALLER#$REPO_ROOT/}"
  if [[ -e /etc/sddm.conf ]]; then
    log "Preserving existing /etc/sddm.conf; not changing the SDDM theme"
    return
  fi

  log "Selecting the package-provided SilentSDDM theme"
  bash "$SDDM_INSTALLER"
}

deploy_configs() {
  local stow_output

  if contains code "${resolved_profiles[@]}" && ! $deploy_opencode; then
    log "Skipping OpenCode configuration because the opencode command is not installed"
    printf '    Install upstream with: curl -fsSL https://opencode.ai/install | bash\n'
    printf '    Then rerun with --profile code.\n'
  fi

  log "Stow preflight: simulating link changes (no files will be changed)"
  if ! stow_output="$(stow --simulate --restow --no-folding --dir "$REPO_ROOT" --target "$HOME" "${stow_packages[@]}" 2>&1)"; then
    printf '%s\n' "$stow_output" >&2
    die "Stow preflight failed. Resolve the conflicts above manually, then rerun the installer"
  fi

  log "Stow deployment: creating or updating dotfile links in $HOME"
  stow --restow --no-folding --dir "$REPO_ROOT" --target "$HOME" "${stow_packages[@]}"
}

configure_gnome_dark_mode() {
  if ! command -v gsettings >/dev/null 2>&1; then
    printf '    GNOME dark mode: skipped because gsettings is unavailable\n'
    return
  fi

  log "Setting GNOME applications to dark mode"
  if gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null; then
    return
  fi

  if command -v dbus-run-session >/dev/null 2>&1 \
    && dbus-run-session -- gsettings set org.gnome.desktop.interface color-scheme prefer-dark; then
    return
  fi

  printf '    GNOME dark mode: could not save the GSettings preference; run: gsettings set org.gnome.desktop.interface color-scheme prefer-dark\n' >&2
}

unit_enabled_or_active() {
  local unit="$1"
  systemctl is-enabled --quiet "$unit" 2>/dev/null || systemctl is-active --quiet "$unit" 2>/dev/null
}

assert_no_network_manager_conflicts() {
  local -a conflicts=()
  local unit

  for unit in "${NETWORK_CONFLICT_UNITS[@]}"; do
    unit_enabled_or_active "$unit" && conflicts+=("$unit")
  done
  ((${#conflicts[@]} == 0)) || die "Resolve competing network managers before continuing: ${conflicts[*]}"
}

ensure_service_enabled() {
  local unit="$1"
  local enabled_state active_state

  if systemctl is-enabled --quiet "$unit"; then
    enabled_state="already enabled"
  else
    log "Enabling $unit for future boots"
    sudo systemctl enable "$unit" || die "Could not enable $unit"
    systemctl is-enabled --quiet "$unit" || die "$unit did not become enabled"
    enabled_state="enabled"
  fi

  active_state="$(systemctl is-active "$unit" 2>/dev/null || true)"
  printf '    %s: %s; currently %s; not restarted\n' "$unit" "$enabled_state" "${active_state:-unknown}"
}

ensure_user_service_enabled() {
  local unit="$1"
  local enabled_state active_state

  if systemctl --user is-enabled --quiet "$unit"; then
    enabled_state="already enabled"
  else
    log "Enabling $unit for future user sessions"
    systemctl --user enable "$unit" || die "Could not enable user service $unit"
    systemctl --user is-enabled --quiet "$unit" || die "$unit did not become enabled for this user"
    enabled_state="enabled"
  fi

  active_state="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
  printf '    %s (user): %s; currently %s; not restarted\n' "$unit" "$enabled_state" "${active_state:-unknown}"
}

enable_firewall() {
  if sudo ufw status | grep -q '^Status: active$'; then
    printf '    UFW rules are already active; not reloaded\n'
  else
    log "Activating UFW firewall rules"
    sudo ufw --force enable || die "Could not activate UFW"
  fi
  ensure_service_enabled ufw.service
}

configure_services() {
  log "Checking system services"
  if $enable_networkmanager; then
    assert_no_network_manager_conflicts
    ensure_service_enabled NetworkManager.service
  fi
  $enable_bluetooth && ensure_service_enabled bluetooth.service
  $enable_ufw && enable_firewall
  $enable_cups && ensure_service_enabled cups.service
  $enable_avahi && ensure_service_enabled avahi-daemon.service
  $enable_tailscale && ensure_service_enabled tailscaled.service
  $enable_syncthing && ensure_user_service_enabled syncthing.service

  if $enable_sddm; then
    ensure_service_enabled sddm.service
    log "Setting graphical.target for future boots"
    sudo systemctl set-default graphical.target || die "Could not set graphical.target"
    [[ "$(systemctl get-default)" == "graphical.target" ]] || die "graphical.target was not set as default"
  fi
}

print_summary() {
  log "Installation complete"
  printf '    Profiles: %s\n' "${resolved_profiles[*]}"
  if $optional_profile_requested; then
    print_package_list "Selected optional packages" "${selected_optional_packages[@]}"
  fi
  if $skip_services; then
    printf '    Services: unchanged (--skip-services).\n'
  else
    printf '    Services: NetworkManager=%s, Bluetooth=%s, UFW=%s, CUPS=%s, Avahi=%s, Tailscale=%s, SDDM+graphical.target=%s, Syncthing=%s\n' \
      "$enable_networkmanager" "$enable_bluetooth" "$enable_ufw" "$enable_cups" "$enable_avahi" "$enable_tailscale" "$enable_sddm" "$enable_syncthing"
  fi
  printf '    PipeWire and WirePlumber start in your graphical user session.\n'
  printf '    Check README.md for hardware-driver and monitor-layout setup.\n'
  printf '    Configure the optional Groq key using the secure README instructions.\n'
  printf '    Reboot when ready: sudo systemctl reboot\n'
}

main() {
  # Planning is side-effect free, so --dry-run shares the same profile and
  # manifest resolution as a real install without touching the machine.
  parse_args "$@"
  resolve_profiles
  build_install_plan
  build_stow_plan
  validate_repository_inputs

  if $dry_run; then
    print_dry_run
    return 0
  fi

  [[ $EUID -ne 0 ]] || die "Run this installer as your normal login user, not root"
  require_command pacman
  require_command sudo
  require_command git
  require_command systemctl
  [[ -w "$REPO_ROOT" ]] || die "Repository is not writable: $REPO_ROOT"
  collect_optional_package_choices
  if $skip_services; then
    log "Skipping service questions and system service changes"
  else
    collect_service_choices
  fi

  assert_no_unmanaged_typescript

  # From here onward the installer intentionally changes the machine.
  sudo -v
  ensure_multilib_for_selected_packages
  install_packages
  ensure_rustup_default_toolchain

  # These preserve existing per-machine files; Stow owns only the listed
  # repository directories, not every top-level directory.
  seed_wallpaper
  seed_monitor_config
  prepare_whisper_key_directory
  deploy_configs
  configure_gnome_dark_mode

  # SDDM is system-wide, so its selected theme is a managed /etc drop-in rather
  # than a Stowed user config. Existing monolithic SDDM config is preserved.
  configure_sddm_theme

  # Services are enabled for future boots and are not restarted mid-session.
  if ! $skip_services; then
    configure_services
  fi
  print_summary
}

main "$@"
