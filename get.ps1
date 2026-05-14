# ==============================================================================
#  WinInstall - Remote Bootstrap
#  Usage (paste in any PowerShell window):
#
#    irm https://raw.githubusercontent.com/its-dhaya/wininstall/main/get.ps1 | iex
#
# ==============================================================================

Set-StrictMode -Version Latest

$REPO_OWNER   = "its-dhaya"           # <-- change this
$REPO_NAME    = "wininstall"              # <-- change this if repo name differs
$BRANCH       = "main"
$BASE_URL     = "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/WinInstall"
$PACKAGES_URL = "$BASE_URL/packages"
$INSTALL_DIR  = Join-Path $env:APPDATA "WinInstall"
$MODULES_DIR  = ($env:PSModulePath -split ";") |
                    Where-Object { $_ -match [regex]::Escape($env:USERPROFILE) } |
                    Select-Object -First 1
if (-not $MODULES_DIR) {
    $MODULES_DIR = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules"
}
$MODULE_DEST  = Join-Path $MODULES_DIR "WinInstall"

# Files to download from WinInstall/
$MODULE_FILES = @(
    "WinInstall.psm1",
    "WinInstall.psd1",
    "Core.ps1",
    "Registry.ps1",
    "PathEnv.ps1",
    "Winget.ps1",
    "Commands.ps1"
)

# Package JSON files to download from WinInstall/packages/
$PACKAGE_FILES = @(
    "languages.json",
    "build-tools.json",
    "devops.json",
    "editors.json"
)

# -- Output helpers (no unicode, no ANSI - works everywhere) -------------------

function Print-Header {
    Write-Host ""
    Write-Host "  ================================================"
    Write-Host "   WinInstall - Windows Package Manager"
    Write-Host "   github.com/$REPO_OWNER/$REPO_NAME"
    Write-Host "  ================================================"
    Write-Host ""
}

function Print-Step  ([string]$msg) { Write-Host "  [....] $msg" }
function Print-Ok    ([string]$msg) { Write-Host "  [ OK ] $msg" }
function Print-Warn  ([string]$msg) { Write-Host "  [WARN] $msg" }
function Print-Fail  ([string]$msg) { Write-Host "  [FAIL] $msg" }
function Print-Info  ([string]$msg) { Write-Host "         $msg" }

# -- Download helper -----------------------------------------------------------

function Download-File ([string]$url, [string]$dest) {
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        Print-Fail "Failed to download: $url"
        Print-Info "Error: $_"
        return $false
    }
}

# -- Main install --------------------------------------------------------------

Print-Header

# Check internet
Print-Step "Checking connection to GitHub..."
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | Out-Null
    Print-Ok "GitHub is reachable."
} catch {
    Print-Fail "Cannot reach GitHub. Check your internet connection."
    exit 1
}

# Check winget
Print-Step "Checking winget..."
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Print-Ok "winget is available."
} else {
    Print-Warn "winget not found."
    Print-Info "Install 'App Installer' from the Microsoft Store:"
    Print-Info "https://aka.ms/getwinget"
    Print-Info "Then re-run this installer."
    exit 1
}

# Download module files
Print-Step "Downloading WinInstall module..."

if (Test-Path $MODULE_DEST) {
    Remove-Item $MODULE_DEST -Recurse -Force
}
New-Item -ItemType Directory -Path $MODULE_DEST -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $MODULE_DEST "packages") -Force | Out-Null

$failed = 0
foreach ($file in $MODULE_FILES) {
    $url  = "$BASE_URL/$file"
    $dest = Join-Path $MODULE_DEST $file
    if (-not (Download-File $url $dest)) { $failed++ }
}

foreach ($file in $PACKAGE_FILES) {
    $url  = "$PACKAGES_URL/$file"
    $dest = Join-Path $MODULE_DEST "packages\$file"
    if (-not (Download-File $url $dest)) { $failed++ }
}

if ($failed -gt 0) {
    Print-Fail "$failed file(s) failed to download. Check your connection and try again."
    exit 1
}
Print-Ok "All files downloaded."

# Unblock files
Print-Step "Unblocking downloaded files..."
try {
    Get-ChildItem -Path $MODULE_DEST -Recurse | Unblock-File -ErrorAction SilentlyContinue
    Print-Ok "Files unblocked."
} catch {
    Print-Warn "Unblock-File failed (non-critical)."
}

# Register in PowerShell profile
Print-Step "Registering 'win' command in PowerShell profile..."

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($profileContent -match "WinInstall") {
    $cleaned = $profileContent -replace "(?ms)# WinInstall.*?# ---[^\r\n]*[\r\n]*", ""
    Set-Content -Path $PROFILE -Value $cleaned.TrimEnd()
}

$importBlock = @"


# WinInstall - added by installer
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
Import-Module WinInstall -ErrorAction SilentlyContinue
Set-Alias -Name win -Value Invoke-Win -Scope Global -ErrorAction SilentlyContinue
# ---
"@

Add-Content -Path $PROFILE -Value $importBlock
Print-Ok "Registered in: $PROFILE"

# Load into current session
Print-Step "Loading WinInstall into current session..."
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Import-Module (Join-Path $MODULE_DEST "WinInstall.psd1") -Force -ErrorAction Stop
    Set-Alias -Name win -Value Invoke-Win -Scope Global
    Print-Ok "WinInstall loaded successfully."
} catch {
    Print-Warn "Could not load in current session: $_"
    Print-Warn "It will work in a new PowerShell window."
}

# Done
Write-Host ""
Write-Host "  ================================================"
Write-Host "   WinInstall is ready!"
Write-Host "  ================================================"
Write-Host ""
Write-Host "  Open a NEW PowerShell window and run:"
Write-Host ""
Write-Host "    win install python"
Write-Host "    win install java"
Write-Host "    win install go"
Write-Host "    win install node"
Write-Host "    win list"
Write-Host "    win help"
Write-Host ""
Write-Host "  Installed to: $MODULE_DEST"
Write-Host ""