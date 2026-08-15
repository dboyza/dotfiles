#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-wsl-clipboard.XXXXXX")
cleanup() {
  local status=$?
  rm -rf "$test_dir"
  exit "$status"
}
trap cleanup EXIT

fake_bin="$test_dir/bin"
clipboard="$test_dir/clipboard"
mkdir -p "$fake_bin"

cat >"$fake_bin/wslpath" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -w ]]; then
  printf '%s\n' "$2"
else
  exit 2
fi
EOF

cat >"$fake_bin/powershell.exe" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${WIN_COPY_PATH:-}" ]]; then
  cp "$WIN_COPY_PATH" "$WSL_CLIPBOARD_TEST_FILE"
elif [[ -f "$WSL_CLIPBOARD_TEST_FILE" ]]; then
  cat "$WSL_CLIPBOARD_TEST_FILE"
fi
EOF

chmod +x "$fake_bin/wslpath" "$fake_bin/powershell.exe"

export PATH="$fake_bin:$PATH"
export WSL_CLIPBOARD_TEST_FILE="$clipboard"

sample="$test_dir/sample"
round_trip="$test_dir/round-trip"
printf 'héllo 🌙\r\nsecond line without a trailing newline' >"$sample"

"$repo_dir/scripts/win-copy" <"$sample"
"$repo_dir/scripts/win-paste" >"$round_trip"
cmp "$sample" "$round_trip"

: >"$sample"
"$repo_dir/scripts/win-copy" <"$sample"
"$repo_dir/scripts/win-paste" >"$round_trip"
test ! -s "$round_trip"

printf 'WSL UTF-8 clipboard round trip passed\n'
