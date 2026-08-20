#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pi-update-test.XXXXXX")
cleanup() {
  local exit_code=$?
  rm -rf "$test_dir"
  exit "$exit_code"
}
trap cleanup EXIT

fake_bin="$test_dir/bin"
fake_package="$test_dir/pi-package"
fake_repo="$test_dir/repository"
fixture="$test_dir/fixture"
mkdir -p "$fake_bin" "$fake_package/bin" "$fake_repo/nix" "$fake_repo/pi/extensions" \
  "$fake_repo/pi/themes" "$fake_repo/scripts" "$fixture/package"

cat >"$fake_bin/pi-real" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PI_UPDATE_TEST_REAL_LOG"
if [[ "${1:-}" == update ]] && [[ "${2:-}" != --extensions ]]; then
  printf 'test: native self-update must not run\n' >&2
  exit 1
fi
EOF

cat >"$fake_bin/updater" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PI_UPDATE_TEST_UPDATER_LOG"
EOF

chmod +x "$fake_bin/pi-real" "$fake_bin/updater"

export PI_MANAGED_REAL="$fake_bin/pi-real"
export PI_MANAGED_UPDATER="$fake_bin/updater"
export PI_MANAGED_VERSION=1.0.0
export PI_UPDATE_TEST_REAL_LOG="$test_dir/real.log"
export PI_UPDATE_TEST_UPDATER_LOG="$test_dir/updater.log"

bash "$repo_dir/scripts/pi-managed" update
test ! -s "$PI_UPDATE_TEST_REAL_LOG"
test -s "$PI_UPDATE_TEST_UPDATER_LOG"

: >"$PI_UPDATE_TEST_REAL_LOG"
: >"$PI_UPDATE_TEST_UPDATER_LOG"
bash "$repo_dir/scripts/pi-managed" update --extensions
grep -Fxq 'update --extensions' "$PI_UPDATE_TEST_REAL_LOG"
test ! -s "$PI_UPDATE_TEST_UPDATER_LOG"

: >"$PI_UPDATE_TEST_REAL_LOG"
: >"$PI_UPDATE_TEST_UPDATER_LOG"
bash "$repo_dir/scripts/pi-managed" update --all --force
grep -Fxq 'update --extensions --force' "$PI_UPDATE_TEST_REAL_LOG"
grep -Fxq -- '--force' "$PI_UPDATE_TEST_UPDATER_LOG"

cp "$repo_dir/scripts/update-pi" "$fake_repo/scripts/update-pi"
cat >"$fake_repo/nix/pi-coding-agent.json" <<'EOF'
{
  "version": "1.0.0",
  "tarball": "https://example.invalid/pi-1.0.0.tgz",
  "sourceHash": "sha512-old",
  "npmDepsHash": "sha256-old",
  "missingIntegrities": []
}
EOF

printf '{"packages":[]}\n' >"$fake_repo/pi/settings.json"
printf '{}\n' >"$fake_repo/pi/models.json"

cat >"$fake_package/bin/pi" <<'EOF'
#!/usr/bin/env bash
test "${1:-}" = --mode
test "${2:-}" = rpc
test -L "$PI_CODING_AGENT_DIR/extensions"
EOF

cat >"$fixture/package/npm-shrinkwrap.json" <<'EOF'
{
  "packages": {
    "": {},
    "node_modules/@example/pi-runtime": {
      "version": "9.9.9",
      "resolved": "https://example.invalid/pi-runtime-9.9.9.tgz"
    },
    "node_modules/complete": {
      "version": "1.0.0",
      "resolved": "https://example.invalid/complete-1.0.0.tgz",
      "integrity": "sha512-complete"
    }
  }
}
EOF
tar -czf "$test_dir/pi.tgz" -C "$fixture" package

cat >"$fake_bin/npm" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"dist-tags.latest"*) printf '"9.9.9"\n' ;;
  *"@earendil-works/pi-coding-agent@9.9.9 version"*)
    printf '%s\n' '{"version":"9.9.9","dist.tarball":"https://example.invalid/pi-9.9.9.tgz","dist.integrity":"sha512-new"}'
    ;;
  *"@example/pi-runtime@9.9.9 dist.integrity"*) printf '"sha512-runtime"\n' ;;
  *)
    printf 'test npm: unexpected arguments: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
output=
while (($# > 0)); do
  if [[ "$1" == -o ]]; then
    shift
    output=$1
  fi
  shift
done
cp "$PI_UPDATE_TEST_ARCHIVE" "$output"
EOF

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$fake_bin/nix" <<'EOF'
#!/usr/bin/env bash
test "$DOTFILES_REPOSITORY" = "$PI_UPDATE_TEST_REPOSITORY"
if grep -Fq 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=' \
  "$PI_UPDATE_TEST_REPOSITORY/nix/pi-coding-agent.json"; then
  printf '       got:    sha256-generated-dependency-hash\n' >&2
  exit 1
fi
printf '%s\n' "$PI_UPDATE_TEST_PACKAGE"
EOF

cat >"$fake_repo/bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$PI_UPDATE_TEST_BOOTSTRAP_LOG"
EOF

chmod +x "$fake_bin/pi-real" "$fake_bin/updater" "$fake_bin/npm" "$fake_bin/curl" \
  "$fake_bin/git" "$fake_bin/nix" "$fake_package/bin/pi" "$fake_repo/bootstrap.sh" \
  "$fake_repo/scripts/update-pi"

export PATH="$fake_bin:$PATH"
export PI_UPDATE_TEST_ARCHIVE="$test_dir/pi.tgz"
export PI_UPDATE_TEST_BOOTSTRAP_LOG="$test_dir/bootstrap.log"
export PI_UPDATE_TEST_PACKAGE="$fake_package"
export PI_UPDATE_TEST_REPOSITORY="$fake_repo"
unset PI_MANAGED_VERSION

"$fake_repo/scripts/update-pi"

test "$(jq -r .version "$fake_repo/nix/pi-coding-agent.json")" = 9.9.9
test "$(jq -r .npmDepsHash "$fake_repo/nix/pi-coding-agent.json")" = sha256-generated-dependency-hash
test "$(jq -r '.missingIntegrities[0].integrity' "$fake_repo/nix/pi-coding-agent.json")" = sha512-runtime
grep -Fxq -- '--apply' "$PI_UPDATE_TEST_BOOTSTRAP_LOG"

printf 'Managed Pi update routing and metadata refresh passed\n'
