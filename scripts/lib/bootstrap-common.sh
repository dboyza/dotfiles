#!/usr/bin/env bash

# shellcheck disable=SC2154
# Shared bootstrap functions. This file is sourced by bootstrap.sh.

# shellcheck source=scripts/lib/wezterm.sh
source "$repo_dir/scripts/lib/wezterm.sh"

load_nix() {
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  local profile_script
  for profile_script in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
    if [[ -r "$profile_script" ]]; then
      # shellcheck disable=SC1090
      source "$profile_script"
    fi
  done
}

require_existing_nix() {
  load_nix
  if ! command -v nix >/dev/null 2>&1; then
    printf 'bootstrap: --check is non-mutating and requires Nix to be installed already\n' >&2
    printf 'bootstrap: run ./bootstrap.sh once to install and activate the environment\n' >&2
    exit 1
  fi
}

preflight_installation() {
  load_nix
  printf 'Bootstrap preflight for %s:\n' "$profile"
  if command -v nix >/dev/null 2>&1; then
    printf '  Nix: installed\n'
  else
    printf '  Nix: will be installed\n'
    if command -v curl >/dev/null 2>&1; then
      printf '  curl: installed\n'
    elif command -v apt-get >/dev/null 2>&1; then
      printf '  curl: will be installed through apt\n'
    else
      printf 'bootstrap: curl is required to install Nix\n' >&2
      return 1
    fi
  fi
  preflight_platform_installation
}

install_nix() {
  load_nix
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
  fi

  local installer
  installer=$(mktemp "${TMPDIR:-/tmp}/nix-install.XXXXXX")
  curl --proto '=https' --tlsv1.2 -fsSL https://nixos.org/nix/install -o "$installer"

  if [[ "$os" == Darwin ]] || [[ $(ps -p 1 -o comm= 2>/dev/null) == systemd ]]; then
    sh "$installer" --daemon
  else
    sh "$installer" --no-daemon
  fi
  rm -f "$installer"

  load_nix
  if ! command -v nix >/dev/null 2>&1; then
    printf 'bootstrap: Nix installed but is not available in this shell; open a new shell and rerun this script\n' >&2
    exit 1
  fi
}

load_managed_targets() {
  local attribute inventory target
  if [[ "$os" == Darwin ]]; then
    attribute="darwinConfigurations.$profile.config.home-manager.users.\"$DOTFILES_USER\".home.file"
  else
    attribute="homeConfigurations.$profile.config.home.file"
  fi

  # Evaluate once before backups; a failed evaluation must stop activation.
  inventory=$(nix "${nix_options[@]}" eval --raw "$flake_ref#$attribute" --impure \
    --apply 'files: builtins.concatStringsSep "\n" (map (file: file.target) (builtins.filter (file: file.enable) (builtins.attrValues files)))') || return
  if [[ -z "$inventory" ]]; then
    printf 'bootstrap: Home Manager returned an empty managed-file inventory\n' >&2
    return 1
  fi

  managed_file_targets=()
  while IFS= read -r target; do
    case "/$target/" in
      //* | */../* | */./*)
        printf 'bootstrap: invalid managed home path: %s\n' "$target" >&2
        return 1
        ;;
    esac
    managed_file_targets+=("$HOME/$target")
  done <<<"$inventory"
}

managed_targets() {
  printf '%s\n' "${managed_file_targets[@]}"
}

backup_managed_files() {
  local stamp target link_target
  stamp=$(date +%Y%m%d%H%M%S)

  while IFS= read -r target; do
    [[ -e "$target" || -L "$target" ]] || continue

    if [[ -L "$target" ]]; then
      link_target=$(readlink "$target" 2>/dev/null || true)
      case "$link_target" in
        "$repo_dir"/* | /nix/store/*) continue ;;
      esac
    fi

    mv "$target" "$target.backup.$stamp"
    printf 'Backed up %s\n' "$target"
  done < <(managed_targets)
}

verify_managed_links() {
  local link_target missing=0 target

  while IFS= read -r target; do
    if [[ ! -L "$target" ]]; then
      printf 'bootstrap: expected managed link is missing: %s\n' "$target" >&2
      missing=1
      continue
    fi

    link_target=$(readlink "$target" 2>/dev/null || true)
    case "$link_target" in
      /nix/store/* | "$repo_dir"/*) ;;
      *)
        printf 'bootstrap: managed link does not point into the checkout or Nix store: %s\n' "$target" >&2
        missing=1
        ;;
    esac
  done < <(managed_targets)

  ((missing == 0))
}

verify_pi_configuration() {
  if [[ ! -f "$HOME/.pi/agent/settings.json" ]]; then
    printf 'bootstrap: Pi settings.json is missing\n' >&2
    return 1
  fi
  if ! jq empty "$HOME/.pi/agent/settings.json" >/dev/null 2>&1; then
    printf 'bootstrap: Pi settings.json contains invalid JSON\n' >&2
    return 1
  fi
}

verify_tmux_configuration() (
  local prefix socket_name tmux_tmp
  tmux_tmp=$(mktemp -d /tmp/dotfiles-tmux-verify.XXXXXX)
  socket_name="dotfiles-verify-$$"

  # Invoked by the EXIT trap below.
  # shellcheck disable=SC2329
  cleanup_tmux_verification() {
    TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" kill-server >/dev/null 2>&1 || true
    rm -rf "$tmux_tmp"
  }
  trap cleanup_tmux_verification EXIT

  TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" -f "$HOME/.tmux.conf" new-session -d
  prefix=$(TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" show-options -gv prefix)
  if [[ "$prefix" != C-g ]]; then
    printf 'bootstrap: expected tmux prefix C-g, found %s\n' "$prefix" >&2
    return 1
  fi

  if TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" list-keys -T prefix | grep -Eq -- '-T[[:space:]]+prefix[[:space:]]+C-a[[:space:]]'; then
    printf 'bootstrap: tmux prefix table still binds C-a\n' >&2
    return 1
  fi
)

verify_wezterm_configuration() {
  if [[ "$DOTFILES_WSL" == 1 ]]; then
    return 0
  fi

  local wezterm_command
  if ! wezterm_command=$(find_wezterm); then
    printf 'bootstrap: WezTerm executable is missing\n' >&2
    return 1
  fi

  if ! "$wezterm_command" --config-file "$HOME/.wezterm.lua" show-keys >/dev/null; then
    printf 'bootstrap: WezTerm rejected the activated configuration\n' >&2
    return 1
  fi
}

build_configuration() {
  if [[ "$os" == Darwin ]]; then
    nix "${nix_options[@]}" build \
      "$flake_ref#darwinConfigurations.$profile.system" \
      --impure \
      --no-link
  else
    nix "${nix_options[@]}" build \
      "$flake_ref#homeConfigurations.$profile.activationPackage" \
      --impure \
      --no-link
  fi
}

verify_installation() {
  local command_name missing=0
  local expected_commands=(claude codex gh git herdr kubectl nvim node opencode pi pre-commit rg starship terraform tmux uv zsh)
  export PATH="$HOME/.local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$DOTFILES_USER/bin:/run/current-system/sw/bin:$PATH"

  if [[ "$os" == Darwin ]]; then
    local brew_binary
    brew_binary=$(find_homebrew)
    eval "$("$brew_binary" shellenv)"
  fi

  for command_name in "${expected_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'bootstrap: expected command is missing: %s\n' "$command_name" >&2
      missing=1
    fi
  done

  if ((missing)); then
    return 1
  fi

  verify_managed_links
  verify_pi_configuration
  node --check "$repo_dir/scripts/dotfiles-tool.mjs"
  verify_tmux_configuration
  verify_wezterm_configuration
  verify_platform
}
