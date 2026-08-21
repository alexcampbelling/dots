# AGENTS.md — Dots repo agent instructions

This repo deploys dotfiles to `$HOME` with GNU Stow and manages package
selection through composable profiles. `install.sh` is the single source of
truth for how everything is installed and validated. Read it before changing
anything; keep `README.md` in sync with user-visible changes.

## Layout: stow packages

Each stow package is a top-level dir mirroring `$HOME` (e.g.
`hypr/.config/hypr/…`, `icons/.local/share/…`, or dotfiles like
`bash/.bash_aliases` directly). Only dirs listed in `STOW_PACKAGES` (top of
`install.sh`) are stowed: `stow --restow --no-folding --dir . --target $HOME`
after a `--simulate` preflight. `sddm-silent/` is NOT stowed — its own
`install.sh` writes a managed `/etc/sddm.conf.d/` drop-in.

Package map (one line each):

| Dir | What it is |
|---|---|
| `bash/` | `.bash_aliases` (source it from `~/.bashrc`) |
| `hypr/` | Hyprland + hypridle/lock/paper; `conf/*.conf` are `source`d by `hyprland.conf`; scripts in `scripts/` (incl. whisper dictation) |
| `waybar/` | Waybar config (`config.jsonc`, `style.css`, `modules.json`, scripts) |
| `dunst/`, `rofi/`, `kitty/`, `lazygit/`, `Thunar/`, `xfce4/`, `waypaper/` | Respective app configs |
| `vicinae/` | Launcher (Super+Space); Wi-Fi chooser via `network-cli-tool: nmcli` |
| `gtk-3.0/`, `fontconfig/`, `mimeapps.list/` | GTK settings, font config, default apps |
| `theme/` | `tokens.css` + `tokens.rasi` (shared colors) |
| `icons/` | AlexIcons icon theme (below) |
| `opencode/`, `agents/` | OpenCode config + skills; stowed ONLY for `--profile code` and only when `opencode` is installed (gated in `build_stow_plan`) |
| `assets/` | NOT stowed — wallpaper source; `wallpapers/pillars.jpg` is the default, `validate_repository_inputs` dies if missing |

Repo edits apply live through the symlinks (except icons and seeded files).

## Package profiles

Manifests: `packages/profiles/<profile>/pacman.txt` and `aur.txt` — one package
per line, `#` comments and blank lines allowed. `system` and `desktop` are
always resolved; `optional`, `code`, `local-whisper` are opt-in via
`--profile`. AUR entries already present in a pacman list are skipped.

- `system` — every machine (core system, networking, gitleaks, tailscale)
- `desktop` — every machine (Hyprland, apps, fonts)
- `optional` — home machines; every entry is offered as an individual y/n
  prompt during install
- `code` — dev tooling
- `local-whisper` — whisper-cpp

### Adding a package — ask the user first
1. Official repos or AUR?
2. Which profile — or a new one? (`optional` = individually prompted, not
   auto-installed.)
3. If adding to `system`/`desktop`, it lands on every machine — confirm.
4. Check `install.sh` for package-keyed side effects: `steam` → enables
   `[multilib]`; `syncthing` → extra user-service prompt; `rustup` → sets
   stable default toolchain; `typescript` → asserts no npm-managed `/usr/bin/tsc`.
5. Add to the right `.txt`, then update `README.md` if user-visible: keep it
   concise, match existing tone, and confirm wording with the user.

### Adding a new profile
Create `packages/profiles/<name>/{pacman,aur}.txt`, add the name to
`is_supported_profile()` and the `usage()` text in `install.sh`, and describe
it in `README.md`. Decide: CLI opt-in (default) or always-resolved (add to
`resolve_profiles()`). Add conditional stow packages in `build_stow_plan()`.

## install.sh architecture

Pipeline in `main()`: `parse_args` → `resolve_profiles` → `build_install_plan`
(reads manifests, dedupes AUR vs pacman) → `build_stow_plan` →
`validate_repository_inputs` → optional/service prompts → installs
(pacman `-Syu --needed`, yay installed on demand) → seeds state → stows →
hooks/GSettings/SDDM → services. Dry-run shares the whole planning path and
prints the plan without touching the machine.

Seeded, per-machine files (created once, never overwritten):
- `hypr/.config/hypr/conf/monitors.conf` — gitignored, seeded from
  `monitors.conf.example`; edit the example for defaults
- `~/wallpaper/pillars.jpg` — from `assets/wallpapers/pillars.jpg`
- `~/.config/whisper/` — chmod 700; keys are created manually (see README)

Services are enabled, never restarted, and each is explained in a prompt
unless `--skip-services`. SDDM theme install is skipped if `/etc/sddm.conf`
exists. Keep the dry-run output accurate when changing any of this.

## Icons (AlexIcons theme)

Overrides layered on Papirus:
`icons/.local/share/icons/AlexIcons/scalable/apps/<name>.svg`. One scalable SVG
covers all sizes; `index.theme` has `Inherits=Papirus`,
`Directories=scalable/apps` — keep both or inheritance breaks.

Change/add: copy from Papirus
(`cp /usr/share/icons/Papirus/<size>x<size>/apps/<name>.svg …/scalable/apps/`),
edit, then refresh: `systemctl --user restart dunst` and
`gtk-update-icon-cache ~/.local/share/icons/AlexIcons` (verify with
`notify-send -i <name> test` / `dunstctl history`).

Gotchas: never edit `/usr/share/icons/Papirus` (overwritten on updates);
`papirus-icon-theme` must be installed.

## Git hooks and secrets

`.githooks/pre-push` runs gitleaks on every push (blocks secrets unless
`GITLEAKS_FORCE=1` or typing "I understand"). `install.sh` sets
`core.hooksPath`. Never commit secrets: `.env`/`.env.*` and `monitors.conf`
are gitignored (`.env.example` is tracked).

## Skills (`agents/`)

OpenCode skills live in `agents/.agents/skills/<name>/SKILL.md`, stowed to
`~/.agents` only with `--profile code`. `AGENTS.md` itself is repo-root, not
stowed.

## Rules

- Validate with `bash -n install.sh` and `bash ./install.sh --dry-run` only.
  Never run a real install without explicit user approval.
- Confirm profile/package placement and README wording with the user.
- Don't commit unless asked.
