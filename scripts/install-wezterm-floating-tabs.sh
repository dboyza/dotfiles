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
# Section: Sign and publish with a recoverable backup
codesign --force --sign - --identifier com.dboyza.wezterm-floating-tabs "$build_dir/app"
# Replace only this repository's helper, retaining a recoverable previous build.
if [[ -e "$app_dir" ]]; then
  identifier=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_dir/Contents/Info.plist")
  [[ "$identifier" == com.dboyza.wezterm-floating-tabs ]] || {
    printf 'Refusing to replace another app.\n' >&2
    exit 1
  }
  backup_dir="$HOME/Applications/WezTerm Floating Tabs.previous.$(date +%s).app"
  mv "$app_dir" "$backup_dir"
fi
mv "$build_dir/app" "$app_dir"
printf 'Installed %s\nEnable it in System Settings > Privacy & Security > Accessibility when prompted.\n' "$app_dir"
