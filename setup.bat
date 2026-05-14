@echo off
title WinInstall Setup

echo.
echo  ==================================================
echo   WinInstall - Setting up the 'win' command...
echo  ==================================================
echo.

where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo  [ERROR] PowerShell not found.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-WinInstall.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo  [ERROR] Setup encountered an issue. See output above.
    pause
    exit /b 1
)

echo.
echo  ================================================
echo   Done! Open a NEW PowerShell window and run:
echo.
echo     win install python
echo     win install java
echo     win install go
echo     win list
echo  ================================================
echo.
pause
