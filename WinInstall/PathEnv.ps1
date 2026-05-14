# =============================================================================
#  PathEnv.ps1 - PATH and environment variable management
#  Part of WinInstall
# =============================================================================

function Expand-EnvPath ([string]$path) {
    return [System.Environment]::ExpandEnvironmentVariables($path)
}

function Get-CurrentUserPath {
    $p = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($null -eq $p) { return "" }
    return $p
}

function Get-CurrentMachinePath {
    $p = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($null -eq $p) { return "" }
    return $p
}

function Add-ToUserPath ([string]$newPath) {
    $newPath = Expand-EnvPath $newPath
    if (-not (Test-Path $newPath -PathType Container)) {
        Write-Warn "Path does not exist (skipping): $newPath"
        return $false
    }

    $currentPath = Get-CurrentUserPath
    $pathList    = $currentPath -split ";" | Where-Object { $_ -ne "" }

    $exists = $pathList | Where-Object { $_.TrimEnd("\") -ieq $newPath.TrimEnd("\") }
    if ($exists) {
        Write-Gray "Already in PATH: $newPath"
        return $false
    }

    $pathList  += $newPath
    $newPathStr = ($pathList | Where-Object { $_ -ne "" }) -join ";"
    [System.Environment]::SetEnvironmentVariable("PATH", $newPathStr, "User")
    $env:PATH   = "$env:PATH;$newPath"

    Write-Ok "Added to PATH: $newPath"
    Write-Log "PATH += $newPath"
    return $true
}

function Set-UserEnvVar ([string]$name, [string]$value) {
    $value   = Expand-EnvPath $value
    $current = [System.Environment]::GetEnvironmentVariable($name, "User")
    if ($current -ieq $value) {
        Write-Gray "$name already set correctly"
        return
    }
    [System.Environment]::SetEnvironmentVariable($name, $value, "User")
    [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
    Write-Ok "Set $name = $value"
    Write-Log "ENV: $name = $value"
}

function Broadcast-EnvironmentChange {
    # Notifies Explorer and other processes that env vars changed - no reboot needed
    try {
        $code = @"
using System;
using System.Runtime.InteropServices;
public class WinEnvBroadcast {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam,
        string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        $result = [UIntPtr]::Zero
        [WinEnvBroadcast]::SendMessageTimeout(
            [IntPtr]0xffff, 0x001A, [UIntPtr]::Zero,
            "Environment", 0x0002, 5000, [ref]$result
        ) | Out-Null
    } catch { }
}

function Resolve-InstallDir ([object]$pkg) {
    foreach ($hint in $pkg.install_dir_hints) {
        $expanded = Expand-EnvPath $hint

        if ($expanded -match '\*') {
            $parent  = Split-Path $expanded -Parent
            $pattern = Split-Path $expanded -Leaf
            if (Test-Path $parent) {
                $found = Get-ChildItem -Path $parent -Filter $pattern -Directory -ErrorAction SilentlyContinue |
                         Sort-Object Name -Descending | Select-Object -First 1
                if ($found) { return $found.FullName }
            }
        } elseif (Test-Path $expanded) {
            return $expanded
        }
    }
    return $null
}

function Apply-PackageEnvironment ([string]$pkgName, [object]$pkg, [bool]$verbose) {
    $installDir = Resolve-InstallDir $pkg

    if ($verbose) {
        if ($installDir) {
            Write-Step "Detected install dir: $installDir"
        } else {
            Write-Warn "Could not auto-detect install directory. Using hint defaults."
            $installDir = ""
        }
    }

    $pathsAdded = 0
    $envsSet    = 0

    if ($verbose) { Write-Info "Configuring PATH entries..." }
    foreach ($rawPath in $pkg.path_additions) {
        $resolvedPath = $rawPath -replace '\{install_dir\}', $installDir
        $resolvedPath = Expand-EnvPath $resolvedPath
        if (Add-ToUserPath $resolvedPath) { $pathsAdded++ }
    }

    $envProps = @($pkg.env_vars.PSObject.Properties)
    if ($envProps.Count -gt 0) {
        if ($verbose) { Write-Info "Configuring environment variables..." }
        foreach ($prop in $envProps) {
            $varValue = $prop.Value -replace '\{install_dir\}', $installDir
            $varValue = Expand-EnvPath $varValue
            Set-UserEnvVar $prop.Name $varValue
            $envsSet++
        }
    }

    Broadcast-EnvironmentChange

    $dirToSave = if ($installDir) { $installDir } else { "unknown" }
    Register-InstalledPackage $pkgName $pkg $dirToSave

    return @{ PathsAdded = $pathsAdded; EnvsSet = $envsSet }
}

function Repair-WinPath {
    [CmdletBinding()]
    param([switch]$RemoveDeadEntries)

    Write-Info "Scanning PATH for issues..."
    $userPath    = Get-CurrentUserPath
    $machinePath = Get-CurrentMachinePath
    $allPaths    = ($userPath -split ";") + ($machinePath -split ";") | Where-Object { $_ -ne "" }

    $dead  = @()
    $alive = @()

    foreach ($p in $allPaths) {
        $expanded = Expand-EnvPath $p
        if (Test-Path $expanded) { $alive += $p }
        else                     { $dead  += $p }
    }

    Write-Host ""
    Write-Host "$($script:CLR.Green)  Active PATH entries ($($alive.Count)):$($script:CLR.Reset)"
    $alive | ForEach-Object { Write-Gray "[OK] $_" }

    if ($dead.Count -gt 0) {
        Write-Host ""
        Write-Host "$($script:CLR.Red)  Dead PATH entries ($($dead.Count)):$($script:CLR.Reset)"
        $dead | ForEach-Object { Write-Warn "[X] $_" }

        if ($RemoveDeadEntries) {
            Write-Info "Removing dead entries from User PATH..."
            $cleanPath = ($userPath -split ";" | Where-Object {
                $_ -ne "" -and (Test-Path (Expand-EnvPath $_))
            }) -join ";"
            [System.Environment]::SetEnvironmentVariable("PATH", $cleanPath, "User")
            Broadcast-EnvironmentChange
            Write-Ok "Dead entries removed from User PATH."
        } else {
            Write-Warn "Run 'win fix-path --remove-dead' to remove them."
        }
    } else {
        Write-Ok "No dead PATH entries found!"
    }

    Write-Host ""
    Write-Info "Re-applying PATH/ENV for all installed packages..."
    $installed = Get-InstalledRegistry
    if ($installed.Count -eq 0) {
        Write-Gray "No packages tracked by win-install yet."
    } else {
        foreach ($key in $installed.Keys) {
            $pkg = Get-PackageDef $key
            if ($pkg) {
                Write-Step "Re-checking: $key"
                Apply-PackageEnvironment $key $pkg $false | Out-Null
            }
        }
        Broadcast-EnvironmentChange
        Write-Ok "Environment refreshed for all tracked packages."
    }
}
