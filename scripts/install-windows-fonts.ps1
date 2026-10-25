# Install missing Windows-host fonts from the supplied source directory.
param(
    [Parameter(Mandatory = $true)]
    [string] $Source,
    [string] $Filter = "*.ttf"
)

$ErrorActionPreference = "Stop"
# Section: Per-user destinations and input discovery
$destination = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$registryPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

New-Item -ItemType Directory -Force -Path $destination | Out-Null
if (-not (Test-Path -LiteralPath $registryPath)) { New-Item -Path $registryPath | Out-Null }

$fonts = Get-ChildItem -Path $Source -Filter $Filter -File -Recurse
if (-not $fonts) {
    throw "No fonts matching $Filter were found under $Source"
}

# Section: Content-addressed font registration
# Only new or repointed fonts are loaded, so repeat runs skip the system-wide font reload.
$changedFonts = @()
foreach ($font in $fonts) {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $font.FullName).Hash.Substring(0, 12).ToLowerInvariant()
    $targetName = "$($font.BaseName)-$hash$($font.Extension)"
    $target = Join-Path $destination $targetName
    $valueName = "$($font.BaseName) (TrueType)"

    $copied = -not (Test-Path -LiteralPath $target)
    if ($copied) {
        Copy-Item -LiteralPath $font.FullName -Destination $target
    }
    $registered = (Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
    if ($copied -or $registered -ne $target) {
        New-ItemProperty -Path $registryPath -Name $valueName -PropertyType String -Value $target -Force | Out-Null
        $changedFonts += $target
    }
}

if (-not $changedFonts) {
    Write-Host "All $($fonts.Count) JetBrains Mono Nerd Font files are already installed for the current Windows user."
    exit 0
}

# Section: Native font reload APIs
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class FontInstaller {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    public static extern int AddFontResourceEx(
        string name,
        uint flags,
        IntPtr reserved
    );

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint message,
        IntPtr wParam,
        string lParam,
        uint flags,
        uint timeout,
        out IntPtr result
    );
}
"@

# Section: Load fonts and notify running applications
foreach ($fontPath in $changedFonts) {
    if ([FontInstaller]::AddFontResourceEx($fontPath, 0, [IntPtr]::Zero) -eq 0) {
        throw "Windows could not load the font resource $fontPath"
    }
}

$result = [IntPtr]::Zero
[FontInstaller]::SendMessageTimeout(
    [IntPtr] 0xffff,
    0x001D,
    [IntPtr]::Zero,
    $null,
    0x0002,
    1000,
    [ref] $result
) | Out-Null

Write-Host "Installed $($changedFonts.Count) JetBrains Mono Nerd Font files for the current Windows user."
# WezTerm enumerates fonts once at startup and does not react to WM_FONTCHANGE.
Write-Host "Fully quit and reopen Windows WezTerm to use the new fonts."
