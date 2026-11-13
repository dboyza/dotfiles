#!/usr/bin/env bash
# Claude Code status line: model, effort/thinking, current folder, context used, 5-hour and 7-day usage limits.
input=$(cat)

# Section: Session fields from Claude Code's JSON payload
model=$(jq -r '.model.display_name // .model.id // "?"' <<<"$input")
effort=$(jq -r '.effort.level // empty' <<<"$input")
thinking=$(jq -r 'if .thinking.enabled == false then "off" elif .thinking.enabled == true then "on" else empty end' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
folder=$(basename "${dir:-$PWD}")
ctx=$(jq -r '.context_window.used_percentage // empty | round' <<<"$input")
five=$(jq -r '.rate_limits.five_hour.used_percentage // empty | round' <<<"$input")
week=$(jq -r '.rate_limits.seven_day.used_percentage // empty | round' <<<"$input")

# Section: Usage coloring
# Green below 50%, yellow below 80%, red from 80%.
color() {
  if (( $1 >= 80 )); then printf '\033[31m'
  elif (( $1 >= 50 )); then printf '\033[33m'
  else printf '\033[32m'; fi
}

limit() {
  if [[ -n $2 ]]; then
    printf '%s %s%s%%\033[0m' "$1" "$(color "$2")" "$2"
  else
    printf '%s --' "$1"
  fi
}

# Section: Rendered line
# Effort level when the model supports it, otherwise whether thinking is on.
if [[ -n $effort ]]; then
  mode="$effort"
  [[ $thinking == off ]] && mode+=", thinking off"
elif [[ -n $thinking ]]; then
  mode="thinking $thinking"
else
  mode="--"
fi

printf '\033[36m%s\033[0m \033[2m|\033[0m \033[35m%s\033[0m \033[2m|\033[0m \033[34m%s\033[0m \033[2m|\033[0m %s \033[2m|\033[0m %s \033[2m|\033[0m %s' \
  "$model" "$mode" "$folder" "$(limit ctx "$ctx")" "$(limit 5h "$five")" "$(limit 7d "$week")"
