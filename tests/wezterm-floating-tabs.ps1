$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repository = Split-Path -Parent $PSScriptRoot
& (Join-Path $repository "scripts/install-wezterm-floating-tabs.ps1") -Check

$wezterm = Get-Command wezterm.exe -ErrorAction SilentlyContinue
$command = if ($wezterm) { $wezterm.Source } else { Join-Path $env:ProgramFiles "WezTerm/wezterm.exe" }
if (-not (Test-Path -LiteralPath $command)) { throw "Install Windows WezTerm to run the real Lua bridge checks." }
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) "floating-tabs-$([Guid]::NewGuid().ToString('N'))"
$previousHome = $env:DOTFILES_FLOATING_TEST_HOME
try {
    # Regression: applying the private ACL repeatedly must not require elevation.
    $installerAst = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repository "scripts/install-wezterm-floating-tabs.ps1"), [ref] $null, [ref] $null)
    $protect = $installerAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "Protect-FloatingTabsState"
    }, $true)
    . ([scriptblock]::Create($protect.Extent.Text))
    [void] [System.IO.Directory]::CreateDirectory($fixture)
    Protect-FloatingTabsState -Directory $fixture
    Protect-FloatingTabsState -Directory $fixture
    $acl = Get-Acl -LiteralPath $fixture
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    if (-not $acl.AreAccessRulesProtected -or $rules.Count -ne 2) { throw "State ACL is not private." }
    foreach ($rule in $rules) {
        if ($rule.IdentityReference.Value -notin @($sid, "S-1-5-18") -or
            $rule.FileSystemRights -ne [System.Security.AccessControl.FileSystemRights]::FullControl -or
            $rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            throw "Unexpected state directory permission."
        }
    }
    Write-Host "Repeated private state ACL configuration passed"
    $bin = Join-Path $fixture ".local/share/dotfiles/wezterm-floating-tabs"
    [void] [System.IO.Directory]::CreateDirectory($bin)
    [void] [System.IO.Directory]::CreateDirectory((Join-Path $fixture ".local/state/dotfiles/wezterm-floating-tabs"))
    [System.IO.File]::WriteAllText((Join-Path $bin "wezterm-floating-tabs.exe"), "fixture")
    $env:DOTFILES_FLOATING_TEST_HOME = $fixture.Replace('\', '/')
    & $command --config-file (Join-Path $PSScriptRoot "wezterm-floating-tabs.lua") show-keys | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Windows floating tabs bridge failed." }
    Write-Host "Windows floating tabs Lua bridge passed"
} finally {
    $env:DOTFILES_FLOATING_TEST_HOME = $previousHome
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
