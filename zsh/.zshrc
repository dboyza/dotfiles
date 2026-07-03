# PATH
export PATH="$HOME/.local/bin:$PATH"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt append_history share_history hist_ignore_dups hist_reduce_blanks

# Completion
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select

# Keys
bindkey -e
bindkey $'\e[1;5D' backward-word
bindkey $'\e[1;5C' forward-word
bindkey $'\e[5D' backward-word
bindkey $'\e[5C' forward-word
# Aliases shared from Bash, if compatible.
[ -f "$HOME/.bash_aliases" ] && source "$HOME/.bash_aliases"

# ls aliases

alias ls='ls --color=auto'

alias ll="ls -alF"
alias la="ls -la"
alias l="ls -CF"
alias k="kubectl"

# Ghost suggestions and command highlighting.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
# opencode
export PATH=/home/dylan/.opencode/bin:$PATH
