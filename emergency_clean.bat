@echo off
setlocal EnableDelayedExpansion
title EMERGENCY CLEAN
color 0C

:: ═══════════════════════════════════════════════════════════
::  Emergency cleaner — nuke everything, force restart
::  Deletes itself when done
:: ═══════════════════════════════════════════════════════════

:: admin check + auto-elevate
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting admin...
    powershell -Command "Start-Process '%~f0' -Verb RunAs" 2>nul
    if %errorlevel% neq 0 (
        echo [!] Need admin. Right-click ^> Run as administrator.
        pause
        exit /b 1
    )
    exit /b 0
)

echo.
echo  ╔═══════════════════════════════════════════════════╗
echo  ║         EMERGENCY CLEAN — FULL NUKE              ║
echo  ╚═══════════════════════════════════════════════════╝
echo.

:: ── keyword block ──
set "KW[0]=synapse"
set "KW[1]=scriptware"
set "KW[2]=script-ware"
set "KW[3]=solara"
set "KW[4]=fluxus"
set "KW[5]=hydrogen"
set "KW[6]=macsploit"
set "KW[7]=jjsploit"
set "KW[8]=wearedevs"
set "KW[9]=sirhurt"
set "KW[10]=nezur"
set "KW[11]=seliware"
set "KW[12]=potassium"
set "KW[13]=velostrap"
set "KW[14]=madium"
set "KW[15]=exoduz"
set "KW[16]=injware"
set "KW[17]=rbxstu"
set "KW[18]=robloxplayerexecutor"
set "KW[19]=wave executor"
set "KW[20]=awp"
set "KW[21]=arceus"
set "KW[22]=trigon"
set "KW[23]=vega"
set "KW[24]=evon"
set "KW[25]=bunni"
set "KW[26]=zenith"
set "KW[27]=swift"
set "KW[28]=delta executor"
set "KW[29]=codex"
set "KW[30]=cryptic"
set "KW[31]=xeno"
set "KW[32]=comet"
set "KW[33]=luna"
set "KW[34]=celery"
set "KW[35]=matcha"
set "KW[36]=temple"
set "KW[37]=oxygen"
set "KW[38]=electron"
set "KW[39]=krnl"
set "KW[40]=ronix"
set "KW[41]=valex"
set "KW[42]=mooze"
set "KW[43]=sxlib"
set "KW[44]=OpXOyuApWKTlFzrV"
set "KW[45]=bloxstrap"
set "KW[46]=fishstrap"
set "KW[47]=froststrap"
set "KW[48]=voidstrap"
set "KW[49]=lunarstrap"
set "KW[50]=rbxfpsunlocker"
set "KW[51]=fps-unlocker"
set "KW[52]=bloxshade"
set "KW[53]=trinity_bypass"
set "KW[54]=trinity_stealth"
set "KW[55]=trinity_cleaner"
set "KW[56]=trinity_proxy"
set "KW[57]=trinity_report"
set "KW[58]=launch_trinity"
set "KW[59]=launch_proxy"
set "KW[60]=make_bundle"
set "KW[61]=pc_check"
set "KW[62]=emergency_clean"
set "KW_MAX=62"

:: ══════════════════════════════════════════════════════
::  PHASE 0 — DISABLE PS EVENT LOG CHANNELS
:: ══════════════════════════════════════════════════════
echo [0] Disabling PS event log channels...
wevtutil sl "Windows PowerShell" /e:false >nul 2>&1
wevtutil sl "Microsoft-Windows-PowerShell/Operational" /e:false >nul 2>&1
wevtutil sl "Microsoft-Windows-PowerShell/Analytic" /e:false >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 1 — KILL THE EXACT BAM ENTRIES (your hits)
:: ══════════════════════════════════════════════════════
echo [1] Nuking BAM entries...
for %%S in (
    "HKLM\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    "HKLM\SYSTEM\CurrentControlSet\Services\bam\UserSettings"
) do (
    for /f "tokens=*" %%K in ('reg query %%S /s 2^>nul ^| findstr /i /c:"HKEY_"') do (
        set "SUBKEY=%%K"
        for /f "tokens=1,*" %%A in ('reg query "!SUBKEY!" /s 2^>nul ^| findstr /i /c:"\Device\"') do (
            set "VALNAME=%%A"
            for /L %%i in (0,1,%KW_MAX%) do (
                echo !VALNAME! | findstr /i /c:"!KW[%%i]!" >nul 2>&1
                if !errorlevel! equ 0 (
                    reg delete "!SUBKEY!" /v "!VALNAME!" /f >nul 2>&1
                    echo   deleted: !VALNAME!
                )
            )
        )
    )
)
:: also nuke the exact paths from the scan
for %%S in (
    "HKLM\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    "HKLM\SYSTEM\CurrentControlSet\Services\bam\UserSettings"
) do (
    for /f "tokens=*" %%K in ('reg query %%S /s 2^>nul ^| findstr /i /c:"HKEY_"') do (
        for /f "tokens=1,*" %%A in ('reg query "%%K" 2^>nul ^| findstr /i /c:"OpXOyuApWKTlFzrV" /c:"Potassium" /c:"potassium"') do (
            reg delete "%%K" /v "%%A" /f >nul 2>&1
            echo   force deleted: %%A
        )
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 2 — PREFETCH
:: ══════════════════════════════════════════════════════
echo [2] Cleaning Prefetch...
if exist "%SystemRoot%\Prefetch" (
    for /L %%i in (0,1,%KW_MAX%) do (
        for %%F in ("%SystemRoot%\Prefetch\*!KW[%%i]!*.pf") do (
            del /f /q "%%F" >nul 2>&1
            echo   deleted: %%~nxF
        )
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 3 — USERASSIST (ROT13)
:: ══════════════════════════════════════════════════════
echo [3] Cleaning UserAssist (ROT13 patterns)...
for %%S in (
    "flaNCfr" "fpevcgjner" "fbyben" "syhkhf" "ulqebtra" "wwfcybvg"
    "jrnerirf" "fveuheg" "armhe" "fryvjner" "cbgnffvhz" "irybnfgenc"
    "xeay" "kkrab" "BcKBlhNcJXGySmej"
) do (
    for /f "tokens=*" %%K in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist" /s 2^>nul ^| findstr /i /c:"HKEY_"') do (
        for /f "tokens=1,*" %%A in ('reg query "%%K" 2^>nul ^| findstr /i /c:%%S') do (
            reg delete "%%K" /v "%%A" /f >nul 2>&1
            echo   deleted ROT13 entry: %%A
        )
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 4 — SHIMCACHE (wipe it)
:: ══════════════════════════════════════════════════════
echo [4] Wiping ShimCache...
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache" /v AppCompatCache /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatibility" /v AppCompatCache /f >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 5 — JUMP LISTS / RECENT
:: ══════════════════════════════════════════════════════
echo [5] Cleaning Jump Lists / Recent...
for %%D in (
    "%APPDATA%\Microsoft\Windows\Recent"
    "%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations"
    "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations"
) do (
    if exist "%%~D" (
        for /L %%i in (0,1,%KW_MAX%) do (
            for %%F in ("%%~D\*!KW[%%i]!*") do (
                del /f /q "%%F" >nul 2>&1
                echo   deleted: %%~nxF
            )
        )
    )
)
:: aggressive — wipe all auto/custom destinations
del /f /q "%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations\*" >nul 2>&1
del /f /q "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations\*" >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 6 — TEMP FILES
:: ══════════════════════════════════════════════════════
echo [6] Cleaning Temp...
for %%D in ("%TEMP%" "%SystemRoot%\Temp") do (
    if exist "%%~D" (
        for /L %%i in (0,1,%KW_MAX%) do (
            for %%F in ("%%~D\*!KW[%%i]!*") do (
                del /f /q "%%F" >nul 2>&1
            )
            for /d %%F in ("%%~D\*!KW[%%i]!*") do (
                rd /s /q "%%F" >nul 2>&1
            )
        )
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 7 — RECYCLE BIN
:: ══════════════════════════════════════════════════════
echo [7] Emptying Recycle Bin...
rd /s /q "C:\$Recycle.Bin" >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 8 — ROBLOX LOGS
:: ══════════════════════════════════════════════════════
echo [8] Wiping Roblox logs...
if exist "%LOCALAPPDATA%\Roblox\logs" (
    del /f /q "%LOCALAPPDATA%\Roblox\logs\*" >nul 2>&1
    echo   wiped all logs
)
:: also nuke Roblox FFlags
for /d %%V in ("%LOCALAPPDATA%\Roblox\Versions\*") do (
    if exist "%%V\ClientSettings\ClientAppSettings.json" (
        del /f /q "%%V\ClientSettings\ClientAppSettings.json" >nul 2>&1
        echo   deleted ClientAppSettings.json in %%~nxV
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 9 — REGISTRY (MUICache, FeatureUsage, App Paths)
:: ══════════════════════════════════════════════════════
echo [9] Cleaning Registry traces...
:: MUICache
for /f "tokens=1,*" %%A in ('reg query "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" 2^>nul ^| findstr /i /v /c:"(Default)" ^| findstr /i /v /c:"HKEY_"') do (
    set "VAL=%%A"
    for /L %%i in (0,1,%KW_MAX%) do (
        echo !VAL! | findstr /i /c:"!KW[%%i]!" >nul 2>&1
        if !errorlevel! equ 0 (
            reg delete "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" /v "!VAL!" /f >nul 2>&1
            echo   deleted MUICache: !VAL!
        )
    )
)
:: FeatureUsage
for %%K in (
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppLaunch"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppBadgeUpdated"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\ShowJumpView"
) do (
    for /f "tokens=1,*" %%A in ('reg query %%K 2^>nul ^| findstr /i /v /c:"(Default)" ^| findstr /i /v /c:"HKEY_"') do (
        set "VAL=%%A"
        for /L %%i in (0,1,%KW_MAX%) do (
            echo !VAL! | findstr /i /c:"!KW[%%i]!" >nul 2>&1
            if !errorlevel! equ 0 (
                reg delete %%K /v "!VAL!" /f >nul 2>&1
                echo   deleted FeatureUsage: !VAL!
            )
        )
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 10 — SHELLBAGS (wipe all)
:: ══════════════════════════════════════════════════════
echo [10] Wiping ShellBags...
reg delete "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\Shell\BagMRU" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\Shell\Bags" /f >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 11 — VSS (delete all shadow copies)
:: ══════════════════════════════════════════════════════
echo [11] Deleting Volume Shadow Copies...
vssadmin delete shadows /all /quiet >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 12 — PCA (Program Compatibility Assistant)
:: ══════════════════════════════════════════════════════
echo [12] Cleaning PCA...
reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /f >nul 2>&1
if exist "%ProgramData%\Microsoft\Windows\AppRepository\Packages" (
    for /L %%i in (0,1,%KW_MAX%) do (
        for %%F in ("%ProgramData%\Microsoft\Windows\AppRepository\Packages\*!KW[%%i]!*") do (
            del /f /q "%%F" >nul 2>&1
        )
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 13 — SRUM
:: ══════════════════════════════════════════════════════
echo [13] Cleaning SRUM...
net stop DiagTrack >nul 2>&1
net stop DPS >nul 2>&1
if exist "%SystemRoot%\System32\sru\SRUDB.dat" (
    del /f /q "%SystemRoot%\System32\sru\SRUDB.dat" >nul 2>&1
    echo   deleted SRUDB.dat
)
net start DPS >nul 2>&1
net start DiagTrack >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 14 — USN JOURNAL
:: ══════════════════════════════════════════════════════
echo [14] Resetting USN Journal...
fsutil usn deletejournal /d /n C: >nul 2>&1
fsutil usn createjournal C: >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 15 — EVENT LOGS (delete evtx while disabled)
:: ══════════════════════════════════════════════════════
echo [15] Deleting PS event log files...
del /f /q "%SystemRoot%\System32\winevt\Logs\Windows PowerShell.evtx" >nul 2>&1
del /f /q "%SystemRoot%\System32\winevt\Logs\Microsoft-Windows-PowerShell%%4Operational.evtx" >nul 2>&1
del /f /q "%SystemRoot%\System32\winevt\Logs\Microsoft-Windows-PowerShell%%4Analytic.evtx" >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 16 — RE-ENABLE PS LOGGING (fresh logs)
:: ══════════════════════════════════════════════════════
echo [16] Re-enabling PS event log channels...
wevtutil sl "Windows PowerShell" /e:true >nul 2>&1
wevtutil sl "Microsoft-Windows-PowerShell/Operational" /e:true >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 17 — DEFENDER FIX
:: ══════════════════════════════════════════════════════
echo [17] Fixing Defender...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /f >nul 2>&1
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 18 — DELETE THE POTASSIUM FOLDER + FILES
:: ══════════════════════════════════════════════════════
echo [18] Deleting executor folders from Downloads/Desktop...
for %%D in ("%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%TEMP%") do (
    if exist "%%~D" (
        for /L %%i in (0,1,%KW_MAX%) do (
            for /d %%F in ("%%~D\*!KW[%%i]!*") do (
                rd /s /q "%%F" >nul 2>&1
                echo   deleted folder: %%F
            )
            for %%F in ("%%~D\*!KW[%%i]!*") do (
                del /f /q "%%F" >nul 2>&1
                echo   deleted file: %%~nxF
            )
        )
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 19 — DELETE TOOLKIT + LOGS + ZIPS + CERTS
:: ══════════════════════════════════════════════════════
echo [19] Deleting toolkit traces...
set "SCRIPTDIR=%~dp0"

:: delete pc_check results
if exist "%SCRIPTDIR%pc_check_results.txt" del /f /q "%SCRIPTDIR%pc_check_results.txt" >nul 2>&1

:: delete toolkit files if in same dir or nearby
for %%F in (
    trinity_proxy.py trinity_stealth.bat trinity_cleaner.ps1
    trinity_report.py make_bundle.py launch_trinity.bat launch_proxy.bat
    pc_check.bat pc_check_results.txt README.md README.txt .gitignore
) do (
    if exist "%SCRIPTDIR%%%F" del /f /q "%SCRIPTDIR%%%F" >nul 2>&1
)
if exist "%SCRIPTDIR%certs" rd /s /q "%SCRIPTDIR%certs" >nul 2>&1
if exist "%SCRIPTDIR%proxy_logs" rd /s /q "%SCRIPTDIR%proxy_logs" >nul 2>&1
if exist "%SCRIPTDIR%__pycache__" rd /s /q "%SCRIPTDIR%__pycache__" >nul 2>&1

:: hunt for toolkit zips in common locations
for %%D in ("%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%TEMP%") do (
    for %%Z in (
        "trinity_bypass.zip" "trinity-ac.zip" "trinity_bypass" "trinity-ac"
    ) do (
        if exist "%%~D\%%~Z" (
            del /f /q "%%~D\%%~Z" >nul 2>&1
            rd /s /q "%%~D\%%~Z" >nul 2>&1
            echo   deleted: %%~D\%%~Z
        )
    )
)
echo   done

:: ══════════════════════════════════════════════════════
::  PHASE 20 — SELF-DESTRUCT + FORCE RESTART
:: ══════════════════════════════════════════════════════
echo.
echo ═══════════════════════════════════════════════════════════
color 0A
echo   [DONE] All phases complete.
echo   Force restarting in 10 seconds...
echo   Close anything you need to save NOW.
echo ═══════════════════════════════════════════════════════════
echo.

:: delete this script + parent folder if it's trinity_bypass, then restart
set "SELF=%~f0"
set "SELFDIR=%~dp0"
set "SELFNAME=%~nx0"
set "DIRNAME=%~dp0"
set "DIRNAME=%DIRNAME:~0,-1%"
for %%I in ("%DIRNAME%") do set "FOLDERNAME=%%~nxI"

:: spawn background cmd: wait 3 sec, delete this bat, delete parent if toolkit folder, restart
start "" /b cmd /c "timeout /t 3 /nobreak >nul & del /f /q "%SELF%" >nul 2>&1 & if /i "%FOLDERNAME%"=="trinity_bypass" rd /s /q "%SELFDIR%." >nul 2>&1 & shutdown /r /t 7 /f /c "Emergency clean complete — restarting""

exit
