# AGENTS.md — Dots repo agent instructions

This repo deploys dotfiles to `$HOME` with GNU Stow and manages package
selection through composable profiles. `install.sh` is the single source of
truth for how everything is installed and validated. Read it before changing
anything; keep `README.md` in sync with user-visible changes.

## Layout: stow packages

Each stow package is a top-level dir mirroring `$HOME` (e.g.
`hypr/.config/hypr/…`, `icons/.local/share/…`, or dotfiles like
`bash/.bash_aliases` directly). The package list is NOT hand-maintained: every
top-level dir is a stow package except the structural dirs in `STOW_EXCLUDE`
(`assets/`, `packages/`, `sddm-silent/`) and hidden dirs. `stow_plan_all()` in
`stow-plan.sh` derives the list from the filesystem, so adding a package means
dropping a new top-level dir — no list edit. `install.sh` and `restow.sh` both
source `stow-plan.sh`.

A package whose app may be absent on a machine lists its required command in
`STOW_REQUIRES` (`stow-plan.sh`). `restow.sh` skips such a package with a loud
warning when the command is missing; install it and rerun. `install.sh` stows
conditional packages only when their `--profile` is resolved AND the command
is present. `sddm-silent/` is NOT stowed — its own `install.sh` writes a
managed `/etc/sddm.conf.d/` drop-in.

Package map (one line each):

| Dir | What it is |
|---|---|
| `bash/` | `.bash_aliases` (source it from `~/.bashrc`) |
| `zsh/` | `.zshrc` — vanilla zsh; plugins auto-installed by the `ZPLUG` loader (below) |
| `hypr/` | Hyprland + hypridle/lock/paper; `conf/*.lua` are `require`d by `hyprland.lua` (Lua config, Hyprland ≥0.55); scripts in `scripts/` (incl. whisper dictation) |
| `waybar/` | Waybar config (`config.jsonc`, `style.css`, `modules.json`, scripts) |
| `dunst/`, `rofi/`, `kitty/`, `lazygit/`, `Thunar/`, `xfce4/`, `waypaper/` | Respective app configs |
| `vicinae/` | Launcher (Super+Space); Wi-Fi chooser via `network-cli-tool: nmcli` |
| `gtk-3.0/`, `fontconfig/`, `mimeapps.list/` | GTK settings, font config, default apps |
| `theme/` | `tokens.css` + `tokens.rasi` (shared colors) |
| `icons/` | AlexIcons icon theme (below) |
| `opencode/`, `agents/` | OpenCode config + skills; conditional via `STOW_REQUIRES` — skipped with a warning by `restow.sh` unless `opencode` is installed; `install.sh` stows them for `--profile code` when `opencode` is installed |
| `assets/` | NOT stowed — wallpaper source; `wallpapers/pillars.jpg` is the default, `validate_repository_inputs` dies if missing |

Repo edits apply live through the symlinks (except icons and seeded files).

### Zsh plugins (the `ZPLUG` loader)

`zsh/.zshrc` installs and loads its own plugins — no `install.sh`/`restow.sh`
involvement. Plugins are declared once in the `ZPLUG=( ... )` associative array
(`name -> GitHub URL`), auto-cloned into `~/.local/share/zsh` when missing, and
loaded in the order that matters: completion dirs are added to `fpath` before
`compinit`, runtime plugins are `source`d after it, and
`zsh-syntax-highlighting` is sourced last.

To add a plugin: (1) add its name + URL to `ZPLUG`, and (2) add a
`[[ -f … ]] && source …` line (or nothing for a completions-only plugin — `fpath`
handles it). Keep highlighting last. The loader clones but never updates; refresh
manually with `git -C ~/.local/share/zsh/<name> pull`.

## Restowing without installing

`restow.sh` re-links every stow package (from `stow-plan.sh`) without touching
packages, services, or seeded files. Packages whose required command is missing
are skipped with a warning. Run `bash ./restow.sh` (or `--dry-run`) to sync a
machine after pulling repo changes.

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
`resolve_profiles()`). Add conditional stow packages by editing `STOW_REQUIRES`
in `stow-plan.sh` (and `build_stow_plan()` for the profile gate).

## install.sh architecture

Pipeline in `main()`: `parse_args` → `resolve_profiles` → `build_install_plan`
(reads manifests, dedupes AUR vs pacman) → `build_stow_plan` →
`validate_repository_inputs` → optional/service prompts → installs
(pacman `-Syu --needed`, yay installed on demand) → seeds state → stows →
hooks/GSettings/SDDM → services. Dry-run shares the whole planning path and
prints the plan without touching the machine.

Per-machine Hyprland config is committed and keyed off the hostname:
`hypr/.config/hypr/conf/hosts.lua` reads `/etc/hostname`; `monitors.lua` and
`environment.lua` branch on it (see README).

Seeded, per-machine files (created once, never overwritten):
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
`core.hooksPath`. Never commit secrets: `.env`/`.env.*` are gitignored
(`.env.example` is tracked).

## Skills (`agents/`)

OpenCode skills live in `agents/.agents/skills/<name>/SKILL.md`, stowed to
`~/.agents` only with `--profile code`. `AGENTS.md` itself is repo-root, not
stowed.

## Rules

- Validate with `bash -n install.sh`, `bash -n restow.sh`, and
  `bash ./install.sh --dry-run` only. Never run a real install without explicit
  user approval.
- Confirm profile/package placement and README wording with the user.
- Don't commit unless asked.
