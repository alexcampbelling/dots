# Create a Fresh Public Repository

This guide turns the existing private repository into a read-only archive,
creates a new public `alexcampbelling/dots` repository with one commit and no
old Git history, and moves the desktop and laptop to the new repository.

The fresh repository intentionally has no license. Its files are publicly
visible, but no general permission to reuse them is granted.

## Overview

1. Finalize and push `main` in the private repository.
2. Rename the private GitHub repository to `dots-private-archive`.
3. Export only the final files and create a one-commit public repository.
4. Move this desktop (`pcarch`) to the fresh repository.
5. Repeat the shorter migration procedure on the laptop.

Do not pull the fresh repository into an old clone. Their histories are
unrelated.

## 1. Finalize the private repository

The final public files must be committed to `main` before creating the export.

```bash
cd ~/dots
git status --short
git fetch origin
git switch main
git merge --ff-only feature/public-work
git push origin main
```

Before continuing, confirm that the working tree is clean, `main` matches
GitHub, and the installer still passes its non-destructive checks:

```bash
git status --short
git rev-list --left-right --count main...origin/main
bash -n install.sh
bash ./install.sh --profile optional --profile code --dry-run
```

Expected results:

- `git status --short` prints nothing.
- `git rev-list` prints `0  0`.
- Both installer checks succeed.

## 2. Turn the current GitHub repository into a private archive

Rename the repository on GitHub:

```bash
gh repo rename -R alexcampbelling/dots dots-private-archive
```

Immediately point this desktop's old clone at the renamed repository. This
prevents it from accidentally pushing old history to the new public repository
when the `dots` name is reused.

```bash
git -C ~/dots remote set-url origin \
  https://github.com/alexcampbelling/dots-private-archive.git
git -C ~/dots remote -v
```

Before continuing, run the same safety change on the laptop if it is available:

```bash
git -C ~/dots remote set-url origin \
  https://github.com/alexcampbelling/dots-private-archive.git
git -C ~/dots remote -v
```

The laptop does not need to be fully migrated yet. If it is unavailable, do not
fetch, pull, or push from its old clone until its remote has been changed with
the command above. In particular, never push `--all` from an old clone.

Archive it on GitHub so it becomes read-only:

```bash
gh repo archive alexcampbelling/dots-private-archive --yes
gh repo view alexcampbelling/dots-private-archive \
  --json nameWithOwner,visibility,isArchived,url
```

Confirm that it reports `"visibility":"PRIVATE"` and
`"isArchived":true`.

## 3. Create the fresh public repository

### Export the final files

`git archive` copies the files in the final `main` commit without copying
`.git`, old commits, branches, tags, ignored files, or the local monitor layout.

First confirm that the destination does not already exist:

```bash
test ! -e ~/dots-public && test ! -L ~/dots-public
```

Stop if that command fails. Do not reuse an existing directory.

Create the clean export:

```bash
cd ~/dots
mkdir ~/dots-public
git archive --format=tar main | tar -xf - -C ~/dots-public

cd ~/dots-public
git init -b main
git add .
git diff --cached --check
git status --short
```

Review the complete staged file list printed by `git status`. These are the
only files that will become public. Confirm that it contains no credentials,
`.env` files, `monitors.conf`, machine backups, or other private files.

Check the public commit identity:

```bash
git config user.name
git config user.email
```

The displayed name and email will be public. Set a local GitHub no-reply email
before committing if necessary.

Create the root commit and verify that it is the only commit and branch:

```bash
git commit -m "Initial public dotfiles"
git rev-list --all --count
git for-each-ref --format='%(refname)' refs/heads refs/tags
```

Expected results:

- The commit count is `1`.
- The only ref printed is `refs/heads/main`.

### Create and configure the empty public repository

```bash
gh repo create alexcampbelling/dots \
  --public \
  --description "Arch Linux and Hyprland dotfiles"

gh repo edit alexcampbelling/dots \
  --add-topic arch-linux \
  --add-topic dotfiles \
  --add-topic hyprland \
  --add-topic wayland \
  --enable-issues \
  --enable-wiki=false \
  --enable-projects=false \
  --enable-discussions=false \
  --enable-secret-scanning \
  --enable-secret-scanning-push-protection
```

The repository is empty at this point, so no files or history have been
published. GitHub push protection is enabled before the first push.

### Push the one-commit repository

```bash
cd ~/dots-public
git remote add origin https://github.com/alexcampbelling/dots.git
git push -u origin main
```

No license is added. Verify the result and configured repository settings:

```bash
git rev-list --all --count
git ls-files 'LICENSE*' 'COPYING*'
git remote -v
gh repo view alexcampbelling/dots \
  --json nameWithOwner,visibility,defaultBranchRef,url
gh api repos/alexcampbelling/dots --jq \
  '{has_issues, has_wiki, has_projects, topics, security_and_analysis}'
```

Confirm that the commit count is still `1`, the repository is public, and its
default branch is `main`. The license command should print nothing. Open the
repository on GitHub and inspect its file list, commit history, topics, and
security settings before continuing.

## 4. Move this desktop to the fresh repository

The current computer is `pcarch`. The clean repository already exists locally
at `~/dots-public`, so it can replace the old clone without another download.

### Preserve local files

Inspect tracked, untracked, and ignored files in the old clone:

```bash
git -C ~/dots status --short --untracked-files=all
git -C ~/dots status --short --ignored
```

The complete old clone will remain available at `~/dots-private-archive`.
Separately back up anything else that should survive.

Save the local monitor layout:

```bash
test ! -e ~/monitors.conf.migration-backup && \
  test ! -L ~/monitors.conf.migration-backup

cp ~/dots/hypr/.config/hypr/conf/monitors.conf \
  ~/monitors.conf.migration-backup
```

Stop if the first command fails rather than overwriting an existing backup.

### Replace the clone

Confirm that the local archive path is unused:

```bash
test ! -e ~/dots-private-archive && test ! -L ~/dots-private-archive
```

Stop if that command fails. Then switch the two repositories:

```bash
mv ~/dots ~/dots-private-archive
mv ~/dots-public ~/dots

install -m 644 ~/monitors.conf.migration-backup \
  ~/dots/hypr/.config/hypr/conf/monitors.conf
```

Existing Stow links contain the path `~/dots`, so links for retained
configuration now resolve into the fresh clone. Run the desktop installer to
restow all currently managed configuration:

```bash
cd ~/dots
bash ./install.sh \
  --profile optional \
  --profile local-whisper \
  --profile code \
  --non-interactive
```

Optional application and service choices still require terminal input. Reboot
after installation:

```bash
sudo systemctl reboot
```

After rebooting, verify Hyprland, monitors, Waybar, terminal, launcher, audio,
network, and selected services. Keep `~/dots-private-archive` and the monitor
backup until everything works.

## 5. Move the laptop to the fresh repository

Run these steps on the laptop.

### Preserve its local state

Confirm that the old clone points at the private archive. If the safety step in
part 2 was not run on this laptop, change it now **before any other Git
command**:

```bash
git -C ~/dots remote set-url origin \
  https://github.com/alexcampbelling/dots-private-archive.git
git -C ~/dots remote -v
```

Inspect local files:

```bash
git -C ~/dots status --short --untracked-files=all
git -C ~/dots status --short --ignored
```

Save the monitor layout. This supports both repository layouts:

```bash
test ! -e ~/monitors.conf.migration-backup && \
  test ! -L ~/monitors.conf.migration-backup

if [[ -f ~/dots/hypr/.config/hypr/conf/monitors.conf ]]; then
  cp ~/dots/hypr/.config/hypr/conf/monitors.conf \
    ~/monitors.conf.migration-backup
else
  cp ~/dots/hypr/.config/hypr/conf/hosts/current/monitors.conf \
    ~/monitors.conf.migration-backup
fi
```

Stop if the first command fails. Back up any other local files that should
survive.

### Clone and switch

Confirm that both temporary paths are unused:

```bash
test ! -e ~/dots-public && test ! -L ~/dots-public
test ! -e ~/dots-private-archive && test ! -L ~/dots-private-archive
```

Clone and verify the fresh repository before moving the working clone:

```bash
git clone https://github.com/alexcampbelling/dots.git ~/dots-public
git -C ~/dots-public rev-list --all --count
```

The commit count must be `1`. Then replace the clone and restore the monitor
layout:

```bash
mv ~/dots ~/dots-private-archive
mv ~/dots-public ~/dots

install -m 644 ~/monitors.conf.migration-backup \
  ~/dots/hypr/.config/hypr/conf/monitors.conf
```

Run the laptop installer:

```bash
cd ~/dots
bash ./install.sh --profile code --non-interactive
sudo systemctl reboot
```

Service choices still require terminal input.

## 6. Final checks and cleanup

On each machine, check for dangling configuration links left by packages that
the public repository no longer contains, notably the old `nvim` and `wal`
packages:

```bash
find ~/.config -xtype l -print
```

Inspect anything printed. Recover a configuration from
`~/dots-private-archive` if it is still needed, or remove only a confirmed stale
link.

Once each machine has been working normally, the following backups are no
longer required:

- `~/dots-private-archive`
- `~/monitors.conf.migration-backup`

Remove them deliberately only after confirming they contain no unique local
changes, ignored files, branches, commits, or stashes. Keep the GitHub
`dots-private-archive` repository private and archived for as long as the old
history is needed.
