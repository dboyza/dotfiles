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
path_prepend "/etc/profiles/per-user/$USER/bin"
path_prepend "$HOME/.nix-profile/bin"
unfunction path_prepend
export PATH

for hm_session_vars in \
  "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" \
  "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"; do
  if [ -r "$hm_session_vars" ]; then
    source "$hm_session_vars"
    break
  fi
done
unset hm_session_vars

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

select-backward-word() {
  (( REGION_ACTIVE )) || zle set-mark-command
  zle backward-word
}

select-forward-word() {
  (( REGION_ACTIVE )) || zle set-mark-command
  zle forward-word
}

select-backward-character() {
  (( REGION_ACTIVE )) || zle set-mark-command
  zle backward-char
}

select-forward-character() {
  (( REGION_ACTIVE )) || zle set-mark-command
  zle forward-char
}

copy-selected-region() {
  (( REGION_ACTIVE )) || return
  zle copy-region-as-kill

  if (( $+commands[pbcopy] )); then
    print -rn -- "$CUTBUFFER" | pbcopy || return
  elif (( $+commands[win-copy] )); then
    print -rn -- "$CUTBUFFER" | win-copy || return
  elif (( $+commands[wl-copy] )); then
    print -rn -- "$CUTBUFFER" | wl-copy || return
  else
    zle -M 'No system clipboard provider found'
    return 1
  fi

  REGION_ACTIVE=0
  CURSOR=${#BUFFER}
  zle redisplay
}

zle -N select-backward-word
zle -N select-forward-word
zle -N select-backward-character
zle -N select-forward-character
zle -N copy-selected-region
bindkey $'\e[1;2D' select-backward-character
bindkey $'\e[1;2C' select-forward-character
bindkey $'\e[2D' select-backward-character
bindkey $'\e[2C' select-forward-character
bindkey $'\e[1;6D' select-backward-word
bindkey $'\e[1;6C' select-forward-word
bindkey $'\e[6D' select-backward-word
bindkey $'\e[6C' select-forward-word
bindkey $'\e[99;6u' copy-selected-region

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

# Ghost suggestions and command highlighting.
ZSH_AUTOSUGGEST_USE_ASYNC=true
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=80
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
source_first() { local plugin; for plugin in "$@"; do [ -r "$plugin" ] && source "$plugin" && return; done; }
source_first \
  "$HOME/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/etc/profiles/per-user/$USER/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source_first \
  "$HOME/.nix-profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/etc/profiles/per-user/$USER/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
unfunction source_first

# Prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
