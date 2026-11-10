@echo off
setlocal EnableDelayedExpansion
title PC Check — Trinity Vector Replica
color 0E

:: ═══════════════════════════════════════════════════════════
::  Replicates every forensic vector Trinity.exe scans
::  Run as Administrator for full results
:: ═══════════════════════════════════════════════════════════

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Not admin — results will be incomplete
    echo.
)

set "TOTAL_HITS=0"
set "TOTAL_CLEAN=0"
set "LOG=%~dp0pc_check_results.txt"

:: ── timestamp ──
echo ═══════════════════════════════════════════════════════════ > "%LOG%"
echo   PC CHECK — %date% %time% >> "%LOG%"
echo ═══════════════════════════════════════════════════════════ >> "%LOG%"
echo. >> "%LOG%"

echo.
echo  ╔═══════════════════════════════════════════════════╗
echo  ║        PC CHECK — TRINITY VECTOR REPLICA          ║
echo  ║   12 forensic checks, same as the real thing      ║
echo  ╚═══════════════════════════════════════════════════╝
echo.

:: ══════════════════════════════════════════════════════
::  KEYWORD BANKS
::  all keywords in single findstr chains for speed
:: ══════════════════════════════════════════════════════

:: executor + tool keywords (one findstr pass)
set "EXEC_FILTER=/i /c:"synapse" /c:"scriptware" /c:"script-ware" /c:"solara" /c:"fluxus" /c:"hydrogen" /c:"macsploit" /c:"jjsploit" /c:"wearedevs" /c:"sirhurt" /c:"nezur" /c:"seliware" /c:"potassium" /c:"velostrap" /c:"madium" /c:"exoduz" /c:"injware" /c:"rbxstu" /c:"robloxplayerexecutor" /c:"wave executor" /c:"awp" /c:"arceus" /c:"trigon" /c:"vega x" /c:"evon executor" /c:"bunni" /c:"zenith" /c:"delta executor" /c:"codex executor" /c:"cryptic" /c:"xeno" /c:"comet executor" /c:"luna" /c:"celery" /c:"matcha" /c:"temple" /c:"oxygen u" /c:"electron exploit" /c:"krnl" /c:"ronix" /c:"valex" /c:"mooze" /c:"sxlib" /c:"OpXOyuApWKTlFzrV""

:: rot13 encoded versions for userassist
set "ROT13_FILTER=/i /c:"flaNCfr" /c:"fpevcgjner" /c:"fbyben" /c:"syhkhf" /c:"ulqebtra" /c:"wwfcybvg" /c:"jrnerirf" /c:"fveuheg" /c:"armhe" /c:"fryvjner" /c:"cbgnffvhz" /c:"irybnfgenc" /c:"xeay" /c:"kkrab" /c:"BcKBlhNcJXGySmej""

:: UNC API signatures trinity searches in logs + memory
set "UNC_FILTER=/i /c:"getrawmetatable" /c:"setrawmetatable" /c:"hookmetamethod" /c:"hookfunction" /c:"getnamecallmethod" /c:"checkcaller" /c:"getthreadidentity" /c:"getsenv" /c:"getrenv" /c:"getgenv" /c:"getreg" /c:"getgc" /c:"firesignal" /c:"newcclosure" /c:"identifyexecutor" /c:"saveinstance" /c:"setclipboard" /c:"queue_on_teleport" /c:"synapse-api""

:: fflag / bootstrapper keywords
set "FFLAG_FILTER=/i /c:"bloxstrap" /c:"fishstrap" /c:"froststrap" /c:"voidstrap" /c:"lunarstrap" /c:"rbxfpsunlocker" /c:"fps-unlocker" /c:"bloxshade" /c:"ClientAppSettings""


:: ══════════════════════════════════════════════════════
::  [1/12] PREFETCH — PECmd.exe parses .pf files
:: ══════════════════════════════════════════════════════
echo [1/12] Prefetch ^(PECmd vector^)...
echo [PREFETCH] >> "%LOG%"
set "PHASE_HITS=0"
if exist "%SystemRoot%\Prefetch" (
    for /f "delims=" %%F in ('dir /b "%SystemRoot%\Prefetch\*.pf" 2^>nul ^| findstr %EXEC_FILTER%') do (
        echo   [HIT] %%F
        echo   [HIT] %%F >> "%LOG%"
        set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
    )
)
if !PHASE_HITS! equ 0 ( echo   [CLEAN] & echo   [CLEAN] >> "%LOG%" & set /a TOTAL_CLEAN+=1 )
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [2/12] BAM — live registry entries
::  trinity also compares live vs raw SYSTEM hive
::  (can't do raw hive comparison in bat — live only)
:: ══════════════════════════════════════════════════════
echo [2/12] BAM ^(Background Activity Monitor^)...
echo [BAM] >> "%LOG%"
set "PHASE_HITS=0"
for %%S in (
    "HKLM\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    "HKLM\SYSTEM\CurrentControlSet\Services\bam\UserSettings"
) do (
    for /f "delims=" %%L in ('reg query %%S /s 2^>nul ^| findstr /i /c:"\Device\" ^| findstr %EXEC_FILTER%') do (
        echo   [HIT] %%L
        echo   [HIT] %%L >> "%LOG%"
        set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
    )
)
:: bam integrity — check if bam service is running
sc query bam 2>nul | findstr /i "RUNNING" >nul 2>&1
if !errorlevel! neq 0 (
    echo   [WARN] BAM service not running — trinity flags this
    echo   [WARN] BAM service not running >> "%LOG%"
)
if !PHASE_HITS! equ 0 ( echo   [CLEAN] & echo   [CLEAN] >> "%LOG%" & set /a TOTAL_CLEAN+=1 )
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [3/12] USERASSIST — ROT13-encoded execution history
::  bat can only match pre-computed rot13 strings
:: ══════════════════════════════════════════════════════
echo [3/12] UserAssist ^(ROT13 encoded^)...
echo [USERASSIST] >> "%LOG%"
set "PHASE_HITS=0"
for /f "delims=" %%L in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist" /s 2^>nul ^| findstr %ROT13_FILTER%') do (
    echo   [HIT] %%L
    echo   [HIT] %%L >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
)
if !PHASE_HITS! equ 0 ( echo   [CLEAN] ^(partial — ROT13 limits bat^) & echo   [CLEAN] (partial) >> "%LOG%" & set /a TOTAL_CLEAN+=1 )
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [4/12] SHIMCACHE — AppCompatCacheParser.exe
::  can't parse the binary blob in bat, check if it exists
:: ══════════════════════════════════════════════════════
echo [4/12] ShimCache ^(AppCompatCache^)...
echo [SHIMCACHE] >> "%LOG%"
set "PHASE_HITS=0"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache" /v AppCompatCache >nul 2>&1
if !errorlevel! equ 0 (
    echo   [INFO] ShimCache present — trinity parses this binary blob
    echo   [INFO] ShimCache present (binary, can't parse in bat) >> "%LOG%"
) else (
    echo   [CLEAN] ShimCache wiped
    echo   [CLEAN] ShimCache wiped >> "%LOG%"
)
set /a TOTAL_CLEAN+=1
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [5/12] AMCACHE — checks modification time + size
:: ══════════════════════════════════════════════════════
echo [5/12] Amcache...
echo [AMCACHE] >> "%LOG%"
set "AMCACHE_PATH=%SystemRoot%\AppCompat\Programs\Amcache.hve"
if exist "%AMCACHE_PATH%" (
    for %%F in ("%AMCACHE_PATH%") do (
        echo   [INFO] Amcache.hve exists — size: %%~zF bytes, modified: %%~tF
        echo   [INFO] size=%%~zF modified=%%~tF >> "%LOG%"
    )
    echo   [INFO] Trinity checks if recently modified or suspiciously small
    echo   [INFO] Locked by Windows — can't parse or clean without WinPE >> "%LOG%"
) else (
    echo   [WARN] Amcache.hve missing — trinity flags this
    echo   [WARN] Amcache.hve missing >> "%LOG%"
    set /a TOTAL_HITS+=1
)
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [6/12] EVENT LOGS — gap detection + clearing evidence
:: ══════════════════════════════════════════════════════
echo [6/12] Event Logs ^(gaps + clearing^)...
echo [EVENT LOGS] >> "%LOG%"
set "PHASE_HITS=0"

:: check for log clearing evidence (Event ID 1102)
wevtutil qe "Security" /c:30 /f:text /rd:true 2>nul | findstr /c:"1102" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [HIT] Event ID 1102 — log clearing detected
    echo   [HIT] Event ID 1102 >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
)

:: check for PS script execution (trinity checks last 7 days)
wevtutil qe "Windows PowerShell" /c:100 /f:text /rd:true 2>nul | findstr /i /c:".ps1" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [HIT] .ps1 execution in PowerShell event log
    echo   [HIT] .ps1 execution found >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
)
wevtutil qe "Microsoft-Windows-PowerShell/Operational" /c:100 /f:text /rd:true 2>nul | findstr /i /c:".ps1" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [HIT] .ps1 execution in PS Operational log
    echo   [HIT] .ps1 in PS Operational >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
)

:: check if PS logs are empty/missing (trinity flags this too)
wevtutil gli "Windows PowerShell" 2>nul | findstr /i /c:"numberOfLogRecords: 0" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [WARN] PowerShell log is empty — trinity may flag as cleared
    echo   [WARN] PS log empty >> "%LOG%"
)

if !PHASE_HITS! equ 0 ( echo   [CLEAN] & echo   [CLEAN] >> "%LOG%" & set /a TOTAL_CLEAN+=1 )
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [7/12] SRUM — SrumECmd.exe parses SRUDB.dat
:: ══════════════════════════════════════════════════════
echo [7/12] SRUM...
echo [SRUM] >> "%LOG%"
if exist "%SystemRoot%\System32\sru\SRUDB.dat" (
    for %%F in ("%SystemRoot%\System32\sru\SRUDB.dat") do (
        echo   [INFO] SRUDB.dat exists — size: %%~zF bytes
        echo   [INFO] SRUDB.dat size=%%~zF >> "%LOG%"
    )
    echo   [INFO] Trinity parses this for app execution history
) else (
    echo   [CLEAN] SRUDB.dat missing — was deleted
    echo   [CLEAN] SRUDB.dat deleted >> "%LOG%"
)
set /a TOTAL_CLEAN+=1
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [8/12] VSS — mounts shadow copies and re-scans
:: ══════════════════════════════════════════════════════
echo [8/12] Volume Shadow Copies...
echo [VSS] >> "%LOG%"
set "PHASE_HITS=0"
set "VSS_COUNT=0"
for /f "tokens=*" %%L in ('vssadmin list shadows 2^>nul ^| findstr /i /c:"Shadow Copy Volume"') do (
    set /a VSS_COUNT+=1
)
if !VSS_COUNT! gtr 0 (
    echo   [HIT] !VSS_COUNT! shadow copy^(ies^) exist — trinity mounts and re-scans these
    echo   [HIT] !VSS_COUNT! shadow copies >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
) else (
    echo   [CLEAN] No shadow copies
    echo   [CLEAN] >> "%LOG%"
    set /a TOTAL_CLEAN+=1
)
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [9/12] SHELLBAGS — SBECmd.exe folder history
:: ══════════════════════════════════════════════════════
echo [9/12] ShellBags...
echo [SHELLBAGS] >> "%LOG%"
set "PHASE_HITS=0"
set "SB_EXISTS=0"
reg query "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU" >nul 2>&1
if !errorlevel! equ 0 set "SB_EXISTS=1"
reg query "HKCU\Software\Microsoft\Windows\Shell\BagMRU" >nul 2>&1
if !errorlevel! equ 0 set "SB_EXISTS=1"
if !SB_EXISTS! equ 1 (
    echo   [INFO] ShellBags present — trinity parses these for folder navigation
    echo   [INFO] ShellBags present (binary, can't keyword-scan in bat) >> "%LOG%"
) else (
    echo   [CLEAN] ShellBags wiped
    echo   [CLEAN] ShellBags wiped >> "%LOG%"
)
set /a TOTAL_CLEAN+=1
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [10/12] JUMP LISTS — JLECmd.exe recent/pinned
:: ══════════════════════════════════════════════════════
echo [10/12] Jump Lists ^& Recent...
echo [JUMP LISTS] >> "%LOG%"
set "PHASE_HITS=0"
for /f "delims=" %%F in ('dir /b "%APPDATA%\Microsoft\Windows\Recent\*" 2^>nul ^| findstr %EXEC_FILTER%') do (
    echo   [HIT] %%F
    echo   [HIT] %%F >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
)
if !PHASE_HITS! equ 0 ( echo   [CLEAN] & echo   [CLEAN] >> "%LOG%" & set /a TOTAL_CLEAN+=1 )
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [11/12] RECYCLE BIN — deleted file traces
:: ══════════════════════════════════════════════════════
echo [11/12] Recycle Bin...
echo [RECYCLE BIN] >> "%LOG%"
set "PHASE_HITS=0"
for /f "delims=" %%F in ('dir /s /b "C:\$Recycle.Bin" 2^>nul ^| findstr %EXEC_FILTER%') do (
    echo   [HIT] %%~nxF
    echo   [HIT] %%~nxF >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
)
if !PHASE_HITS! equ 0 ( echo   [CLEAN] & echo   [CLEAN] >> "%LOG%" & set /a TOTAL_CLEAN+=1 )
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  [12/12] ROBLOX + FFLAGS + REGISTRY + DEFENDER
::  (secondary vectors trinity also checks)
:: ══════════════════════════════════════════════════════
echo [12/12] Roblox ^& secondary vectors...
echo [SECONDARY] >> "%LOG%"
set "PHASE_HITS=0"

:: roblox logs — keyword + UNC API scan
if exist "%LOCALAPPDATA%\Roblox\logs" (
    for %%F in ("%LOCALAPPDATA%\Roblox\logs\*.log") do (
        findstr %EXEC_FILTER% "%%F" >nul 2>&1
        if !errorlevel! equ 0 (
            echo   [HIT] %%~nxF ^(executor keyword^)
            echo   [HIT] %%~nxF (keyword) >> "%LOG%"
            set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
        ) else (
            findstr %UNC_FILTER% "%%F" >nul 2>&1
            if !errorlevel! equ 0 (
                echo   [HIT] %%~nxF ^(UNC API^)
                echo   [HIT] %%~nxF (UNC API) >> "%LOG%"
                set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
            )
        )
    )
)

:: fflags — ClientAppSettings in roblox versions
for /d %%V in ("%LOCALAPPDATA%\Roblox\Versions\*") do (
    if exist "%%V\ClientSettings\ClientAppSettings.json" (
        echo   [HIT] ClientAppSettings.json in %%~nxV
        echo   [HIT] ClientAppSettings.json >> "%LOG%"
        set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
    )
)

:: bootstrapper folders
for %%B in (bloxstrap fishstrap froststrap voidstrap lunarstrap) do (
    if exist "%LOCALAPPDATA%\%%B" (
        echo   [HIT] %%B installed
        echo   [HIT] %%B folder >> "%LOG%"
        set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
    )
)

:: registry — MUICache + FeatureUsage
for %%K in (
    "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppLaunch"
) do (
    for /f "delims=" %%L in ('reg query %%K 2^>nul ^| findstr %EXEC_FILTER%') do (
        echo   [HIT] %%L
        echo   [HIT] %%L >> "%LOG%"
        set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
    )
)

:: defender status
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware 2>nul | findstr /c:"0x1" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [HIT] Defender disabled via registry
    echo   [HIT] Defender disabled >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
)

:: defender exclusions
for /f "delims=" %%E in ('reg query "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths" 2^>nul ^| findstr %EXEC_FILTER%') do (
    echo   [HIT] Defender exclusion: %%E
    echo   [HIT] Defender exclusion >> "%LOG%"
    set /a PHASE_HITS+=1 & set /a TOTAL_HITS+=1
)

if !PHASE_HITS! equ 0 ( echo   [CLEAN] & echo   [CLEAN] >> "%LOG%" & set /a TOTAL_CLEAN+=1 )
echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  INTEGRITY CHECKS (what trinity uses to detect cleaning)
:: ══════════════════════════════════════════════════════
echo.
echo  ── INTEGRITY CHECKS ──
echo. >> "%LOG%"
echo [INTEGRITY] >> "%LOG%"

:: prefetch count vs install age
set "PF_COUNT=0"
for %%F in ("%SystemRoot%\Prefetch\*.pf") do set /a PF_COUNT+=1
if !PF_COUNT! lss 40 (
    echo   [WARN] Only !PF_COUNT! prefetch files — trinity flags low count as "CLEARED"
    echo   [WARN] Prefetch count low: !PF_COUNT! >> "%LOG%"
) else (
    echo   [OK] !PF_COUNT! prefetch files — normal range
    echo   [OK] Prefetch count: !PF_COUNT! >> "%LOG%"
)

:: bam entry count
set "BAM_COUNT=0"
for /f "delims=" %%L in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings" /s 2^>nul ^| findstr /i /c:"\Device\"') do set /a BAM_COUNT+=1
if !BAM_COUNT! lss 5 (
    echo   [WARN] Only !BAM_COUNT! BAM entries — trinity flags low count
    echo   [WARN] BAM count low: !BAM_COUNT! >> "%LOG%"
) else (
    echo   [OK] !BAM_COUNT! BAM entries — normal
    echo   [OK] BAM count: !BAM_COUNT! >> "%LOG%"
)

echo. >> "%LOG%"

:: ══════════════════════════════════════════════════════
::  RESULTS
:: ══════════════════════════════════════════════════════
echo.
echo ═══════════════════════════════════════════════════════════
echo. >> "%LOG%"

if !TOTAL_HITS! equ 0 (
    color 0A
    echo   [PASSED] All 12 vector checks clean
    echo   [PASSED] Clean >> "%LOG%"
) else (
    color 0C
    echo   [FAILED] !TOTAL_HITS! detection^(s^) across 12 vectors
    echo   [FAILED] !TOTAL_HITS! detections >> "%LOG%"
)

echo.
echo ═══════════════════════════════════════════════════════════
echo   Results saved: %LOG%
echo ═══════════════════════════════════════════════════════════
echo   Scan completed %date% %time% >> "%LOG%"
echo.
pause
endlocal
