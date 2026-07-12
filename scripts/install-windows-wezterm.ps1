param(
    [Parameter(Mandatory = $true)]
    [string] $Source
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command wezterm.exe -ErrorAction SilentlyContinue)) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "WezTerm is missing and Winget is unavailable. Install WezTerm on Windows, then rerun bootstrap.sh."
    }

    & $winget.Source install `
        --exact `
        --id wez.wezterm `
        --source winget `
        --silent `
        --disable-interactivity `
        --accept-package-agreements `
        --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Winget failed to install WezTerm with exit code $LASTEXITCODE."
    }
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
Write-Host "Installed the WezTerm configuration at $target."
