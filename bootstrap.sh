#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--check | --update]

  --check  Evaluate and build the pinned configuration without updating inputs or activating configuration.
  --update Update, check, and activate the configuration (the default behavior).
EOF
}

check_only=false
case "${1:-}" in
  "") ;;
  --check) check_only=true ;;
  --update) ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

unset CDPATH
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ ! -f "$repo_dir/flake.nix" ]]; then
  printf 'bootstrap: flake.nix was not found next to this script\n' >&2
  exit 1
fi

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  printf 'bootstrap: run this script as your normal user, not root\n' >&2
  exit 1
fi

os=$(uname -s)
architecture=$(uname -m)
case "$architecture" in
  arm64 | aarch64) nix_architecture=aarch64 ;;
  x86_64 | amd64) nix_architecture=x86_64 ;;
  *)
    printf 'bootstrap: unsupported architecture: %s\n' "$architecture" >&2
    exit 1
    ;;
esac

case "$os" in
  Darwin)
    profile="macos-$nix_architecture"
    platform_library=macos
    ;;
  Linux)
    profile="linux-$nix_architecture"
    platform_library=linux
    ;;
  *)
    printf 'bootstrap: supported operating systems are Linux and macOS\n' >&2
    exit 1
    ;;
esac

export DOTFILES_USER=${USER:-$(id -un)}
export DOTFILES_HOME=$HOME
export DOTFILES_WSL=0
if [[ "$os" == Linux ]] && grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  export DOTFILES_WSL=1
fi

# shellcheck source=scripts/lib/bootstrap-common.sh
source "$repo_dir/scripts/lib/bootstrap-common.sh"
# shellcheck source=/dev/null
source "$repo_dir/scripts/lib/bootstrap-$platform_library.sh"

if $check_only; then
  require_existing_nix
else
  preflight_installation
  install_nix
fi

nix_options=(--extra-experimental-features "nix-command flakes")
flake_ref="path:$repo_dir"

if ! $check_only; then
  printf 'Updating Nix packages and plugin inputs to their latest declared versions...\n'
  nix "${nix_options[@]}" flake update --flake "$flake_ref"
fi

printf 'Checking %s configuration...\n' "$profile"
nix "${nix_options[@]}" flake check "$flake_ref" --impure --all-systems

if $check_only; then
  build_configuration
  printf 'Configuration check passed for %s.\n' "$profile"
  exit 0
fi

backup_managed_files
activate_platform
verify_installation
printf 'Bootstrap complete. Open a new terminal to use the configured environment.\n'
