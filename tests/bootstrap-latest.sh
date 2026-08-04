#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
real_grep=$(type -P grep)
real_true=$(type -P true)
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
fi
EOF

cat >"$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Linux\n' ;;
  -m) printf 'x86_64\n' ;;
  *) printf 'Linux\n' ;;
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
EOF

chmod +x "$fake_bin/nix" "$fake_bin/uname" "$fake_bin/grep" "$fake_bin/getent" "$generation/activate"

for command_name in claude codex herdr kubectl nvim node opencode pi pre-commit starship terraform uv; do
  ln -s "$real_true" "$fake_bin/$command_name"
done

export BOOTSTRAP_TEST_ACTIVATED="$test_dir/activated"
export BOOTSTRAP_TEST_GENERATION="$generation"
export BOOTSTRAP_TEST_GREP="$real_grep"
export BOOTSTRAP_TEST_NIX_LOG="$test_dir/nix.log"
export HOME="$fake_home"
export PATH="$fake_bin:$PATH"
export USER=test

"$repo_dir/bootstrap.sh" >/dev/null

grep -Fq 'flake update --flake' "$BOOTSTRAP_TEST_NIX_LOG"
grep -Fq 'flake check' "$BOOTSTRAP_TEST_NIX_LOG"
test -e "$BOOTSTRAP_TEST_ACTIVATED"

rm -f "$BOOTSTRAP_TEST_ACTIVATED" "$BOOTSTRAP_TEST_NIX_LOG"
"$repo_dir/bootstrap.sh" --check >/dev/null

if grep -Fq 'flake update --flake' "$BOOTSTRAP_TEST_NIX_LOG"; then
  printf 'bootstrap test: --check unexpectedly updated the flake\n' >&2
  exit 1
fi
grep -Fq 'flake check' "$BOOTSTRAP_TEST_NIX_LOG"
test ! -e "$BOOTSTRAP_TEST_ACTIVATED"

printf 'bootstrap update behavior passed\n'
