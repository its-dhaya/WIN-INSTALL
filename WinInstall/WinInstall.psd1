@{
    ModuleVersion     = '2.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'WinInstall'
    Description       = 'Unified Windows Package Installer with automatic PATH and ENV management'
    PowerShellVersion = '5.1'
    RootModule        = 'WinInstall.psm1'
    FunctionsToExport = @(
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
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('win')
    PrivateData       = @{
        PSData = @{
            Tags = @('Windows', 'PackageManager', 'PATH', 'Installer', 'winget')
        }
    }
}
