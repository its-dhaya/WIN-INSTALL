# =============================================================================
#  Registry.ps1 - Tracks installed packages in %APPDATA%\WinInstall\
#  Part of WinInstall
# =============================================================================

$script:RegistryFile = Join-Path $env:APPDATA "WinInstall\installed.json"

function Get-InstalledRegistry {
    $regDir = Split-Path $script:RegistryFile -Parent
    if (-not (Test-Path $regDir)) { New-Item -ItemType Directory -Path $regDir -Force | Out-Null }
    if (-not (Test-Path $script:RegistryFile)) { return @{} }

    $raw = Get-Content $script:RegistryFile -Raw
    $obj = $raw | ConvertFrom-Json
    $ht  = @{}
    foreach ($prop in $obj.PSObject.Properties) { $ht[$prop.Name] = $prop.Value }
    return $ht
}

function Save-InstalledRegistry ([hashtable]$registry) {
    $registry | ConvertTo-Json -Depth 5 | Set-Content $script:RegistryFile
}

function Register-InstalledPackage ([string]$name, [object]$pkg, [string]$installDir) {
    $registry        = Get-InstalledRegistry
    $registry[$name] = @{
        display_name = $pkg.display_name
        winget_id    = $pkg.winget_id
        install_dir  = $installDir
        installed_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    Save-InstalledRegistry $registry
}

function Remove-InstalledPackage ([string]$name) {
    $registry = Get-InstalledRegistry
    if ($registry.ContainsKey($name)) {
        $registry.Remove($name)
        Save-InstalledRegistry $registry
    }
}
