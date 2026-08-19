########################################
# ~/.zshrc — Termux
########################################

# ---------- Basics ----------
export EDITOR=nvim
export VISUAL=nvim
alias n='nvim'

# ---------- Esc -> edit current line in nvim (no modal editing) ----------
# Standard emacs-style zle keymap stays active (no `bindkey -v`), so all
# normal C-a/C-e/C-w/arrows/backspace behavior "just works" with zsh's
# built-in defaults — nothing below needs to special-case vi quirks anymore.
#
# KEYTIMEOUT is in hundredths of a second: how long zle waits after ESC to
# see if more bytes are coming before deciding "that was just Esc". Esc is
# also the first byte of every arrow/function-key escape sequence (ESC [ D,
# etc.), so this window is what lets zle tell a lone Esc press apart from
# the start of one of those sequences. 20 (200ms) is enough headroom for
# Termux (soft keyboard / bluetooth / any ssh hop) to deliver the rest of a
# sequence, while still feeling immediate for a plain Esc tap.
export KEYTIMEOUT=20

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line   # readline-standard alternate binding
bindkey '\e' edit-command-line     # plain Esc -> open the current prompt buffer in nvim

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
  # ls: hidden files + dirs + files, tabular/grid layout (eza's default
  # view when not in -l mode), symlinks excluded entirely via --no-symlinks.
  alias ls='eza -a --icons=always --group-directories-first --no-symlinks'
  # ll: long format, includes symlinks (shown as-is, with -> target, not
  # dereferenced).
  alias ll='eza -la --icons=always --group-directories-first'
  # lz: long format, symlinks included AND dereferenced (-X/--dereference)
  # so you see the real target's type/size/perms instead of the link itself.
  alias lz='eza -la --icons=always --group-directories-first -X'
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

# Empty string = no highlight at all (no bg, no fg change) on match/no-match
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND=''
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND=''

# Bind both CSI (^[[A) and SS3/application-mode (^[OA) sequences —
# Termux emits either depending on session state, so bind both to be safe.
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

# 3. Inline ghost-text suggestions (history + path/completion based)
autoload -Uz compinit
compinit -u -d "$HOME/.zcompdump"

# ---------- Completion behavior ----------
# compinit alone only gives bare completion (list or beep-on-ambiguous).
# These styles feed candidates/colors into fzf-tab below, which is what
# actually renders the TAB dropdown.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive matching
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # fzf-tab colorizes candidates from this
zstyle ':completion:*' use-cache on             # cache completion results across invocations...
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"   # ...doesn't help git's file-status list (that
                                                        # has to be live) but speeds up things like
                                                        # branch/tag/ref completion that git supports caching for
zstyle ':completion:*' menu no                  # let fzf-tab drive selection instead of zsh's own menu
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
setopt ALWAYS_TO_END    # move cursor to end of word after an accepted completion
setopt COMPLETE_IN_WORD # allow completing from the middle of a word

# fzf-tab: replaces zsh's own (synchronous, full-grid) completion menu with
# fzf's lazy fuzzy filtering — this is what actually closes the gap with
# fish's snappiness, especially for heavy completers like git's.
# Requires fzf itself: pkg install fzf
# Must load after compinit but before widget-wrapping plugins (autosuggestions,
# syntax highlighting) below.
_zsh_plugin_load "https://github.com/Aloxaf/fzf-tab" \
  "fzf-tab" "fzf-tab.plugin.zsh"

zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -a --icons=always --color=always $realpath'
zstyle ':fzf-tab:complete:(git-add|git-diff|git-restore):*' fzf-preview 'git diff --color=always -- $word'
zstyle ':fzf-tab:*' switch-group '<' '>'

_zsh_plugin_load "https://github.com/zsh-users/zsh-autosuggestions" \
  "zsh-autosuggestions" "zsh-autosuggestions.zsh"

# Try history first; if nothing matches, fall back to completion (e.g. paths)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'   # dim grey ghost text, no bg
ZSH_AUTOSUGGEST_USE_ASYNC=1

# Accept: -> (right arrow) or End accepts the full suggestion if one is
# showing; otherwise falls back to normal cursor movement.
_accept_suggestion_or_forward() {
  if [[ -n $POSTDISPLAY ]]; then
    zle autosuggest-accept
  else
    zle forward-char
  fi
}
zle -N _accept_suggestion_or_forward
bindkey '^[[C' _accept_suggestion_or_forward
bindkey '^[OC' _accept_suggestion_or_forward

_accept_suggestion_or_eol() {
  if [[ -n $POSTDISPLAY ]]; then
    zle autosuggest-accept
  else
    zle end-of-line
  fi
}
zle -N _accept_suggestion_or_eol
bindkey '^[[F' _accept_suggestion_or_eol
bindkey '^[OF' _accept_suggestion_or_eol

# ^F still accepts one word at a time
bindkey '^F' forward-word

# 4. Command / subcommand syntax highlighting (must load LAST — after
#    autosuggestions, or the ghost text can get miscolored)
_zsh_plugin_load "https://github.com/z-shell/F-Sy-H" \
  "fast-syntax-highlighting" "F-Sy-H.plugin.zsh"

# ---------- History behavior (needed for the substring-search UX) ----------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# ---------- Dot motions (cd shortcuts) ----------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'          # jump to previous dir

# ---------- Quick aliases ----------
alias cl='clear'
alias ex='exit'

# ---------- zoxide (smarter cd, aliased to z; also replaces cd) ----------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd z)"
  eval "$(zoxide init zsh --cmd cd)"
else
  echo "zoxide not found — install with: pkg install zoxide"
fi

# ---------- Starship prompt ----------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  echo "starship not found — install with: pkg install starship"
fi

