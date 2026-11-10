@echo off
REM ============================================================================
REM  Trinity Proxy Launcher — Auto-elevates to Administrator
REM  Just double-click this file. It handles everything.
REM ============================================================================

REM Check if already admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] Requesting Administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
    exit /b
)

REM We're admin now — run the proxy
cd /d "%~dp0"
echo.
echo ============================================================
echo   Starting Trinity Proxy (Administrator)
echo   Working directory: %CD%
echo ============================================================
echo.

REM Check if Python is available
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Python not found in PATH!
    echo [!] Install Python from python.org or Microsoft Store
    pause
    exit /b 1
)

REM Launch the proxy
python trinity_proxy.py --no-elevate

pause
