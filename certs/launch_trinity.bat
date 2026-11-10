@echo off
REM ============================================================================
REM  TRINITY LAUNCHER — Complete PIN Bypass + Result Interception
REM  Just right-click -> Run as Administrator. Handles everything.
REM ============================================================================

setlocal EnableDelayedExpansion

REM ---- Color setup ----
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

echo.
echo %ESC%[95m================================================================%ESC%[0m
echo %ESC%[95m  TRINITY BYPASS LAUNCHER v2.0%ESC%[0m
echo %ESC%[95m  One-click PIN bypass + result interception%ESC%[0m
echo %ESC%[95m================================================================%ESC%[0m
echo.

REM ---- Admin check ----
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %ESC%[93m[*] Requesting Administrator privileges...%ESC%[0m
    powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs -WorkingDirectory '%~dp0'"
    exit /b
)

REM ---- Find Trinity.exe ----
set "TRINITY_EXE="

if not "%~1"=="" if exist "%~1" set "TRINITY_EXE=%~1"
if defined TRINITY_EXE goto :found_trinity

if exist "%USERPROFILE%\Downloads\Trinity.exe" set "TRINITY_EXE=%USERPROFILE%\Downloads\Trinity.exe"
if defined TRINITY_EXE goto :found_trinity

if exist "%USERPROFILE%\Desktop\Trinity.exe" set "TRINITY_EXE=%USERPROFILE%\Desktop\Trinity.exe"
if defined TRINITY_EXE goto :found_trinity

if exist "%~dp0..\Trinity.exe" set "TRINITY_EXE=%~dp0..\Trinity.exe"
if defined TRINITY_EXE goto :found_trinity

if exist "%~dp0Trinity.exe" set "TRINITY_EXE=%~dp0Trinity.exe"
if defined TRINITY_EXE goto :found_trinity

echo %ESC%[91m[!] Trinity.exe not found in common locations!%ESC%[0m
set /p "TRINITY_EXE=Path to Trinity.exe: "
if not exist "!TRINITY_EXE!" (
    echo %ESC%[91m[!] File not found: !TRINITY_EXE!%ESC%[0m
    pause
    exit /b 1
)

:found_trinity
echo %ESC%[92m[+] Found Trinity: !TRINITY_EXE!%ESC%[0m
echo.

REM ---- Setup paths ----
set "SCRIPT_DIR=%~dp0"
set "CERT_DIR=%SCRIPT_DIR%certs"
set "CERT_FILE=%CERT_DIR%\trinity.pem"
set "COMBINED_BUNDLE=%CERT_DIR%\combined_ca_bundle.pem"

REM ============================================================================
REM  STEP 1: Certificate
REM ============================================================================
echo %ESC%[36m[STEP 1/5] Certificate Setup%ESC%[0m

if not exist "%CERT_FILE%" (
    echo [*] Cert not found, generating...
    python "%SCRIPT_DIR%trinity_proxy.py" --no-elevate 2>nul
)
if not exist "%CERT_FILE%" (
    echo %ESC%[91m[!] Certificate generation failed. Run trinity_proxy.py manually first.%ESC%[0m
    pause
    exit /b 1
)
echo %ESC%[92m[+] Certificate: %CERT_FILE%%ESC%[0m

REM ============================================================================
REM  STEP 2: Combined CA Bundle
REM ============================================================================
REM  Trinity's Nuitka-bundled requests lib uses certifi's CA store.
REM  Our self-signed cert isn't in it -> SSLError -> "Unable to transmit"
REM  Fix: combine real CAs + our cert into one bundle file.
echo.
echo %ESC%[36m[STEP 2/5] Creating Combined CA Bundle%ESC%[0m

python "%SCRIPT_DIR%make_bundle.py"

if not exist "%COMBINED_BUNDLE%" (
    echo [!] Python bundle creation failed, copying cert directly
    copy /y "%CERT_FILE%" "%COMBINED_BUNDLE%" >nul 2>&1
)
echo %ESC%[92m[+] CA Bundle: %COMBINED_BUNDLE%%ESC%[0m

REM Also install to Windows trusted root store
certutil -addstore Root "%CERT_FILE%" >nul 2>&1
echo %ESC%[92m[+] Cert added to Windows Trusted Root store%ESC%[0m

REM ============================================================================
REM  STEP 3: SSL Environment
REM ============================================================================
echo.
echo %ESC%[36m[STEP 3/5] Setting SSL Environment%ESC%[0m

set "REQUESTS_CA_BUNDLE=%COMBINED_BUNDLE%"
set "SSL_CERT_FILE=%COMBINED_BUNDLE%"
set "CURL_CA_BUNDLE=%COMBINED_BUNDLE%"
echo %ESC%[92m[+] REQUESTS_CA_BUNDLE = %COMBINED_BUNDLE%%ESC%[0m

REM ============================================================================
REM  STEP 4: Network Redirect + Proxy
REM ============================================================================
echo.
echo %ESC%[36m[STEP 4/5] Network Redirect + Proxy%ESC%[0m

set "HOSTSFILE=%SystemRoot%\System32\drivers\etc\hosts"
findstr /i "trinity.ac" "%HOSTSFILE%" >nul 2>&1
if !errorlevel! neq 0 (
    echo 127.0.0.1 trinity.ac>> "%HOSTSFILE%"
    echo 127.0.0.1 www.trinity.ac>> "%HOSTSFILE%"
    echo 127.0.0.1 api.trinity.ac>> "%HOSTSFILE%"
    ipconfig /flushdns >nul 2>&1
    echo %ESC%[92m[+] Hosts: trinity.ac -^> 127.0.0.1%ESC%[0m
) else (
    echo %ESC%[92m[+] Hosts entries already present%ESC%[0m
)

REM Start the proxy in background
echo [*] Starting proxy server...
start "Trinity Proxy" /min cmd /c "cd /d "%SCRIPT_DIR%" & python trinity_proxy.py --no-elevate"

REM Wait for proxy to bind
echo [*] Waiting for proxy to start...
timeout /t 4 /nobreak >nul

REM Check if proxy is up
netstat -an 2>nul | findstr "LISTENING" | findstr ":443 " >nul 2>&1
if !errorlevel! equ 0 (
    echo %ESC%[92m[+] Proxy listening on port 443%ESC%[0m
) else (
    echo %ESC%[93m[!] Proxy may not be on 443 — check the proxy window%ESC%[0m
    echo %ESC%[93m[!] Continuing anyway...%ESC%[0m
)

REM ============================================================================
REM  STEP 5: Launch Trinity
REM ============================================================================
echo.
echo %ESC%[36m[STEP 5/5] Launching Trinity%ESC%[0m
echo.
echo %ESC%[92m========================================%ESC%[0m
echo %ESC%[92m  READY! Trinity is starting.%ESC%[0m
echo %ESC%[92m  Enter ANY PIN -- it will be accepted.%ESC%[0m
echo %ESC%[92m  Results intercepted and saved locally.%ESC%[0m
echo %ESC%[92m========================================%ESC%[0m
echo.

start "" /wait "!TRINITY_EXE!"

REM ============================================================================
REM  CLEANUP
REM ============================================================================
echo.
echo %ESC%[36m[*] Trinity closed. Cleaning up...%ESC%[0m

taskkill /fi "WINDOWTITLE eq Trinity Proxy" /f >nul 2>&1
netsh interface portproxy delete v4tov4 listenport=443 listenaddress=127.0.0.1 >nul 2>&1

echo %ESC%[92m[+] Proxy stopped%ESC%[0m
echo.
echo %ESC%[93m  Hosts entries still active. To remove:%ESC%[0m
echo %ESC%[93m    python trinity_proxy.py --restore%ESC%[0m
echo %ESC%[93m  Intercepted data in: %SCRIPT_DIR%proxy_logs\%ESC%[0m
echo.

pause
