# =============================================================================
#  Winget.ps1 - winget invocation wrappers with retry and error handling
#  Part of WinInstall
# =============================================================================

function Invoke-WingetInstall ([string]$wingetId) {
    Write-Step "winget install --id $wingetId --accept-package-agreements --accept-source-agreements"
    Write-Host ""
    winget install --id $wingetId `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity `
        2>&1
    return $LASTEXITCODE
}

function Invoke-WingetUninstall ([string]$wingetId) {
    Write-Step "winget uninstall --id $wingetId"
    winget uninstall --id $wingetId 2>&1
    return $LASTEXITCODE
}

function Invoke-WingetUpgrade ([string]$wingetId) {
    Write-Step "winget upgrade --id $wingetId --accept-package-agreements"
    winget upgrade --id $wingetId `
        --accept-package-agreements `
        --accept-source-agreements `
        2>&1
    return $LASTEXITCODE
}

function Resolve-WingetExitCode ([int]$exitCode, [string]$wingetId) {
    # Returns: 'ok', 'already_installed', 'retry', 'warn'
    switch ($exitCode) {
        0            { return 'ok' }
        -1978335189  { return 'already_installed' }   # APPINSTALLER_ERROR_PACKAGE_ALREADY_INSTALLED
        1618         { return 'retry' }               # ERROR_INSTALL_ALREADY_RUNNING
        -1978335140  { return 'ok' }                  # Installer succeeded (some packages return this)
        default      { return 'warn' }
    }
}

function Install-ViaWinget ([string]$wingetId) {
    Write-Info "Installing via winget..."
    $exitCode = Invoke-WingetInstall $wingetId
    Write-Host ""

    $status = Resolve-WingetExitCode $exitCode $wingetId

    switch ($status) {
        'ok'               { Write-Ok "winget installation completed." }
        'already_installed'{ Write-Ok "Already installed. Proceeding to fix PATH/ENV..." }
        'retry' {
            Write-Warn "Another installer is running (code 1618)."
            Write-Host ""
            $answer = Read-Host "  Wait 15 seconds and retry? [Y/n]"
            if ($answer -eq "" -or $answer -match "^[Yy]") {
                Write-Info "Waiting 15 seconds..."
                Start-Sleep -Seconds 15
                Write-Info "Retrying..."
                $exitCode = Invoke-WingetInstall $wingetId
                if ($exitCode -eq 0) {
                    Write-Ok "winget installation completed on retry."
                } else {
                    Write-Warn "winget exited with code $exitCode. Proceeding anyway..."
                }
            } else {
                Write-Warn "Skipped. Proceeding with PATH/ENV setup only..."
            }
        }
        default { Write-Warn "winget exited with code $exitCode. Proceeding with PATH/ENV setup..." }
    }

    Write-Log "winget install $wingetId => exit $exitCode"
}
