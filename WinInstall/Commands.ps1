# =============================================================================
#  Commands.ps1 - All user-facing win commands
#  Part of WinInstall
# =============================================================================

function Install-WinPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$PackageName,
        [switch]$SkipInstall,
        [switch]$Force
    )

    Write-Banner
    Assert-Winget
    Assert-Admin "Invoke-Win install $PackageName"

    $pkg = Get-PackageDef $PackageName
    if (-not $pkg) {
        Write-Err "Unknown package: '$PackageName'"
        Write-Host ""
        Write-Info "Run 'win list' to see all available packages."
        Write-Info "Run 'win search $PackageName' to search winget directly."
        exit 1
    }

    Write-Host "$($script:CLR.Bold)$($script:CLR.White)Installing: $($pkg.display_name)$($script:CLR.Reset)"
    Write-Gray  "winget ID : $($pkg.winget_id)"
    Write-Gray  "About     : $($pkg.description)"
    Write-Host ""

    if (-not $SkipInstall) {
        Install-ViaWinget $pkg.winget_id
    } else {
        Write-Info "Skipping install (--skip-install). Fixing PATH/ENV only..."
    }

    Write-Info "Applying PATH and environment variable configuration..."
    $result = Apply-PackageEnvironment $PackageName $pkg $true

    Write-Host ""
    Write-Info "Verifying installation..."
    try {
        $verifyOutput = Invoke-Expression $pkg.verify_cmd 2>&1
        Write-Ok "Verified: $verifyOutput"
    } catch {
        Write-Warn "Verification command failed. Restart your terminal and try: $($pkg.verify_cmd)"
    }

    Write-Host ""
    Write-Host "$($script:CLR.Green)$($script:CLR.Bold)  [DONE]$($script:CLR.Reset)  $($pkg.post_install_msg)"
    Write-Host ""
    if ($result.PathsAdded -gt 0 -or $result.EnvsSet -gt 0) {
        Write-Host "$($script:CLR.Yellow)  [!] Open a new terminal window to load the updated PATH and ENV.$($script:CLR.Reset)"
        Write-Host ""
    }
    Write-Log "Install complete: $PackageName"
}

function Uninstall-WinPackage {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$PackageName)

    Assert-Winget
    Assert-Admin "Invoke-Win uninstall $PackageName"

    $pkg = Get-PackageDef $PackageName
    if (-not $pkg) { Write-Err "Unknown package: '$PackageName'"; exit 1 }

    Write-Info "Uninstalling $($pkg.display_name) via winget..."
    $exitCode = Invoke-WingetUninstall $pkg.winget_id

    if ($exitCode -eq 0) {
        Remove-InstalledPackage $PackageName
        Write-Ok "$($pkg.display_name) uninstalled."
        Write-Warn "Run 'win fix-path' to clean up any leftover PATH entries."
    } else {
        Write-Err "winget uninstall failed with exit code $exitCode"
    }
    Write-Log "Uninstall: $PackageName => exit $exitCode"
}

function Update-WinPackage {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$PackageName,
        [switch]$All
    )

    Assert-Winget
    Assert-Admin "Invoke-Win update $(if ($All) { '--all' } else { $PackageName })"

    if ($All) {
        Write-Info "Upgrading all packages via winget..."
        winget upgrade --all --accept-package-agreements --accept-source-agreements
        Write-Info "Re-applying PATH/ENV for all installed packages..."
        $installed = Get-InstalledRegistry
        foreach ($key in $installed.Keys) {
            $pkg = Get-PackageDef $key
            if ($pkg) {
                Write-Step "Re-configuring: $key"
                Apply-PackageEnvironment $key $pkg $false | Out-Null
            }
        }
        Broadcast-EnvironmentChange
        Write-Ok "All packages updated and environment refreshed."
        return
    }

    if (-not $PackageName) { Write-Err "Usage: win update <package>  OR  win update --all"; exit 1 }

    $pkg = Get-PackageDef $PackageName
    if (-not $pkg) { Write-Err "Unknown package: '$PackageName'"; exit 1 }

    Write-Info "Upgrading $($pkg.display_name)..."
    Invoke-WingetUpgrade $pkg.winget_id
    Apply-PackageEnvironment $PackageName $pkg $true | Out-Null
    Broadcast-EnvironmentChange
    Write-Ok "$($pkg.display_name) updated."
}

function Show-WinInstallList {
    $registry  = Get-PackageRegistry
    $installed = Get-InstalledRegistry

    # Group by category file
    $byCategory = @{}
    $files = Get-ChildItem -Path $script:PackagesDir -Filter "*.json" | Sort-Object Name
    foreach ($file in $files) {
        $data     = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $category = if ($data._category) { $data._category } else { $file.BaseName }
        $keys     = $data.PSObject.Properties.Name | Where-Object { -not $_.StartsWith("_") }
        $byCategory[$category] = $keys
    }

    Write-Host ""
    foreach ($category in ($byCategory.Keys | Sort-Object)) {
        Write-Host "$($script:CLR.Bold)$($script:CLR.White)  $category$($script:CLR.Reset)"
        Write-Host "$($script:CLR.Gray)  $('-' * 60)$($script:CLR.Reset)"

        foreach ($key in ($byCategory[$category] | Sort-Object)) {
            if (-not $registry.ContainsKey($key)) { continue }
            $pkg    = $registry[$key]
            $status = if ($installed.ContainsKey($key)) {
                "$($script:CLR.Green)[installed]$($script:CLR.Reset)"
            } else {
                "$($script:CLR.Gray)[available]$($script:CLR.Reset)"
            }
            $aliasStr = ""
            if ($pkg.aliases -and $pkg.aliases.Count -gt 0) {
                $aliasStr = "$($script:CLR.Gray)  aka: $($pkg.aliases -join ', ')$($script:CLR.Reset)"
            }
            Write-Host "  $($script:CLR.Cyan)$("{0,-18}" -f $key)$($script:CLR.Reset)$("{0,-26}" -f $pkg.display_name)$status$aliasStr"
        }
        Write-Host ""
    }
}

function Search-WinPackage {
    param([Parameter(Mandatory)][string]$Query)
    Assert-Winget
    Write-Info "Searching winget for: $Query"
    Write-Host ""
    winget search $Query
}

function Show-WinHelp {
    Write-Banner
    Write-Host "$($script:CLR.Bold)  USAGE$($script:CLR.Reset)"
    Write-Host "    $($script:CLR.Cyan)win install$($script:CLR.Reset) <package>          Install a package + auto PATH/ENV setup"
    Write-Host "    $($script:CLR.Cyan)win uninstall$($script:CLR.Reset) <package>        Uninstall a package"
    Write-Host "    $($script:CLR.Cyan)win update$($script:CLR.Reset) <package>           Upgrade a package"
    Write-Host "    $($script:CLR.Cyan)win update --all$($script:CLR.Reset)               Upgrade all packages"
    Write-Host "    $($script:CLR.Cyan)win list$($script:CLR.Reset)                       List all available packages"
    Write-Host "    $($script:CLR.Cyan)win search$($script:CLR.Reset) <query>             Search winget directly"
    Write-Host "    $($script:CLR.Cyan)win fix-path$($script:CLR.Reset)                   Audit and repair PATH/ENV"
    Write-Host "    $($script:CLR.Cyan)win fix-path --remove-dead$($script:CLR.Reset)     Also remove dead PATH entries"
    Write-Host "    $($script:CLR.Cyan)win help$($script:CLR.Reset)                       Show this help"
    Write-Host ""
    Write-Host "$($script:CLR.Bold)  EXAMPLES$($script:CLR.Reset)"
    Write-Host "    $($script:CLR.Gray)win install python$($script:CLR.Reset)"
    Write-Host "    $($script:CLR.Gray)win install java$($script:CLR.Reset)"
    Write-Host "    $($script:CLR.Gray)win install go$($script:CLR.Reset)"
    Write-Host "    $($script:CLR.Gray)win install docker$($script:CLR.Reset)"
    Write-Host "    $($script:CLR.Gray)win fix-path --remove-dead$($script:CLR.Reset)"
    Write-Host ""
    Show-WinInstallList
}

# -- Main dispatcher -----------------------------------------------------------

function Invoke-Win {
    param(
        [Parameter(Position = 0)][string]$Subcommand = "help",
        [Parameter(Position = 1)][string]$Package    = "",
        [switch]$All,
        [switch]$SkipInstall,
        [switch]$Force,
        [switch]$RemoveDeadEntries
    )

    switch ($Subcommand.ToLower()) {
        "install"    {
            if (-not $Package) { Write-Err "Usage: win install <package>"; return }
            Install-WinPackage -PackageName $Package -SkipInstall:$SkipInstall -Force:$Force
        }
        "uninstall"  {
            if (-not $Package) { Write-Err "Usage: win uninstall <package>"; return }
            Uninstall-WinPackage -PackageName $Package
        }
        "remove"     {
            if (-not $Package) { Write-Err "Usage: win remove <package>"; return }
            Uninstall-WinPackage -PackageName $Package
        }
        "update"     {
            if ($All)         { Update-WinPackage -All }
            elseif ($Package) { Update-WinPackage -PackageName $Package }
            else              { Write-Err "Usage: win update <package>  OR  win update --all" }
        }
        "upgrade"    {
            if ($All)         { Update-WinPackage -All }
            elseif ($Package) { Update-WinPackage -PackageName $Package }
            else              { Write-Err "Usage: win upgrade <package>  OR  win upgrade --all" }
        }
        "list"       { Show-WinInstallList }
        "search"     {
            if (-not $Package) { Write-Err "Usage: win search <query>"; return }
            Search-WinPackage -Query $Package
        }
        "fix-path"   { Repair-WinPath -RemoveDeadEntries:$RemoveDeadEntries }
        "fixpath"    { Repair-WinPath -RemoveDeadEntries:$RemoveDeadEntries }
        "help"       { Show-WinHelp }
        "--help"     { Show-WinHelp }
        "-h"         { Show-WinHelp }
        default      {
            Write-Err "Unknown subcommand: '$Subcommand'"
            Write-Host ""
            Write-Info "Did you mean:  win install $Subcommand ?"
            Write-Info "Run 'win help' to see all commands."
        }
    }
}

function Invoke-WinInstall { Invoke-Win @args }
