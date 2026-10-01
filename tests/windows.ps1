$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repository = Split-Path -Parent $PSScriptRoot
$scripts = @(
    (Join-Path $repository "scripts/install-windows-fonts.ps1"),
    (Join-Path $repository "scripts/install-windows-wezterm.ps1"),
    (Join-Path $repository "scripts/install-windows-tools.ps1")
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
if ($weztermInstaller -notmatch 'return dofile' -or $weztermInstaller -notmatch 'add_to_config_reload_watch_list') {
    throw "The WezTerm installer must load and watch the live checkout configuration."
}

$tokens = $null
$errors = $null
$toolInstaller = [System.Management.Automation.Language.Parser]::ParseFile($scripts[2], [ref] $tokens, [ref] $errors)
$backupFunction = $toolInstaller.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "Backup-ConflictingToolLaunchers"
}, $true)
if (-not $backupFunction) {
    throw "The tool installer must preserve commands that would shadow managed launchers."
}
. ([scriptblock]::Create($backupFunction.Extent.Text))
$testDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "dotfiles-launchers-$([System.Guid]::NewGuid().ToString('N'))"
[void] [System.IO.Directory]::CreateDirectory($testDirectory)
try {
    foreach ($extension in @(".exe", ".com", ".bat", ".ps1")) {
        [System.IO.File]::WriteAllText((Join-Path $testDirectory "claude$extension"), "original-$extension")
    }
    [System.IO.File]::WriteAllText((Join-Path $testDirectory "claude.cmd"), "managed")
    [System.IO.File]::WriteAllText((Join-Path $testDirectory "unrelated.exe"), "keep")
    Backup-ConflictingToolLaunchers -Directory $testDirectory -Tool "claude"
    Backup-ConflictingToolLaunchers -Directory $testDirectory -Tool "claude"
    foreach ($extension in @(".exe", ".com", ".bat", ".ps1")) {
        $backups = @(Get-ChildItem -LiteralPath $testDirectory -Filter "claude$extension.backup.*")
        if ((Test-Path -LiteralPath (Join-Path $testDirectory "claude$extension")) -or $backups.Count -ne 1) {
            throw "Conflicting $extension launcher was not preserved exactly once."
        }
        if ([System.IO.File]::ReadAllText($backups[0].FullName) -ne "original-$extension") {
            throw "Conflicting $extension launcher content changed."
        }
    }
    if ([System.IO.File]::ReadAllText((Join-Path $testDirectory "claude.cmd")) -ne "managed" -or
        [System.IO.File]::ReadAllText((Join-Path $testDirectory "unrelated.exe")) -ne "keep") {
        throw "Launcher migration changed an unrelated command."
    }
} finally {
    Remove-Item -LiteralPath $testDirectory -Recurse -Force
}

Write-Host "Native Windows PowerShell compatibility passed"
