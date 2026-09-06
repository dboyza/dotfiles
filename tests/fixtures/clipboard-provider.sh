#!/usr/bin/env bash

set -euo pipefail
provider=${0##*/}
if [[ $provider == uname ]]; then
  case "$1" in
    -r) printf '%s\n' "${CLIPBOARD_TEST_KERNEL:-generic}" ;;
    -s) printf '%s\n' "${CLIPBOARD_TEST_SYSTEM:-Linux}" ;;
  esac
  exit
fi

printf '%s %s\n' "$provider" "$*" >>"$CLIPBOARD_TEST_LOG"
case "$provider $*" in
  'pbcopy ' | 'win-copy ' | 'wl-copy ' | 'xclip -selection clipboard' | 'xsel --clipboard --input' | 'tmux load-buffer -')
    cat >"$CLIPBOARD_TEST_FILE"
    ;;
  'pbpaste ' | 'win-paste ' | 'wl-paste --no-newline' | 'xclip -selection clipboard -out' | 'xsel --clipboard --output' | 'tmux save-buffer -')
    [[ ${CLIPBOARD_TEST_FAIL_PASTE:-0} == 0 ]] || exit 1
    cat "$CLIPBOARD_TEST_FILE"
    ;;
  *)
    printf 'Unexpected provider invocation: %s %s\n' "$provider" "$*" >&2
    exit 2
    ;;
esac
