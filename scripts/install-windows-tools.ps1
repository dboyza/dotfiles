param(
    [string] $Repository = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($env:OS -ne "Windows_NT") {
    throw "Run this installer in native Windows PowerShell, not WSL."
}

$node = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue
if (-not $node) {
    throw "Install Node.js LTS with 'winget install --exact --id OpenJS.NodeJS.LTS', reopen PowerShell, then rerun this script."
}
$nodeVersion = & $node.Source -p 'process.versions.node'
if ($LASTEXITCODE -ne 0 -or [version]$nodeVersion -lt [version]'22.19.0') {
    throw "These launchers require Node.js 22.19 or newer. Upgrade Node.js LTS and reopen PowerShell."
}
if (-not (Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue)) {
    throw "npm.cmd is unavailable. Repair your Node.js LTS installation, then reopen PowerShell."
}

$repositoryPath = (Resolve-Path -LiteralPath $Repository).ProviderPath
$source = Join-Path $repositoryPath "scripts/dotfiles-tool.mjs"
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "The checkout does not contain scripts/dotfiles-tool.mjs."
}

$bin = Join-Path $HOME ".local/bin"
[void] [System.IO.Directory]::CreateDirectory($bin)
$encoding = [System.Text.UTF8Encoding]::new($false)
$marker = "Managed by dotfiles tool launchers."

function Write-ManagedLauncher {
    param([string] $Path, [string] $Content)

    if (Test-Path -LiteralPath $Path) {
        $existing = [System.IO.File]::ReadAllText($Path)
        if ($existing -eq $Content) {
            return
        }
        if (-not $existing.Contains($marker)) {
            $backup = "$Path.backup.$([System.Guid]::NewGuid().ToString('N'))"
            Move-Item -LiteralPath $Path -Destination $backup
            Write-Host "Preserved existing launcher at $backup."
        }
    }
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

# A local JS shim preserves Unicode and UNC checkout paths without cmd.exe interpolation.
$sourceUrl = ([System.Uri]::new($source)).AbsoluteUri | ConvertTo-Json -Compress
$shim = "// $marker`nimport { main } from $sourceUrl;`nawait main(process.argv[2], process.argv.slice(3));`n"
Write-ManagedLauncher -Path (Join-Path $bin "dotfiles-tool.mjs") -Content $shim

foreach ($tool in @("codex", "pi", "opencode", "herdr")) {
    $launcher = "@echo off`r`nrem $marker`r`nnode `"%~dp0dotfiles-tool.mjs`" $tool %*`r`nexit /b %errorlevel%`r`n"
    Write-ManagedLauncher -Path (Join-Path $bin "$tool.cmd") -Content $launcher
}

# Preserve expandable variables in the user's existing PATH and its registry value kind.
$environmentKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Environment")
try {
    $pathValue = $environmentKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $pathKind = if ($environmentKey.GetValueNames() -contains "Path") {
        $environmentKey.GetValueKind("Path")
    } else {
        [Microsoft.Win32.RegistryValueKind]::ExpandString
    }
    $remaining = @($pathValue.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) | Where-Object {
        [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\', '/') -ine $bin.TrimEnd('\', '/')
    })
    $environmentKey.SetValue("Path", (@($bin) + $remaining) -join ';', $pathKind)
} finally {
    $environmentKey.Dispose()
}
$env:Path = "$bin;$env:Path"

Write-Host "Installed Codex, Pi, OpenCode, and Herdr launchers in $bin."
Write-Host "Each tool installs or updates when launched. Reopen your terminal to use the updated PATH."
