$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repository = Split-Path -Parent $PSScriptRoot
$scripts = @(
    (Join-Path $repository "scripts/install-windows-fonts.ps1"),
    (Join-Path $repository "scripts/install-windows-wezterm.ps1")
)

foreach ($script in $scripts) {
    $tokens = $null
    $errors = $null
    [void] [System.Management.Automation.Language.Parser]::ParseFile(
        $script,
        [ref] $tokens,
        [ref] $errors
    )

    if ($errors.Count -gt 0) {
        $messages = ($errors | ForEach-Object Message) -join [Environment]::NewLine
        throw "PowerShell syntax validation failed for ${script}:$([Environment]::NewLine)$messages"
    }
}

$weztermInstaller = Get-Content -Raw -LiteralPath $scripts[1]
if ($weztermInstaller -notmatch 'APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE') {
    throw "The WezTerm installer does not handle Winget's no-applicable-update result."
}
if ($weztermInstaller -notmatch 'Get-FileHash' -or $weztermInstaller -notmatch 'SHA256') {
    throw "The WezTerm installer does not verify the copied configuration."
}

Write-Host "Native Windows PowerShell compatibility passed"
