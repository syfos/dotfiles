########################################
# ~/.zshrc — Termux
########################################

# ---------- Basics ----------
export EDITOR=nvim
export VISUAL=nvim
alias n='nvim'

# ---------- Cargo ----------
export CARGO_HOME="$HOME/.cargo"
export CARGO_TARGET_DIR="$HOME/.cargo-target"   # single shared target dir, no per-project bloat
mkdir -p "$CARGO_TARGET_DIR"
export PATH="$CARGO_HOME/bin:$PATH"

# sccache, if installed, wraps rustc to reuse compilation cache across projects
if command -v sccache >/dev/null 2>&1; then
  export RUSTC_WRAPPER=sccache
fi

# ---------- eza (aliased to ls) ----------
if command -v eza >/dev/null 2>&1; then
  # -a: show hidden files, --icons, symlinks shown w/ target in long form, dirs first
  alias ls='eza -a --icons=always --group-directories-first'
  alias ll='eza -la --icons=always --group-directories-first'
  alias lt='eza -a --tree --level=2 --icons=always'
else
  echo "eza not found — install with: pkg install eza"
fi

# ---------- Termux theme switcher ----------
# Usage:
#   sw <name>            -> looks in ~/.termux/themes/<name> or <name>.properties
#   sw /path/to/file      -> uses that file directly
#   sw                    -> lists available themes
sw() {
  local theme_dir="$HOME/.termux/themes"
  local target="$HOME/.termux/colors.properties"
  local theme="$1"

  if [[ -z "$theme" ]]; then
    echo "Usage: sw <theme-name|path>"
    echo "Available themes in $theme_dir:"
    ls "$theme_dir" 2>/dev/null
    return 1
  fi

  local src=""
  if [[ -f "$theme" ]]; then
    src="$theme"
  elif [[ -f "$theme_dir/$theme" ]]; then
    src="$theme_dir/$theme"
  elif [[ -f "$theme_dir/$theme.properties" ]]; then
    src="$theme_dir/$theme.properties"
  fi

  if [[ -z "$src" ]]; then
    echo "Theme not found: $theme"
    return 1
  fi

  cp "$src" "$target" && termux-reload-settings \
    && echo "Switched theme -> $(basename "$src")"
}

# ---------- Plugin bootstrap (no plugin manager, plain git clone) ----------
ZSH_PLUGIN_DIR="$HOME/.zsh/plugins"
mkdir -p "$ZSH_PLUGIN_DIR"

_zsh_plugin_load() {
  local repo="$1" name="$2" entry="$3"
  local dir="$ZSH_PLUGIN_DIR/$name"
  if [[ ! -d "$dir" ]]; then
    echo "Cloning $name..."
    git clone --depth=1 "$repo" "$dir" 2>/dev/null
  fi
  [[ -f "$dir/$entry" ]] && source "$dir/$entry"
}

# 1. Auto-closing/pairing brackets & quotes
_zsh_plugin_load "https://github.com/hlissner/zsh-autopair" \
  "zsh-autopair" "autopair.zsh"

# 2. Prefix-filtered history (type e.g. `cargo`, press UP to cycle matches)
_zsh_plugin_load "https://github.com/zsh-users/zsh-history-substring-search" \
  "zsh-history-substring-search" "zsh-history-substring-search.zsh"

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# 3. Command / subcommand syntax highlighting (must load LAST)
_zsh_plugin_load "https://github.com/z-shell/F-Sy-H" \
  "fast-syntax-highlighting" "fast-syntax-highlighting.plugin.zsh"

# ---------- History behavior (needed for the substring-search UX) ----------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# ---------- Starship prompt ----------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  echo "starship not found — install with: pkg install starship"
fi

