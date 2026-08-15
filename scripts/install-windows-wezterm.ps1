param(
    [Parameter(Mandatory = $true)]
    [string] $Source
)

$ErrorActionPreference = "Stop"

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

$target = Join-Path $HOME ".wezterm.lua"
if (Test-Path -LiteralPath $target) {
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash
    $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash

    if ($sourceHash -eq $targetHash) {
        Write-Host "Windows WezTerm is installed and its configuration is current."
        exit 0
    }

    $stamp = Get-Date -Format "yyyyMMddHHmmssfff"
    Move-Item -LiteralPath $target -Destination "$target.backup.$stamp"
}

Copy-Item -LiteralPath $Source -Destination $target -Force

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash
$targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash
if ($sourceHash -ne $targetHash) {
    throw "The copied WezTerm configuration failed SHA256 verification."
}

Write-Host "Installed the WezTerm configuration at $target."
