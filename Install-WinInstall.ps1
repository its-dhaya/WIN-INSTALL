# ==============================================================================
#  WinInstall Bootstrap
#  Run via: setup.bat  (recommended - double-click)
# ==============================================================================

Set-StrictMode -Version Latest

function Write-Step ([string]$n, [string]$msg) { Write-Host "[$n] $msg" }
function Write-Ok   ([string]$msg) { Write-Host "  [OK]   $msg" }
function Write-Fail ([string]$msg) { Write-Host "  [ERR]  $msg" }
function Write-Warn ([string]$msg) { Write-Host "  [WARN] $msg" }

Write-Host ""
Write-Host "  WinInstall v2 Setup"
Write-Host "  ---------------------------------"
Write-Host ""

# -- Step 1: Locate source folder ----------------------------------------------
$sourceDir = Join-Path $PSScriptRoot "WinInstall"
if (-not (Test-Path $sourceDir)) {
    Write-Fail "WinInstall folder not found at: $sourceDir"
    Write-Host "  Make sure setup.bat is in the same folder as the WinInstall folder."
    exit 1
}

# -- Step 2: Find PowerShell modules directory ---------------------------------
Write-Step "1/5" "Locating PowerShell module directory..."

$modulesRoot = ($env:PSModulePath -split ";") |
    Where-Object { $_ -match [regex]::Escape($env:USERPROFILE) } |
    Select-Object -First 1

if (-not $modulesRoot) {
    $modulesRoot = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules"
}

$destDir = Join-Path $modulesRoot "WinInstall"
Write-Ok "Target: $destDir"

# -- Step 3: Copy module files -------------------------------------------------
Write-Step "2/5" "Copying module files..."
try {
    if (Test-Path $destDir) { Remove-Item $destDir -Recurse -Force }
    Copy-Item -Path $sourceDir -Destination $destDir -Recurse -Force
    Write-Ok "Module copied successfully."
} catch {
    Write-Fail "Failed to copy module: $_"
    exit 1
}

# -- Step 4: Unblock all files (removes 'downloaded from internet' flag) -------
Write-Step "3/5" "Unblocking module files..."
try {
    Get-ChildItem -Path $destDir -Recurse | Unblock-File -ErrorAction SilentlyContinue
    Write-Ok "All files unblocked."
} catch {
    Write-Warn "Unblock-File failed (non-critical): $_"
}

# -- Step 5: Register 'win' alias in PowerShell profile -----------------------
Write-Step "4/5" "Registering 'win' command in PowerShell profile..."

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Ok "Created new PowerShell profile: $PROFILE"
}

# Remove old block cleanly before rewriting
$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($profileContent -match "WinInstall") {
    $cleaned = $profileContent -replace "(?ms)# WinInstall.*?# ---[^\r\n]*[\r\n]*", ""
    Set-Content -Path $PROFILE -Value $cleaned.TrimEnd()
}

$importBlock = @"


# WinInstall - added by setup
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
Import-Module WinInstall -ErrorAction SilentlyContinue
Set-Alias -Name win -Value Invoke-Win -Scope Global -ErrorAction SilentlyContinue
# ---
"@

Add-Content -Path $PROFILE -Value $importBlock
Write-Ok "Registered 'win' command in: $PROFILE"

# -- Step 6: Load into current session ----------------------------------------
Write-Step "5/5" "Loading WinInstall into current session..."
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Import-Module (Join-Path $destDir "WinInstall.psd1") -Force -ErrorAction Stop
    Set-Alias -Name win -Value Invoke-Win -Scope Global
    Write-Ok "WinInstall is active in this session."
} catch {
    Write-Warn "Could not load in current session: $_"
    Write-Warn "Open a new PowerShell window - it will work there."
}

# -- Done ----------------------------------------------------------------------
Write-Host ""
Write-Host "  [DONE] WinInstall is ready!"
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
