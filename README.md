# Alex's Arch + Hyprland Dots

These be my dots, intended for quick machine setups.

The `install.sh` script installs packages and performs the checks I usually do
on fresh systems. Also works as a full system updater / stow checker.

Interesting parts:
- Custom loop engineering agent files for opencode
- Local voice dictation scripts
- Pithy waybar and keybinded scripts

## Tools

TUI/CLI tools and scripts these dots ship, to remind me what is there:

- `nmtui` — NetworkManager's text menu; scan and join Wi-Fi interactively
  without remembering nmcli syntax: `nmtui` > "Activate a connection"
- `vicinae` — app launcher (Super+Space) that doubles as a Wi-Fi chooser when
  its network backend is `nmcli` (`"network-cli-tool": "nmcli"` in
  `~/.config/vicinae/settings.json`)
- `btop` — system monitor: CPU, RAM, disks, network
- `lazygit` — git in a TUI
- `bat` — a prettier `cat` (syntax highlighting, line numbers)
- `idle-pause.sh 15` — pause hypridle's lock/suspend for N minutes (15 = 15 min), auto-resumes; run from `~/.config/hypr/scripts/`
- `gitleaks` — secret scanner; the repo's pre-push hook (`.githooks/pre-push`) runs it on every push and blocks secrets from reaching GitHub unless you explicitly type `I understand` to override

## Fresh installation

### 0. Prepare a boot USB on another computer

Download the latest ISO from <https://archlinux.org/download/>. Verify it if you want!

Find the USB device path, for example `/dev/sdX`:
```bash
lsblk
```

"Disk Dump" the iso to it. Update these `if` and `of` flags.

```bash
sudo dd bs=4M if=archlinux-YYYY.MM.DD-x86_64.iso of=/dev/sdX conv=fsync oflag=direct status=progress
```

### 1. Install Arch

*Purist or the Arch wiki might say it's better to do the install yourself, but honestly the script has gotten very good!*

Boot the USB via BIOS. Try `F12` > `F11` > `ESC`> `F2` > `F8` > `F10`.

Connect to internet.
```bash
iwctl
device list                          # confirm your adapter, e.g. wlan0
station wlan0 scan                   # scan for networks
station wlan0 get-networks           # list them
station wlan0 connect "<SSID>"       # prompts for password
exit
```

`iwctl` is the client for `iwd`, and it only exists in this live-USB
environment. It is not installed on the finished system — after installation,
NetworkManager (with its default wpa_supplicant backend) takes over Wi-Fi.

Or check ethernet with `ip link`.

Now finally run archinstall script.

```bash
archinstall
```

Choices I like:

- **Locales:** `en_AU.UTF-8`
- **Mirrors:** `Australia`
- **Disk configuration:** `Btrfs`
- **Disk encryption:** For a sensitive or travelling laptop, enable Archinstall's
  LUKS encryption for the Linux filesystem and use a strong passphrase.
- **Swap:** 2–4 GiB swap file with zram and zstd compression
- **Bootloader:** `systemd-boot`, Grub if not available (UEFI related thing)
- **Kernels:** `Linux` by default, others are good depending on machine needs.
- **Hostname:** Machine name should be unique and sensible
- **Authentication:** No root password; make a sudo user instead. U2F for YubiKey if needed.
- **Profile:** `Minimal`. We want to set up a DE/WM later.
- **Applications:** Enable PipeWire. The dots installer will ask before enabling
  Bluetooth, printing, UFW, and other system services.
- **Network configuration:** `NetworkManager` (plain, not the "iwd backend"
  variant — NetworkManager's default wpa_supplicant backend is installed and
  enabled as a dependency, so choose the non-iwd option to avoid an idle,
  unused iwd daemon)

Reboot into the new system and sign in at the terminal.

### 2. Install the dots

Run this as your normal user, not root:

```bash
sudo pacman -Syu --needed git
git clone https://github.com/alexcampbelling/dots.git ~/dots
cd ~/dots
```

Choose the software you want, then run the matching command:

```bash
# System basics + Hyprland desktop
bash ./install.sh

# --skip-services skips service and boot-target setup
# --non-interactive accepts pacman and Yay confirmation prompts
# --profile adds a collection of optional packages

# Example work laptop set up
bash ./install.sh --profile code --non-interactive

# Example home desktop set up
bash ./install.sh --profile optional --profile local-whisper --profile code --non-interactive

# Example packages update, runs Pacman and AUR update in script
bash ./install.sh --non-interactive --skip-services
```

`--non-interactive` only accepts package-manager confirmation prompts.
Optional application and service choices still require input from a terminal.

`system` and `desktop` are always included. Profiles add optional groups:

- `system` - Arch, networking, recovery, and command-line essentials
- `desktop` - Hyprland and its everyday graphical applications, including
  Firefox, Text Editor, Okular and Aussie-English spell checking
- `optional` - Prompts for each home-machine application individually:
  Obsidian, Syncthing, Spotify, Steam, Vesktop, and RuneLite. Selecting Steam
  enables Arch's `[multilib]` repository when needed. Obsidian vaults are
  synchronised between personal machines with Syncthing.
- `code` - The open-source Arch `code` editor, databases, and common Python,
  Rust, and JavaScript/TypeScript tooling. If OpenCode is already installed
  separately, this also deploys its config and skills; it does **not** install
  OpenCode itself.
- `local-whisper` - Local Whisper backend. Download a compatible model separately to `~/.local/share/whisper-models/ggml-tiny.en-q5_1.bin`, or set `WHISPER_MODEL`

To inspect a plan without changing anything:

```bash
bash ./install.sh --profile optional --dry-run
```

The installer:
- Updates the system and installs packages from the selected profiles
- Installs Yay when AUR packages are required
- Deploys dotfiles to the home directory with Stow
- Enables the gitleaks pre-push hook (`.githooks/pre-push`) so git pushes are
  scanned for secrets before they reach GitHub
- Sets up Hyprland
- Sets the GNOME/GTK4 colour preference to dark for Text Editor and similar apps
- Automatically selects the SilentSDDM theme when safe to do so
- Asks before enabling NetworkManager, Bluetooth, UFW, CUPS, Avahi, Tailscale,
  or SDDM with graphical boot, explaining each system-wide change first
- When Syncthing is selected from the `optional` profile, also asks before
  enabling it for the logged-in user

### 3. Check hardware and monitors

Drivers are intentionally a manual choice. Check the computer first:

```bash
lscpu
lspci -k
```

Use the detected CPU and GPU to choose the right microcode and graphics/media
packages from current Arch documentation.

The installer creates `~/dots/hypr/.config/hypr/conf/monitors.conf` once and
never overwrites it. After first starting Hyprland, run:

```bash
hyprctl monitors
```

Use that output to update the local monitor file with the correct names,
resolutions, positions, and scales.

### 4. Finish setup

- Tailscale is installed with the `system` profile. If its service is enabled, join and authenticate it manually with `sudo tailscale up`.
- If Syncthing is selected from the `optional` profile and its user service is enabled, pair devices and folders through <http://127.0.0.1:8384>.
- Cloud Whisper is the default speech-to-text backend. To configure it, create a local key file without adding the key to shell history:

  ```bash
  CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  install -d -m 700 "$CONFIG_HOME/whisper"
  read -rsp 'Groq API key: ' GROQ_API_KEY; echo
  umask 077
  printf '%s\n' "$GROQ_API_KEY" > "$CONFIG_HOME/whisper/groq-key"
  unset GROQ_API_KEY
  chmod 600 "$CONFIG_HOME/whisper/groq-key"
  ```

Reboot and everything should be nice:

```bash
sudo systemctl reboot
```
