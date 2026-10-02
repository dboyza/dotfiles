param(
    [string] $Source = (Join-Path (Split-Path -Parent $PSScriptRoot) "wezterm/floating-tabs/windows.cs"),
    [switch] $Check
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Protect-FloatingTabsState {
    param([Parameter(Mandatory = $true)][string] $Directory)
    # Persist only the DACL. Set-Acl can also try to write audit information,
    # requiring SeSecurityPrivilege on subsequent installs by a standard user.
    $acl = [System.Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    foreach ($identity in @($sid, [System.Security.Principal.SecurityIdentifier]::new("S-1-5-18"))) {
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $identity, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        [void] $acl.AddAccessRule($rule)
    }
    if ($PSVersionTable.PSVersion.Major -le 5) {
        [System.IO.Directory]::SetAccessControl($Directory, $acl)
    } else {
        [System.IO.FileSystemAclExtensions]::SetAccessControl([System.IO.DirectoryInfo]::new($Directory), $acl)
    }
}

# Use the Windows inbox .NET Framework compiler; no SDK or package download needed.
$compiler = Join-Path $env:WINDIR "Microsoft.NET/Framework64/v4.0.30319/csc.exe"
if (-not (Test-Path -LiteralPath $compiler)) {
    $compiler = Join-Path $env:WINDIR "Microsoft.NET/Framework/v4.0.30319/csc.exe"
}
if (-not (Test-Path -LiteralPath $compiler)) { throw "The Windows .NET Framework C# compiler is unavailable." }
$sourcePath = (Resolve-Path -LiteralPath $Source).ProviderPath
$installRoot = Join-Path $HOME ".local/share/dotfiles/wezterm-floating-tabs"
$stateRoot = Join-Path $HOME ".local/state/dotfiles/wezterm-floating-tabs"
$hashes = @($sourcePath, $PSCommandPath) | ForEach-Object {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash
}
$hasher = [System.Security.Cryptography.SHA256]::Create()
try {
    $sourceHash = [BitConverter]::ToString($hasher.ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes(($hashes -join "`n")))).Replace("-", "").ToLowerInvariant()
} finally { $hasher.Dispose() }
$build = Join-Path ([System.IO.Path]::GetTempPath()) "wezterm-floating-tabs-$([Guid]::NewGuid().ToString('N'))"
[void] [System.IO.Directory]::CreateDirectory($build)
try {
    $executable = Join-Path $build "wezterm-floating-tabs.exe"
    & $compiler /nologo /target:winexe /platform:anycpu /optimize+ `
        /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll `
        "/out:$executable" $sourcePath
    if ($LASTEXITCODE -ne 0) { throw "Floating tabs compilation failed." }
    $result = Join-Path $build "test-result.txt"
    $test = Start-Process -FilePath $executable -ArgumentList @("--test", "`"$result`"") -Wait -PassThru
    if ($test.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $result)) {
        if (Test-Path -LiteralPath $result) { Write-Host ([System.IO.File]::ReadAllText($result)) }
        throw "Floating tabs native checks failed."
    }
    Write-Host ([System.IO.File]::ReadAllText($result)).Trim()
    if ($Check) { return }

    [void] [System.IO.Directory]::CreateDirectory($installRoot)
    [void] [System.IO.Directory]::CreateDirectory($stateRoot)
    Protect-FloatingTabsState -Directory $stateRoot
    $target = Join-Path $installRoot "wezterm-floating-tabs.exe"
    $stamp = Join-Path $installRoot "source.sha256"
    $current = (Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $stamp) -and
        ([System.IO.File]::ReadAllText($stamp).Trim() -eq $sourceHash)
    if (-not $current) {
        # Stop only the installed helper, retaining unrelated same-name processes.
        Get-Process -Name "wezterm-floating-tabs" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Path -eq $target) { Stop-Process -Id $_.Id -Force; $_.WaitForExit() }
        }
        # Stage beside the destination so replacement also works across volumes.
        $staged = Join-Path $installRoot "wezterm-floating-tabs.new.exe"
        Copy-Item -LiteralPath $executable -Destination $staged -Force
        if (Test-Path -LiteralPath $target) {
            $backup = "$target.previous"
            if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
            [System.IO.File]::Replace($staged, $target, $backup)
        } else { [System.IO.File]::Move($staged, $target) }
        [System.IO.File]::WriteAllText($stamp, $sourceHash, [System.Text.UTF8Encoding]::new($false))
    }
    Start-Process -FilePath $target
    Write-Host "Installed Windows floating tabs at $target. Reload WezTerm with Ctrl+Shift+R."
} finally {
    Remove-Item -LiteralPath $build -Recurse -Force
}
