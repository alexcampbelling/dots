
. "$HOME/.cargo/env"

# PATH — same additions ~/.bashrc makes for bash
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# --- plugins: one list, auto-installed into ~/.local/share/zsh ---
typeset -gA ZPLUG
ZPLUG=(
  zsh-autopair                 https://github.com/hlissner/zsh-autopair
  zsh-autosuggestions          https://github.com/zsh-users/zsh-autosuggestions
  zsh-completions              https://github.com/zsh-users/zsh-completions
  zsh-history-substring-search https://github.com/zsh-users/zsh-history-substring-search
  zsh-syntax-highlighting      https://github.com/zsh-users/zsh-syntax-highlighting
  zsh-you-should-use           https://github.com/MichaelAquilina/zsh-you-should-use
  zsh-z                        https://github.com/agkozak/zsh-z
)
ZPLUG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"

# 1) clone any missing plugin, and put completion dirs on fpath BEFORE compinit
for name url in "${(@kv)ZPLUG}"; do
  dir="$ZPLUG_DIR/$name"
  if [[ ! -d "$dir/.git" ]]; then
    print -r -- "zsh: installing plugin $name"
    git clone --depth 1 "$url" "$dir" || { rm -rf "$dir"; print -ru2 -- "zsh: failed to install $name (offline?)"; }
  fi
  fpath+=("$dir/src")
done

autoload -Uz compinit && compinit

# 2) source runtime plugins — syntax-highlighting is sourced last (below)
[[ -f "$ZPLUG_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] \
  && source "$ZPLUG_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$ZPLUG_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh" ]] \
  && source "$ZPLUG_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh"
[[ -f "$ZPLUG_DIR/zsh-z/zsh-z.plugin.zsh" ]] \
  && source "$ZPLUG_DIR/zsh-z/zsh-z.plugin.zsh"
[[ -f "$ZPLUG_DIR/zsh-autopair/autopair.zsh" ]] \
  && source "$ZPLUG_DIR/zsh-autopair/autopair.zsh"
[[ -f "$ZPLUG_DIR/zsh-you-should-use/you-should-use.plugin.zsh" ]] \
  && source "$ZPLUG_DIR/zsh-you-should-use/you-should-use.plugin.zsh"

# --- built-in goodies ---
setopt autocd
setopt extendedglob

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt share_history
setopt inc_append_history
setopt hist_ignore_all_dups
setopt hist_ignore_space

setopt COMPLETE_IN_WORD
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# --- aliases ---
alias la='ls -a'
alias ll='ls -la'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -c'

# --- prompt ---
PROMPT='%F{47}%n%F{156}@%F{227}%m %F{231}%1~ > %f'

# --- syntax highlighting LAST ---
[[ -f "$ZPLUG_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] \
  && source "$ZPLUG_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
