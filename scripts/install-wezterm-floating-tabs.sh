#!/usr/bin/env bash
# Build and validate the macOS companion before replacing this repository's installed helper.
set -Eeuo pipefail

if [[ $(uname -s) != Darwin ]]; then
  printf 'Floating WezTerm tabs require macOS; native tabs remain available.\n'
  exit 0
fi
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Section: Installed identity and freshness
app_dir="$HOME/Applications/WezTerm Floating Tabs.app"
state_dir="$HOME/.local/state/dotfiles/wezterm-floating-tabs"
source_file="$repo_dir/wezterm/floating-tabs/main.swift"
source_hash=$(shasum -a 256 "$source_file" "$repo_dir/scripts/install-wezterm-floating-tabs.sh" | shasum -a 256 | cut -d ' ' -f 1)
mkdir -p "$state_dir" "$HOME/Applications"
chmod 700 "$state_dir"
if [[ -x "$app_dir/Contents/MacOS/wezterm-floating-tabs" && -f "$app_dir/Contents/Resources/source.sha256" ]] &&
  [[ $(cat "$app_dir/Contents/Resources/source.sha256") == "$source_hash" ]]; then
  printf 'Floating tabs are already installed.\n'
  exit 0
fi
# Section: Compile and validate in temporary storage
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/wezterm-floating-tabs.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
mkdir -p "$build_dir/app/Contents/MacOS" "$build_dir/app/Contents/Resources"
xcrun swiftc -O -module-cache-path "$build_dir/modules" "$source_file" \
  -o "$build_dir/app/Contents/MacOS/wezterm-floating-tabs"
"$build_dir/app/Contents/MacOS/wezterm-floating-tabs" --test "$repo_dir/tests/fixtures/floating-tabs.json"
cat >"$build_dir/app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.dboyza.wezterm-floating-tabs</string>
<key>CFBundleName</key><string>WezTerm Floating Tabs</string>
<key>CFBundleExecutable</key><string>wezterm-floating-tabs</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>NSAccessibilityUsageDescription</key><string>Follow WezTerm windows with clickable floating tabs.</string>
</dict></plist>
PLIST
printf '%s\n' "$source_hash" >"$build_dir/app/Contents/Resources/source.sha256"
# Section: Stable local signing identity
# Accessibility grants follow the signing certificate, so a persistent self-signed identity
# keeps the permission across rebuilds; ad-hoc signatures change with every build.
signing_name="dotfiles local code signing"
keychain="$HOME/Library/Keychains/dotfiles-codesign.keychain-db"
password_file="$HOME/.local/state/dotfiles/codesign-keychain-password"

create_signing_keychain() {
  local work password status
  work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-codesign.XXXXXX") || return 1
  password=$(/usr/bin/openssl rand -hex 24) || return 1
  cat >"$work/request.cnf" <<CNF
[req]
distinguished_name = name
x509_extensions = extensions
prompt = no
[name]
CN = $signing_name
[extensions]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF
  # The keychain only protects this local certificate, so its password lives in a user-only file.
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$work/request.cnf" \
    -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null &&
    /usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
      -out "$work/identity.p12" -passout "pass:$password" &&
    { [[ ! -e "$keychain" ]] || security delete-keychain "$keychain"; } &&
    security create-keychain -p "$password" "$keychain" &&
    security set-keychain-settings "$keychain" &&
    security import "$work/identity.p12" -k "$keychain" -P "$password" -T /usr/bin/codesign >/dev/null &&
    security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" >/dev/null &&
    (umask 077 && printf '%s\n' "$password" >"$password_file")
  status=$?
  rm -rf "$work"
  return "$status"
}

# Sign with the stable identity, adding its keychain to the search list only while codesign runs.
sign_with_stable_identity() {
  local entry status
  local -a searched=()
  if [[ ! -f "$keychain" || ! -f "$password_file" ]]; then
    create_signing_keychain || return 1
  fi
  security unlock-keychain -p "$(cat "$password_file")" "$keychain" || return 1
  while IFS= read -r entry; do
    entry=${entry#"${entry%%[![:space:]]*}"}
    entry=${entry#\"}
    searched+=("${entry%\"}")
  done < <(security list-keychains -d user)
  security list-keychains -d user -s ${searched[@]+"${searched[@]}"} "$keychain" || return 1
  codesign --force --sign "$signing_name" --identifier com.dboyza.wezterm-floating-tabs "$1"
  status=$?
  security list-keychains -d user -s ${searched[@]+"${searched[@]}"}
  return "$status"
}

# Section: Sign and publish with a recoverable backup
if ! sign_with_stable_identity "$build_dir/app"; then
  printf 'Stable signing failed; using an ad-hoc signature that needs a fresh Accessibility grant.\n' >&2
  codesign --force --sign - --identifier com.dboyza.wezterm-floating-tabs "$build_dir/app"
fi
# Replace only this repository's helper, keeping just the most recent previous build.
if [[ -e "$app_dir" ]]; then
  identifier=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_dir/Contents/Info.plist")
  [[ "$identifier" == com.dboyza.wezterm-floating-tabs ]] || {
    printf 'Refusing to replace another app.\n' >&2
    exit 1
  }
  # Older installers left timestamped backups; remove those along with the last one.
  rm -rf "$HOME/Applications/WezTerm Floating Tabs.previous.app" \
    "$HOME/Applications/WezTerm Floating Tabs.previous."[0-9]*.app
  mv "$app_dir" "$HOME/Applications/WezTerm Floating Tabs.previous.app"
fi
mv "$build_dir/app" "$app_dir"
# A running helper keeps executing the moved backup, and WezTerm's launch would reuse it.
if pkill -x wezterm-floating-tabs; then
  open -g "$app_dir" || printf 'Restart WezTerm to launch the updated helper.\n' >&2
fi
printf 'Installed %s\nEnable it in System Settings > Privacy & Security > Accessibility when prompted.\n' "$app_dir"
