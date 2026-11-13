#!/usr/bin/env bash
# Render the Claude Code status line from sample payloads and compare the visible text.

set -Eeuo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf 'Claude status line test skipped because jq is unavailable\n'
  exit 78
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
escape=$(printf '\033')

# Section: Rendering helpers
render() {
  bash "$repo_dir/claude/statusline.sh" <<<"$1"
}

expect() {
  local name=$1 expected=$2 actual
  actual=$(render "$3" | sed "s/${escape}\[[0-9;]*m//g")
  if [[ $actual != "$expected" ]]; then
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual"
    exit 1
  fi
}

# Section: Visible text
expect 'full payload' 'Fable 5.2 | high | dotfiles | ctx 42% | 5h 7% | 7d 81%' '{
  "model": {"display_name": "Fable 5.2", "id": "claude-fable-5-2"},
  "effort": {"level": "high"},
  "thinking": {"enabled": true},
  "workspace": {"current_dir": "/home/user/code/dotfiles"},
  "context_window": {"used_percentage": 41.6},
  "rate_limits": {"five_hour": {"used_percentage": 7.2}, "seven_day": {"used_percentage": 80.5}}
}'
expect 'effort with thinking off' 'model-id | medium, thinking off | work | ctx 5% | 5h -- | 7d --' '{
  "model": {"id": "model-id"},
  "effort": {"level": "medium"},
  "thinking": {"enabled": false},
  "cwd": "/tmp/work",
  "context_window": {"used_percentage": 5}
}'
expect 'thinking without effort' 'Model | thinking on | work | ctx -- | 5h -- | 7d --' '{
  "model": {"display_name": "Model"},
  "thinking": {"enabled": true},
  "cwd": "/tmp/work"
}'
expect 'empty payload' "? | -- | $(basename "$PWD") | ctx -- | 5h -- | 7d --" '{}'

# Section: Usage colors
# Green below 50%, yellow below 80%, red from 80%.
colors=$(render '{
  "context_window": {"used_percentage": 49},
  "rate_limits": {"five_hour": {"used_percentage": 50}, "seven_day": {"used_percentage": 80}}
}')
for wanted in "ctx ${escape}[32m49%" "5h ${escape}[33m50%" "7d ${escape}[31m80%"; do
  if [[ $colors != *"$wanted"* ]]; then
    printf 'FAIL usage colors: missing %q\n' "$wanted"
    exit 1
  fi
done

printf 'Claude status line renders every field, fallback, and usage color\n'
