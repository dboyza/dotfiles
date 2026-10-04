# Install Windows WezTerm and connect its UTF-8 loader to the live checkout.
param(
    [Parameter(Mandatory = $true)]
    [string] $Source
)

$ErrorActionPreference = "Stop"

# Section: WezTerm package update
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
    throw "Winget is unavailable. Install or update App Installer on Windows, then rerun bootstrap.sh."
}

# Winget's install command upgrades an existing package unless --no-upgrade is used.
& $winget.Source install `
    --exact `
    --id wez.wezterm `
    --source winget `
    --silent `
    --disable-interactivity `
    --accept-package-agreements `
    --accept-source-agreements

$wingetExitCode = $LASTEXITCODE
$noApplicableUpdate = -1978335189 # 0x8A15002B: APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
if ($wingetExitCode -ne 0 -and $wingetExitCode -ne $noApplicableUpdate) {
    throw "Winget failed to install or upgrade WezTerm with exit code $wingetExitCode."
}

if ($wingetExitCode -eq $noApplicableUpdate) {
    Write-Host "Windows WezTerm is already at the newest applicable version."
}

# Install before the loader's idempotent early return so helper updates are applied.
& (Join-Path $PSScriptRoot "install-wezterm-floating-tabs.ps1")

# A loader works with local paths and WSL UNC paths without Developer Mode or elevation.
# Section: Live checkout loader
$sourcePath = (Resolve-Path -LiteralPath $Source).ProviderPath
$luaPath = $sourcePath.Replace('\', '\\').Replace('"', '\"')
$loader = @"
-- Managed by dotfiles. Configuration stays in the checkout.
local source = "$luaPath"
require("wezterm").add_to_config_reload_watch_list(source)
return assert(loadfile(source))(source)
"@

# Section: Preserve and replace the user loader
$target = Join-Path $HOME ".wezterm.lua"
if (Test-Path -LiteralPath $target) {
    if ((Get-Content -Raw -Encoding UTF8 -LiteralPath $target).TrimEnd() -eq $loader.TrimEnd()) {
        Write-Host "Windows WezTerm is installed and its live configuration loader is current."
        exit 0
    }

    $stamp = Get-Date -Format "yyyyMMddHHmmssfff"
    Move-Item -LiteralPath $target -Destination "$target.backup.$stamp"
}

# Explicit UTF-8 without BOM behaves consistently on PowerShell 5.1 and 7.
[System.IO.File]::WriteAllText($target, $loader, [System.Text.UTF8Encoding]::new($false))
if ((Get-Content -Raw -Encoding UTF8 -LiteralPath $target).TrimEnd() -ne $loader.TrimEnd()) {
    throw "The WezTerm configuration loader failed verification."
}

Write-Host "Installed the live WezTerm configuration loader at $target."
