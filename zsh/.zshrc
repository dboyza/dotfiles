# PATH
path_prepend() {
  [ -d "$1" ] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.opencode/bin"
unfunction path_prepend
export PATH

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt append_history share_history hist_ignore_dups hist_ignore_space hist_reduce_blanks

# Completion
mkdir -p "$HOME/.cache/zsh"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache"
for completion_dir in /usr/share/zsh/vendor-completions; do
  [ -d "$completion_dir" ] || continue
  for completion_file in "$completion_dir"/_*(N); do
    if [ ! -r "$completion_file" ]; then
      fpath=("${(@)fpath:#$completion_dir}")
      break
    fi
  done
done
unset completion_dir completion_file
autoload -Uz compinit
compinit -d "$HOME/.cache/zsh/zcompdump"
zstyle ':completion:*' menu select

# Keys
bindkey -e
export KEYTIMEOUT=1
bindkey $'\e[1;5D' backward-word
bindkey $'\e[1;5C' forward-word
bindkey $'\e[5D' backward-word
bindkey $'\e[5C' forward-word

# Aliases shared from Bash, if compatible.
[ -f "$HOME/.bash_aliases" ] && source "$HOME/.bash_aliases"

# ls aliases
case $(uname -s 2>/dev/null) in
  Darwin*) alias ls='ls -G' ;;
  *) alias ls='ls --color=auto' ;;
esac
alias ll="ls -alF"
alias la="ls -la"
alias l="ls -CF"
alias k="kubectl"

# tmux aliases
alias tns="tmux new-session -s"
alias ta="tmux attach"
alias tat="tmux attach -t"

# batcat
if command -v batcat >/dev/null 2>&1; then
  alias cat="batcat --plain --paging=never"
elif command -v bat >/dev/null 2>&1; then
  alias cat="bat --plain --paging=never"
fi

# Ghost suggestions and command highlighting.
ZSH_AUTOSUGGEST_USE_ASYNC=true
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=80
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
source_first() { local plugin; for plugin in "$@"; do [ -r "$plugin" ] && source "$plugin" && return; done; }
source_first \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source_first \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
unfunction source_first

# Prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
