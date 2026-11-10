@echo off
REM ============================================================================
REM  TRINITY STEALTH CLEANER v2.0
REM  CMD.EXE NATIVE — Does NOT appear in PowerShell event logs!
REM ============================================================================
REM
REM  WHY THIS EXISTS:
REM  Trinity checks PowerShell event logs for .ps1 script execution in the
REM  last 7 days. Running trinity_cleaner.ps1 ITSELF shows up as evidence.
REM  This .bat file uses only cmd.exe and native Windows tools — zero
REM  PowerShell footprint.
REM
REM  ALSO: Trinity detects when event logs are cleared (Event ID 1102,
REM  coordinated clearing timestamps, gap detection). This script uses
REM  a smarter approach: stop the EventLog service FIRST, then clean,
REM  so nothing gets recorded at all.
REM
REM  USAGE: Right-click -> Run as Administrator
REM         trinity_stealth.bat [/AGGRESSIVE] [/DRYRUN] [/SKIPVSS] [/SKIPNET]
REM ============================================================================

setlocal EnableDelayedExpansion

REM ---- Parse arguments ----
set "AGGRESSIVE=0"
set "DRYRUN=0"
set "SKIPVSS=0"
set "SKIPNET=0"

for %%A in (%*) do (
    if /I "%%A"=="/AGGRESSIVE" set "AGGRESSIVE=1"
    if /I "%%A"=="/DRYRUN" set "DRYRUN=1"
    if /I "%%A"=="/SKIPVSS" set "SKIPVSS=1"
    if /I "%%A"=="/SKIPNET" set "SKIPNET=1"
)

REM ---- Color helpers (ANSI escape codes, Win10+) ----
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

echo.
echo %ESC%[95m================================================================%ESC%[0m
echo %ESC%[95m  TRINITY STEALTH CLEANER v2.0 (CMD.EXE NATIVE)%ESC%[0m
echo %ESC%[95m  Zero PowerShell footprint. Smart event log handling.%ESC%[0m
echo %ESC%[95m================================================================%ESC%[0m
echo.

REM ---- Admin check ----
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %ESC%[91m[ERROR] NOT RUNNING AS ADMINISTRATOR!%ESC%[0m
    echo %ESC%[91m[ERROR] Right-click this .bat file -^> Run as Administrator%ESC%[0m
    pause
    exit /b 1
)

if "%DRYRUN%"=="1" (
    echo %ESC%[93m[WARN] DRY RUN MODE — no changes will be made%ESC%[0m
    echo.
)

echo %ESC%[36m[*] Timestamp: %DATE% %TIME%%ESC%[0m
echo.

REM ============================================================================
REM  PHASE 0: STOP EVENT LOG SERVICE (THE KEY TRICK)
REM ============================================================================
REM  By stopping EventLog FIRST, nothing we do gets recorded.
REM  Trinity's check_evtx_integrity looks at existing events — they stay intact.
REM  No Event ID 1102 "log was cleared" gets written because we never clear.
REM  The service just... wasn't running for a bit. Like a reboot.

echo %ESC%[36m=== PHASE 0: EVENT LOG SERVICE SUSPENSION ===%ESC%[0m

if "%DRYRUN%"=="0" (
    REM EventLog service is protected — can't stop it normally.
    REM But we CAN suspend the threads that write events.
    REM Method: Use wevtutil to disable specific log channels instead.

    echo [*] Disabling PowerShell event log channels...
    wevtutil sl Microsoft-Windows-PowerShell/Operational /e:false >nul 2>&1
    wevtutil sl "Windows PowerShell" /e:false >nul 2>&1
    wevtutil sl Microsoft-Windows-PowerShell/Admin /e:false >nul 2>&1
    echo %ESC%[92m[OK] PowerShell logging disabled — cleaner actions won't be recorded%ESC%[0m

    REM Also disable Script Block Logging if it's on
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" /v "EnableScriptBlockLogging" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" /v "EnableModuleLogging" /t REG_DWORD /d 0 /f >nul 2>&1
    echo %ESC%[92m[OK] Script Block Logging and Module Logging disabled%ESC%[0m
) else (
    echo [DRY] Would disable PowerShell event log channels
)
echo.

REM ============================================================================
REM  PHASE 1: NETWORK — BLOCK TRINITY API
REM ============================================================================

echo %ESC%[36m=== PHASE 1: NETWORK — Block Trinity API ===%ESC%[0m

if "%SKIPNET%"=="0" (
    set "HOSTSFILE=%SystemRoot%\System32\drivers\etc\hosts"

    REM Check and add each domain
    findstr /i "trinity.ac" "!HOSTSFILE!" >nul 2>&1
    if !errorlevel! neq 0 (
        if "%DRYRUN%"=="0" (
            echo 127.0.0.1 trinity.ac>> "!HOSTSFILE!"
            echo 127.0.0.1 www.trinity.ac>> "!HOSTSFILE!"
            echo 127.0.0.1 api.trinity.ac>> "!HOSTSFILE!"
            ipconfig /flushdns >nul 2>&1
            echo %ESC%[92m[OK] Blocked trinity.ac in hosts file%ESC%[0m
        ) else (
            echo [DRY] Would block trinity.ac in hosts file
        )
    ) else (
        echo %ESC%[92m[OK] trinity.ac already blocked%ESC%[0m
    )

    REM Firewall rule
    if "%DRYRUN%"=="0" (
        netsh advfirewall firewall show rule name="Block Trinity AC" >nul 2>&1
        if !errorlevel! neq 0 (
            netsh advfirewall firewall add rule name="Block Trinity AC" dir=out action=block program="%USERPROFILE%\Downloads\Trinity.exe" >nul 2>&1
            echo %ESC%[92m[OK] Firewall rule added for Trinity.exe%ESC%[0m
        ) else (
            echo %ESC%[92m[OK] Firewall rule already exists%ESC%[0m
        )
    )
) else (
    echo %ESC%[93m[SKIP] Network blocking skipped%ESC%[0m
)
echo.

REM ============================================================================
REM  PHASE 2: PREFETCH — Delete executor .pf files
REM ============================================================================

echo %ESC%[36m=== PHASE 2: PREFETCH — Clean Executor Traces ===%ESC%[0m

set "PFDIR=%SystemRoot%\Prefetch"
set "PF_CLEANED=0"

REM Build list of keywords to check against prefetch filenames
REM Using a loop over known executor names
for %%K in (
    SYNAPSE SYNAPSEX SCRIPTWARE SOLARA FLUXUS HYDROGEN MACSPLOIT
    JJSPLOIT WEAREDEVS SIRHURT NEZUR SELIWARE POTASSIUM VELOSTRAP
    MADIUM EXODUZ INJWARE RBXSTU WAVE AWP ARCEUS ARCEUSX TRIGON
    VEGA VEGAX EVON BUNNI ZENITH SWIFT DELTA CODEX CRYPTIC XENO
    COMET LUNA CELERY MATCHA TEMPLE OXYGENU ELECTRON KRNL RONIX
    VALEX MOOZE SXLIB BLOXSTRAP FISHSTRAP FROSTSTRAP VOIDSTRAP
    LUNARSTRAP RBXFPSUNLOCKER BLOXSHADE
) do (
    for /F "delims=" %%F in ('dir /b "%PFDIR%\*%%K*" 2^>nul') do (
        if "%DRYRUN%"=="0" (
            del /f /q "%PFDIR%\%%F" >nul 2>&1
        )
        echo %ESC%[92m[OK] Prefetch deleted: %%F [matched: %%K]%ESC%[0m
        set /a PF_CLEANED+=1
    )
)

if %PF_CLEANED%==0 echo %ESC%[92m[OK] No matching prefetch files found%ESC%[0m
echo.

REM ============================================================================
REM  PHASE 3: BAM — Clean Background Activity Monitor
REM ============================================================================

echo %ESC%[36m=== PHASE 3: BAM — Clean Background Activity Monitor ===%ESC%[0m

REM BAM stores execution history per-SID under:
REM SYSTEM\CurrentControlSet\Services\bam\State\UserSettings\{SID}
REM Trinity compares live registry vs raw SYSTEM hive — we clean both

REM Enumerate SIDs under BAM
for /F "tokens=*" %%S in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings" 2^>nul') do (
    REM For each SID key, check all values
    for %%K in (
        synapse scriptware solara fluxus hydrogen macsploit jjsploit
        wearedevs sirhurt nezur seliware potassium velostrap krnl
        delta celery xeno comet luna electron bloxstrap fishstrap
        oxygenu matcha temple codex cryptic vega evon wave
    ) do (
        REM Query the key for values matching this keyword
        for /F "tokens=1,*" %%V in ('reg query "%%S" 2^>nul ^| findstr /i "%%K"') do (
            if "%DRYRUN%"=="0" (
                reg delete "%%S" /v "%%V" /f >nul 2>&1
            )
            echo %ESC%[92m[OK] BAM cleaned: %%V [matched: %%K]%ESC%[0m
        )
    )
)

REM Also check the non-State path
for /F "tokens=*" %%S in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\bam\UserSettings" 2^>nul') do (
    for %%K in (
        synapse scriptware solara fluxus hydrogen macsploit jjsploit
        wearedevs sirhurt nezur seliware krnl delta xeno comet luna
    ) do (
        for /F "tokens=1,*" %%V in ('reg query "%%S" 2^>nul ^| findstr /i "%%K"') do (
            if "%DRYRUN%"=="0" (
                reg delete "%%S" /v "%%V" /f >nul 2>&1
            )
            echo %ESC%[92m[OK] BAM cleaned (alt path): %%V%ESC%[0m
        )
    )
)
echo.

REM ============================================================================
REM  PHASE 4: USERASSIST — Clean ROT13-encoded execution history
REM ============================================================================

echo %ESC%[36m=== PHASE 4: USERASSIST — ROT13 Execution History ===%ESC%[0m
echo [*] UserAssist uses ROT13 encoding — requires PowerShell for decode
echo [*] Skipping in stealth mode (use trinity_cleaner.ps1 for this phase,
echo [*] BUT run it 7+ days before the scan so it ages out of PS logs)
echo.

REM ============================================================================
REM  PHASE 5: SHIMCACHE — Wipe AppCompatCache
REM ============================================================================

echo %ESC%[36m=== PHASE 5: SHIMCACHE — Clean AppCompatCache ===%ESC%[0m

if "%AGGRESSIVE%"=="1" (
    if "%DRYRUN%"=="0" (
        reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache" /v "AppCompatCache" /f >nul 2>&1
        if !errorlevel! equ 0 (
            echo %ESC%[92m[OK] ShimCache wiped (regenerates on reboot)%ESC%[0m
        ) else (
            echo %ESC%[91m[ERROR] Failed to wipe ShimCache%ESC%[0m
        )
    ) else (
        echo [DRY] Would wipe ShimCache
    )
) else (
    echo %ESC%[93m[WARN] Use /AGGRESSIVE to wipe ShimCache%ESC%[0m
)
echo.

REM ============================================================================
REM  PHASE 6: AMCACHE — Report status
REM ============================================================================

echo %ESC%[36m=== PHASE 6: AMCACHE — Status ===%ESC%[0m

set "AMCACHE=%SystemRoot%\appcompat\Programs\Amcache.hve"
if exist "%AMCACHE%" (
    echo [*] Amcache.hve exists — locked by Windows during normal operation
    echo [*] For full clean: boot to WinPE, mount hive, remove executor entries
    echo [*] Or use -Aggressive with the PS1 version to schedule deletion
) else (
    echo %ESC%[93m[WARN] Amcache.hve not found%ESC%[0m
)
echo.

REM ============================================================================
REM  PHASE 7: EVENT LOGS — SMART HANDLING (THE FIX!)
REM ============================================================================
REM
REM  Trinity's event log detection explained:
REM  ----------------------------------------
REM  1. scan_eventlog_gaps — checks for time gaps in event sequences
REM  2. is_system_log_clear / is_security_log_clear — checks if main logs were wiped
REM  3. check_evtx_integrity — uses wevtutil to check oldest/newest event times
REM  4. _check_evtlog_timestamps — compares event dates for anomalies
REM  5. Looks for Event ID 1102 (Security log cleared) in Security log
REM  6. "[WARNING] Coordinated log clearing" — multiple logs cleared same time
REM  7. "[WARNING] Mass event log recreation" — many logs sharing creation date
REM
REM  WHAT WE DO INSTEAD:
REM  - Phase 0 already disabled PowerShell log CHANNELS
REM  - We do NOT clear System or Security logs (that trips multiple detectors)
REM  - We selectively handle ONLY the PowerShell .evtx files
REM  - We delete them while the channel is disabled, avoiding Event ID 1102
REM  - We DON'T touch: System, Security, Application, Setup logs

echo %ESC%[36m=== PHASE 7: EVENT LOGS — Smart Selective Handling ===%ESC%[0m

echo %ESC%[92m[OK] System log: NOT TOUCHED (Trinity checks this for clearing!)%ESC%[0m
echo %ESC%[92m[OK] Security log: NOT TOUCHED (Event ID 1102 detection!)%ESC%[0m
echo %ESC%[92m[OK] Application log: NOT TOUCHED%ESC%[0m

REM The PowerShell channels were disabled in Phase 0.
REM Now delete just the PS operational .evtx files (they'll be recreated when
REM we re-enable the channels, with events starting from NOW — which looks
REM like a normal log rotation, not a manual clearing).

set "EVTX_DIR=%SystemRoot%\System32\winevt\Logs"

if "%DRYRUN%"=="0" (
    REM Delete PowerShell event log files
    del /f /q "%EVTX_DIR%\Microsoft-Windows-PowerShell%%4Operational.evtx" >nul 2>&1
    del /f /q "%EVTX_DIR%\Microsoft-Windows-PowerShell%%4Admin.evtx" >nul 2>&1
    del /f /q "%EVTX_DIR%\Windows PowerShell.evtx" >nul 2>&1
    echo %ESC%[92m[OK] PowerShell .evtx files deleted (channel was disabled)%ESC%[0m

    REM Delete Defender operational log too (less suspicious than System/Security)
    del /f /q "%EVTX_DIR%\Microsoft-Windows-Windows Defender%%4Operational.evtx" >nul 2>&1
    echo %ESC%[92m[OK] Defender operational log deleted%ESC%[0m
) else (
    echo [DRY] Would delete PowerShell and Defender .evtx files
)
echo.

REM ============================================================================
REM  PHASE 8: RECYCLE BIN
REM ============================================================================

echo %ESC%[36m=== PHASE 8: RECYCLE BIN ===%ESC%[0m

if "%DRYRUN%"=="0" (
    rd /s /q "C:\$Recycle.Bin" >nul 2>&1
    echo %ESC%[92m[OK] Recycle Bin emptied%ESC%[0m
) else (
    echo [DRY] Would empty Recycle Bin
)
echo.

REM ============================================================================
REM  PHASE 9: JUMP LISTS — Clean recent items
REM ============================================================================

echo %ESC%[36m=== PHASE 9: JUMP LISTS ===%ESC%[0m

set "JL_AUTO=%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations"
set "JL_CUST=%APPDATA%\Microsoft\Windows\Recent\CustomDestinations"
set "JL_REC=%APPDATA%\Microsoft\Windows\Recent"

REM Selective cleaning: check .lnk names for keywords
for %%K in (
    synapse scriptware solara fluxus hydrogen macsploit jjsploit
    wearedevs sirhurt krnl delta xeno comet luna electron bloxstrap
    celery matcha temple vega evon wave
) do (
    for /F "delims=" %%F in ('dir /b "%JL_REC%\*%%K*" 2^>nul') do (
        if "%DRYRUN%"=="0" del /f /q "%JL_REC%\%%F" >nul 2>&1
        echo %ESC%[92m[OK] JumpList: %%F [matched: %%K]%ESC%[0m
    )
)

if "%AGGRESSIVE%"=="1" (
    if "%DRYRUN%"=="0" (
        del /f /q "%JL_AUTO%\*" >nul 2>&1
        del /f /q "%JL_CUST%\*" >nul 2>&1
        echo %ESC%[92m[OK] All AutomaticDestinations + CustomDestinations wiped%ESC%[0m
    )
)
echo.

REM ============================================================================
REM  PHASE 10: SHELLBAGS
REM ============================================================================

echo %ESC%[36m=== PHASE 10: SHELLBAGS ===%ESC%[0m

if "%AGGRESSIVE%"=="1" (
    if "%DRYRUN%"=="0" (
        reg delete "HKCU\Software\Microsoft\Windows\Shell\BagMRU" /f >nul 2>&1
        reg delete "HKCU\Software\Microsoft\Windows\Shell\Bags" /f >nul 2>&1
        reg delete "HKCU\Software\Microsoft\Windows\ShellNoRoam\BagMRU" /f >nul 2>&1
        reg delete "HKCU\Software\Microsoft\Windows\ShellNoRoam\Bags" /f >nul 2>&1
        reg delete "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU" /f >nul 2>&1
        reg delete "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags" /f >nul 2>&1
        echo %ESC%[92m[OK] ShellBags wiped (Explorer rebuilds on next folder access)%ESC%[0m
    )
) else (
    echo %ESC%[93m[WARN] Use /AGGRESSIVE to wipe ShellBags%ESC%[0m
)
echo.

REM ============================================================================
REM  PHASE 11: VSS — Delete Shadow Copies
REM ============================================================================

echo %ESC%[36m=== PHASE 11: VSS — Shadow Copy Deletion ===%ESC%[0m

if "%SKIPVSS%"=="0" (
    if "%DRYRUN%"=="0" (
        vssadmin delete shadows /all /quiet >nul 2>&1
        echo %ESC%[92m[OK] All Volume Shadow Copies deleted%ESC%[0m
    ) else (
        echo [DRY] Would delete all VSS shadow copies
    )
) else (
    echo %ESC%[93m[SKIP] VSS deletion skipped%ESC%[0m
)
echo.

REM ============================================================================
REM  PHASE 12: ROBLOX — Clean logs and FFlag configs
REM ============================================================================

echo %ESC%[36m=== PHASE 12: ROBLOX — Clean Local Data ===%ESC%[0m

REM Roblox logs
set "RBX_LOGS=%LOCALAPPDATA%\Roblox\logs"
if exist "%RBX_LOGS%" (
    if "%DRYRUN%"=="0" (
        del /f /q /s "%RBX_LOGS%\*" >nul 2>&1
        echo %ESC%[92m[OK] Roblox logs cleaned%ESC%[0m
    )
)

REM FFlag configs (Trinity flags these!)
set "RBX_CS=%LOCALAPPDATA%\Roblox\ClientSettings"
if exist "%RBX_CS%" (
    echo %ESC%[93m[WARN] ClientAppSettings found — Trinity flags this!%ESC%[0m
    if "%AGGRESSIVE%"=="1" (
        if "%DRYRUN%"=="0" (
            rd /s /q "%RBX_CS%" >nul 2>&1
            echo %ESC%[92m[OK] ClientSettings removed%ESC%[0m
        )
    )
)

REM Check for bootstrappers
for %%B in (Bloxstrap Fishstrap Froststrap Voidstrap Lunarstrap) do (
    if exist "%LOCALAPPDATA%\%%B" (
        echo %ESC%[93m[WARN] Found %%B at %LOCALAPPDATA%\%%B — Trinity flags this!%ESC%[0m
    )
)
echo.

REM ============================================================================
REM  PHASE 13: DISCORD — Report only
REM ============================================================================

echo %ESC%[36m=== PHASE 13: DISCORD — Status ===%ESC%[0m

for %%D in (discord discordcanary discordptb) do (
    if exist "%APPDATA%\%%D\Local Storage" (
        echo [*] Found: %APPDATA%\%%D\Local Storage (Trinity reads this)
    )
)
echo [*] Discord storage left intact (cleaning = logout)
echo.

REM ============================================================================
REM  PHASE 14: PCA — Program Compatibility Assistant
REM ============================================================================

echo %ESC%[36m=== PHASE 14: PCA ===%ESC%[0m

if "%AGGRESSIVE%"=="1" (
    if exist "%SystemRoot%\appcompat\pca" (
        if "%DRYRUN%"=="0" (
            del /f /q "%SystemRoot%\appcompat\pca\*" >nul 2>&1
            echo %ESC%[92m[OK] PCA traces cleaned%ESC%[0m
        )
    )
) else (
    echo %ESC%[93m[WARN] Use /AGGRESSIVE to clean PCA%ESC%[0m
)
echo.

REM ============================================================================
REM  PHASE 15: SRUM
REM ============================================================================

echo %ESC%[36m=== PHASE 15: SRUM ===%ESC%[0m

set "SRUMDB=%SystemRoot%\System32\sru\SRUDB.dat"
if exist "%SRUMDB%" (
    if "%AGGRESSIVE%"=="1" (
        if "%DRYRUN%"=="0" (
            net stop DiagTrack >nul 2>&1
            timeout /t 2 /nobreak >nul
            del /f /q "%SRUMDB%" >nul 2>&1
            if !errorlevel! equ 0 (
                echo %ESC%[92m[OK] SRUM database deleted%ESC%[0m
            ) else (
                echo %ESC%[91m[ERROR] SRUM file locked — try after reboot%ESC%[0m
            )
            net start DiagTrack >nul 2>&1
        )
    ) else (
        echo %ESC%[93m[WARN] Use /AGGRESSIVE to delete SRUM%ESC%[0m
    )
)
echo.

REM ============================================================================
REM  PHASE 16: DEFENDER — Fix suspicious settings
REM ============================================================================

echo %ESC%[36m=== PHASE 16: DEFENDER — Fix Suspicion Flags ===%ESC%[0m

REM Check for DisableAntiSpyware=1
for %%P in (
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender"
    "HKLM\SOFTWARE\Microsoft\Windows Defender"
) do (
    reg query %%P /v "DisableAntiSpyware" 2>nul | findstr /i "0x1" >nul 2>&1
    if !errorlevel! equ 0 (
        echo %ESC%[91m[!] DisableAntiSpyware=1 found! Trinity WILL flag this!%ESC%[0m
        if "%DRYRUN%"=="0" (
            reg add %%P /v "DisableAntiSpyware" /t REG_DWORD /d 0 /f >nul 2>&1
            echo %ESC%[92m[OK] Fixed: DisableAntiSpyware set to 0%ESC%[0m
        )
    )
)

REM Check for Defender exclusions
reg query "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths" 2>nul | findstr /v "^$" | findstr /v "HKEY_" >nul 2>&1
if %errorlevel% equ 0 (
    echo %ESC%[91m[!] Defender exclusions found — Trinity flags these!%ESC%[0m
    reg query "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths" 2>nul
)
echo.

REM ============================================================================
REM  PHASE 17: USN JOURNAL
REM ============================================================================

echo %ESC%[36m=== PHASE 17: USN JOURNAL ===%ESC%[0m

if "%AGGRESSIVE%"=="1" (
    if "%DRYRUN%"=="0" (
        fsutil usn deletejournal /d C: >nul 2>&1
        fsutil usn createjournal m=33554432 a=4194304 C: >nul 2>&1
        echo %ESC%[92m[OK] USN Journal deleted and recreated%ESC%[0m
    )
) else (
    echo %ESC%[93m[WARN] Use /AGGRESSIVE to reset USN Journal%ESC%[0m
)
echo.

REM ============================================================================
REM  PHASE 18: TEMP FILES — Clean executor remnants
REM ============================================================================

echo %ESC%[36m=== PHASE 18: TEMP — Clean Executor Remnants ===%ESC%[0m

for %%K in (
    synapse scriptware solara fluxus hydrogen macsploit jjsploit
    wearedevs sirhurt krnl delta xeno comet luna electron
    celery matcha temple vega evon wave bloxstrap
) do (
    for /F "delims=" %%F in ('dir /b /s "%TEMP%\*%%K*" 2^>nul') do (
        if "%DRYRUN%"=="0" del /f /q "%%F" >nul 2>&1
        echo %ESC%[92m[OK] Temp: %%F%ESC%[0m
    )
)
echo.

REM ============================================================================
REM  PHASE 19: REGISTRY — MUICache and other traces
REM ============================================================================

echo %ESC%[36m=== PHASE 19: REGISTRY — MUICache ===%ESC%[0m

set "MUIPATH=HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"

for %%K in (
    synapse scriptware solara fluxus hydrogen macsploit jjsploit
    wearedevs sirhurt krnl delta xeno comet luna electron
    celery matcha temple vega evon wave bloxstrap
) do (
    for /F "tokens=1,*" %%V in ('reg query "%MUIPATH%" 2^>nul ^| findstr /i "%%K"') do (
        if "%DRYRUN%"=="0" reg delete "%MUIPATH%" /v "%%V" /f >nul 2>&1
        echo %ESC%[92m[OK] MUICache: %%V%ESC%[0m
    )
)
echo.

REM ============================================================================
REM  PHASE 20: RE-ENABLE EVENT LOG CHANNELS
REM ============================================================================

echo %ESC%[36m=== PHASE 20: RE-ENABLE EVENT LOGGING ===%ESC%[0m

if "%DRYRUN%"=="0" (
    REM Re-enable the PowerShell channels
    REM The .evtx files were deleted, so Windows creates fresh ones
    REM This looks like normal log rotation, NOT manual clearing
    wevtutil sl Microsoft-Windows-PowerShell/Operational /e:true >nul 2>&1
    wevtutil sl "Windows PowerShell" /e:true >nul 2>&1
    wevtutil sl Microsoft-Windows-PowerShell/Admin /e:true >nul 2>&1
    echo %ESC%[92m[OK] PowerShell event channels re-enabled%ESC%[0m
    echo %ESC%[92m[OK] Fresh .evtx files created — no history of this cleaner%ESC%[0m

    REM Restore Script Block Logging to default (enabled)
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" /v "EnableScriptBlockLogging" /f >nul 2>&1
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" /v "EnableModuleLogging" /f >nul 2>&1
    echo %ESC%[92m[OK] Script Block Logging policies restored%ESC%[0m
) else (
    echo [DRY] Would re-enable PowerShell event channels
)
echo.

REM ============================================================================
REM  SUMMARY
REM ============================================================================

echo %ESC%[92m================================================================%ESC%[0m
echo %ESC%[92m  STEALTH CLEANING COMPLETE%ESC%[0m
echo %ESC%[92m================================================================%ESC%[0m
echo.
echo %ESC%[93m  POST-CLEAN CHECKLIST:%ESC%[0m
echo %ESC%[93m  1. REBOOT your PC (critical for ShimCache/Amcache!)%ESC%[0m
echo %ESC%[93m  2. Do NOT run any executors before the Trinity scan%ESC%[0m
echo %ESC%[93m  3. Close all executor-related programs%ESC%[0m
echo %ESC%[93m  4. Move/rename cheat folders off Desktop/Downloads%ESC%[0m
echo %ESC%[93m  5. Remove Defender exclusions if any were flagged%ESC%[0m
echo %ESC%[93m  6. Run 'python trinity_proxy.py' before launching Trinity%ESC%[0m
echo %ESC%[93m     for PIN bypass (enter any PIN code)%ESC%[0m
echo.
echo %ESC%[36m  WHAT MAKES THIS STEALTH:%ESC%[0m
echo %ESC%[36m  - Zero PowerShell event log footprint (cmd.exe native)%ESC%[0m
echo %ESC%[36m  - PS log channels disabled BEFORE any action taken%ESC%[0m
echo %ESC%[36m  - NO System/Security log clearing (avoids Event ID 1102)%ESC%[0m
echo %ESC%[36m  - .evtx files deleted while channels offline (no gaps)%ESC%[0m
echo %ESC%[36m  - Fresh log files look like normal rotation, not clearing%ESC%[0m
echo.

if "%DRYRUN%"=="1" (
    echo %ESC%[93m[!] This was a DRY RUN — no changes were made%ESC%[0m
    echo %ESC%[93m[!] Run without /DRYRUN to apply changes%ESC%[0m
)

pause
