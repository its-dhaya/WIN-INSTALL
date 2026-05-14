# =============================================================================
#  Core.ps1 - Shared helpers, logging, colours, and package registry loader
#  Part of WinInstall - https://github.com/yourname/wininstall
# =============================================================================

# PS 5.1-safe ANSI escape codes
$esc = [char]27
$script:CLR = @{
    Reset   = "$esc[0m"
    Bold    = "$esc[1m"
    Green   = "$esc[92m"
    Yellow  = "$esc[93m"
    Red     = "$esc[91m"
    Cyan    = "$esc[96m"
    Magenta = "$esc[95m"
    Gray    = "$esc[90m"
    White   = "$esc[97m"
}

$script:PackagesDir  = Join-Path $PSScriptRoot "packages"
$script:LogFile      = Join-Path $env:APPDATA "WinInstall\wininstall.log"

# -- Output helpers ------------------------------------------------------------

function Write-Banner {
    Write-Host ""
    Write-Host "$($script:CLR.Cyan)$($script:CLR.Bold)  WIN INSTALL$($script:CLR.Reset)"
    Write-Host "$($script:CLR.Gray)  Unified Windows Package Installer - PATH and ENV auto-configured$($script:CLR.Reset)"
    Write-Host ""
}

function Write-Info  ([string]$msg) { Write-Host "$($script:CLR.Cyan)[INFO]$($script:CLR.Reset)  $msg" }
function Write-Ok    ([string]$msg) { Write-Host "$($script:CLR.Green)[OK]$($script:CLR.Reset)    $msg" }
function Write-Warn  ([string]$msg) { Write-Host "$($script:CLR.Yellow)[WARN]$($script:CLR.Reset)  $msg" }
function Write-Err   ([string]$msg) { Write-Host "$($script:CLR.Red)[ERR]$($script:CLR.Reset)   $msg" }
function Write-Step  ([string]$msg) { Write-Host "$($script:CLR.Magenta)  >>$($script:CLR.Reset)  $msg" }
function Write-Gray  ([string]$msg) { Write-Host "$($script:CLR.Gray)  $msg$($script:CLR.Reset)" }

function Write-Log ([string]$message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logDir    = Split-Path $script:LogFile -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path $script:LogFile -Value "[$timestamp] $message"
}

# -- Package registry (merges all packages/*.json files) ----------------------

function Get-PackageRegistry {
    if (-not (Test-Path $script:PackagesDir)) {
        throw "Packages directory not found at: $script:PackagesDir"
    }

    $merged = @{}
    $files  = Get-ChildItem -Path $script:PackagesDir -Filter "*.json" | Sort-Object Name

    foreach ($file in $files) {
        $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
        foreach ($prop in $data.PSObject.Properties) {
            # Skip metadata keys (start with _)
            if ($prop.Name.StartsWith("_")) { continue }
            $merged[$prop.Name] = $prop.Value
        }
    }

    return $merged
}

function Get-PackageDef ([string]$name) {
    $registry = Get-PackageRegistry
    $lower    = $name.ToLower()

    # Direct name match
    if ($registry.ContainsKey($lower)) { return $registry[$lower] }

    # Alias match
    foreach ($key in $registry.Keys) {
        $pkg = $registry[$key]
        if ($pkg.aliases -and ($pkg.aliases -contains $lower)) {
            return $pkg
        }
    }

    return $null
}

# -- Admin check ---------------------------------------------------------------

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin ([string]$rerunCommand) {
    if (-not (Test-IsAdmin)) {
        Write-Warn "Admin rights are required to install software."
        Write-Host ""
        $answer = Read-Host "  Re-launch as Administrator? [Y/n]"
        if ($answer -eq "" -or $answer -match "^[Yy]") {
            $argList = "-ExecutionPolicy Bypass -Command `"Set-ExecutionPolicy Bypass -Scope Process -Force; Import-Module '$PSScriptRoot\WinInstall.psd1'; $rerunCommand`""
            Start-Process powershell -Verb RunAs -ArgumentList $argList
            Write-Info "Launched elevated window. Check the new PowerShell window."
            exit 0
        } else {
            Write-Err "Installation cancelled. Run PowerShell as Administrator to install."
            exit 1
        }
    }
}

# -- winget check --------------------------------------------------------------

function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Err "winget is not available on this system."
        Write-Info "Install 'App Installer' from the Microsoft Store:"
        Write-Info "https://aka.ms/getwinget"
        exit 1
    }
}
