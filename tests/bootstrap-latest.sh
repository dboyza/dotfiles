#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
real_grep=$(type -P grep)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap-test.XXXXXX")
cleanup() {
  local status=$?
  rm -rf "$test_dir"
  exit "$status"
}
trap cleanup EXIT

fake_bin="$test_dir/bin"
fake_home="$test_dir/home"
generation="$test_dir/generation"
mkdir -p "$fake_bin" "$fake_home" "$generation"

cat >"$fake_bin/nix" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BOOTSTRAP_TEST_NIX_LOG"
if [[ " $* " == *" build "* ]]; then
  printf '%s\n' "$BOOTSTRAP_TEST_GENERATION"
elif [[ " $* " == *" run "* ]]; then
  "$BOOTSTRAP_TEST_GENERATION/activate"
fi
EOF

cat >"$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf '%s\n' "${BOOTSTRAP_TEST_OS:-Linux}" ;;
  -m) printf 'x86_64\n' ;;
  *) printf '%s\n' "${BOOTSTRAP_TEST_OS:-Linux}" ;;
esac
EOF

cat >"$fake_bin/grep" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *"microsoft /proc/sys/kernel/osrelease"* ]]; then
  exit 1
fi
exec "$BOOTSTRAP_TEST_GREP" "$@"
EOF

cat >"$fake_bin/getent" <<'EOF'
#!/usr/bin/env bash
printf 'test:x:1000:1000:test:/tmp:/usr/bin/zsh\n'
EOF

cat >"$generation/activate" <<'EOF'
#!/usr/bin/env bash
touch "$BOOTSTRAP_TEST_ACTIVATED"

while IFS= read -r target; do
  mkdir -p "$(dirname "$target")"
  ln -sfn "/nix/store/bootstrap-test-$(basename "$target")" "$target"
done <<LINKS
$HOME/.zshrc
$HOME/.zshenv
$HOME/.tmux.conf
$HOME/.wezterm.lua
$HOME/.config/herdr/config.toml
$HOME/.config/nvim
$HOME/.config/starship.toml
$HOME/.codex/AGENTS.md
$HOME/.claude/CLAUDE.md
$HOME/.config/opencode/AGENTS.md
$HOME/.pi/agent/AGENTS.md
$HOME/.agents/skills
$HOME/.pi/agent/models.json
$HOME/.pi/agent/extensions
$HOME/.pi/agent/themes
$HOME/.tmux/plugins/tpm
$HOME/.tmux/plugins/tmux-yank
$HOME/.tmux/plugins/tmux-resurrect
$HOME/.tmux/plugins/tmux-continuum
$HOME/.tmux/plugins/tmux-assistant-resurrect
LINKS

mkdir -p "$HOME/.pi/agent"
printf '{}\n' >"$HOME/.pi/agent/settings.json"
EOF

cat >"$fake_bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF

cat >"$fake_bin/pi" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == --version ]]; then
  printf '0.82.0\n'
fi
EOF

cat >"$fake_bin/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" show-options -gv prefix "* ]]; then
  printf 'C-g\n'
elif [[ " $* " == *" list-keys -T prefix C-a "* ]]; then
  exit 1
fi
EOF

cat >"$fake_bin/PlistBuddy" <<'EOF'
#!/usr/bin/env bash
printf 'false\n'
EOF

cat >"$fake_bin/jq" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$fake_bin/noop" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
output=
while (($#)); do
  if [[ "$1" == -o ]]; then
    output=$2
    shift 2
  else
    shift
  fi
done

cat >"$output" <<'INSTALLER'
#!/usr/bin/env bash
if [[ -n "${NONINTERACTIVE:-}" ]]; then
  printf 'homebrew test: installer unexpectedly ran non-interactively\n' >&2
  exit 1
fi
touch "$BOOTSTRAP_TEST_HOMEBREW_INSTALLED"
ln -s "$BOOTSTRAP_TEST_NOOP" "$BOOTSTRAP_HOMEBREW"
INSTALLER
EOF

chmod +x "$fake_bin/nix" "$fake_bin/uname" "$fake_bin/grep" "$fake_bin/getent" "$fake_bin/sudo" "$fake_bin/curl" \
  "$fake_bin/pi" "$fake_bin/tmux" "$fake_bin/PlistBuddy" "$fake_bin/jq" "$fake_bin/noop" "$generation/activate"

for command_name in brew claude codex herdr kubectl nvim node opencode pre-commit starship terraform uv wezterm; do
  ln -s "$fake_bin/noop" "$fake_bin/$command_name"
done
ln -s "$fake_bin/noop" "$fake_bin/xcode-select"

export BOOTSTRAP_TEST_ACTIVATED="$test_dir/activated"
export BOOTSTRAP_TEST_GENERATION="$generation"
export BOOTSTRAP_TEST_GREP="$real_grep"
export BOOTSTRAP_TEST_HOMEBREW_INSTALLED="$test_dir/homebrew-installed"
export BOOTSTRAP_TEST_NOOP="$fake_bin/noop"
export BOOTSTRAP_TEST_NIX_LOG="$test_dir/nix.log"
export BOOTSTRAP_HOMEBREW="$fake_bin/brew"
export BOOTSTRAP_PLISTBUDDY="$fake_bin/PlistBuddy"
export HOME="$fake_home"
export PATH="$fake_bin:$PATH"
export USER=test

mkdir -p "$HOME/.pi/agent/prompts"
printf 'keep this prompt\n' >"$HOME/.pi/agent/prompts/custom.md"
printf '{"original":true}\n' >"$HOME/.pi/agent/models.json"

"$repo_dir/bootstrap.sh" >/dev/null

grep -Fq 'flake update --flake' "$BOOTSTRAP_TEST_NIX_LOG"
grep -Fq 'flake check path:' "$BOOTSTRAP_TEST_NIX_LOG"
grep -Fq -- '--impure --all-systems' "$BOOTSTRAP_TEST_NIX_LOG"
test -e "$BOOTSTRAP_TEST_ACTIVATED"
grep -Fq 'keep this prompt' "$HOME/.pi/agent/prompts/custom.md"
grep -Fq '"original":true' "$HOME"/.pi/agent/models.json.backup.*
test -L "$HOME/.pi/agent/models.json"

rm -f "$BOOTSTRAP_TEST_ACTIVATED" "$BOOTSTRAP_TEST_NIX_LOG"
"$repo_dir/bootstrap.sh" --check >/dev/null

if grep -Fq 'flake update --flake' "$BOOTSTRAP_TEST_NIX_LOG"; then
  printf 'bootstrap test: --check unexpectedly updated the flake\n' >&2
  exit 1
fi
grep -Fq 'flake check path:' "$BOOTSTRAP_TEST_NIX_LOG"
grep -Fq -- '--impure --all-systems' "$BOOTSTRAP_TEST_NIX_LOG"
test ! -e "$BOOTSTRAP_TEST_ACTIVATED"

fake_etc="$test_dir/etc"
mkdir -p "$fake_etc/static"
printf 'existing bash config\n' >"$fake_etc/bashrc"
printf 'existing zsh config\n' >"$fake_etc/zshrc"
export BOOTSTRAP_DARWIN_ETC_DIR="$fake_etc"
export BOOTSTRAP_TEST_OS=Darwin

rm -f "$BOOTSTRAP_TEST_NIX_LOG"
export BOOTSTRAP_XCODE_SELECT="$fake_bin/missing-xcode-select"
if "$repo_dir/bootstrap.sh" >/dev/null 2>&1; then
  printf 'bootstrap test: macOS preflight accepted missing Command Line Tools\n' >&2
  exit 1
fi
if [[ -e "$BOOTSTRAP_TEST_NIX_LOG" ]]; then
  printf 'bootstrap test: macOS preflight changed Nix state before failing\n' >&2
  exit 1
fi
unset BOOTSTRAP_XCODE_SELECT

rm "$fake_bin/brew"
"$repo_dir/bootstrap.sh" >/dev/null
test -e "$BOOTSTRAP_TEST_HOMEBREW_INSTALLED"
test -x "$fake_bin/brew"

test ! -e "$fake_etc/bashrc"
test ! -e "$fake_etc/zshrc"
grep -Fq 'existing bash config' "$fake_etc/bashrc.before-nix-darwin"
grep -Fq 'existing zsh config' "$fake_etc/zshrc.before-nix-darwin"
grep -Fq 'run path:' "$BOOTSTRAP_TEST_NIX_LOG"

ln -s "$fake_etc/static/bashrc" "$fake_etc/bashrc"
printf 'second zsh config\n' >"$fake_etc/zshrc"
"$repo_dir/bootstrap.sh" >/dev/null

test "$(readlink "$fake_etc/bashrc")" = "$fake_etc/static/bashrc"
test -e "$fake_etc/zshrc.before-nix-darwin"
grep -Fq 'second zsh config' "$fake_etc"/zshrc.before-nix-darwin.*

printf 'bootstrap update and macOS shell backup behavior passed\n'
