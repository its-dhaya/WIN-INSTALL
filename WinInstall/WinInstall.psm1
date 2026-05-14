# =============================================================================
#  WinInstall.psm1 - Root module loader
#  Dot-sources all component files in dependency order.
#  To add new functionality, add a new .ps1 file and dot-source it here.
# =============================================================================

. "$PSScriptRoot\Core.ps1"
. "$PSScriptRoot\Registry.ps1"
. "$PSScriptRoot\PathEnv.ps1"
. "$PSScriptRoot\Winget.ps1"
. "$PSScriptRoot\Commands.ps1"

Export-ModuleMember -Function @(
    'Invoke-Win',
    'Invoke-WinInstall',
    'Install-WinPackage',
    'Uninstall-WinPackage',
    'Update-WinPackage',
    'Repair-WinPath',
    'Show-WinInstallList',
    'Search-WinPackage',
    'Show-WinHelp'
)
