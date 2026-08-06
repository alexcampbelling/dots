# bash

Custom shell aliases managed via GNU stow.

## Setup

1. Stow this directory to create the symlink:
   ```bash
   stow -t ~ bash
   ```
   This creates `~/.bash_aliases -> ~/dots/bash/.bash_aliases`

2. Ensure your `~/.bashrc` sources it by adding this line:
   ```bash
   [ -f ~/.bash_aliases ] && source ~/.bash_aliases
   ```

3. Reload your shell or run `source ~/.bashrc`

## Adding aliases

Edit `~/.bash_aliases` (or `~/dots/bash/.bash_aliases`) and reload.
