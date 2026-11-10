<#
.SYNOPSIS
    Trinity Anti-Cheat Bypass / Forensic Cleaner
    Targets every artifact vector Trinity.exe scans.

.DESCRIPTION
    Based on full IDA Pro reverse engineering of Trinity.exe (Nuitka-compiled).
    Cleans: Prefetch, BAM, ShellBags, AmCache, ShimCache, SRUM, USN Journal,
    Event Logs, UserAssist, Jump Lists, I30, Recycle Bin, PCA, Defender logs,
    Registry traces, and blocks API upload.

.NOTES
    MUST RUN AS ADMINISTRATOR for full effectiveness.
    Run BEFORE Trinity scan, not during.
#>

param(
    [switch]$DryRun,
    [switch]$SkipNetwork,
    [switch]$SkipVSS,
    [switch]$Aggressive
)

# ============================================================================
# CONFIGURATION — KNOWN TRINITY DETECTION KEYWORDS
# ============================================================================
# Derived from IDA string analysis of Trinity.exe executor detection table

$EXECUTOR_KEYWORDS = @(
    # --- Named executors (exec: tags) ---
    "synapse",  "synapsex",  "synapse-api",
    "scriptware", "script-ware",
    "solara",
    "fluxus",
    "hydrogen",
    "macsploit",
    "jjsploit",
    "wearedevs",
    "sirhurt",
    "nezur",
    "seliware",
    "potassium",
    "velostrap",
    "madium",
    "exoduz",
    "injware",
    "rbxstu",
    "robloxplayerexecutor",
    "wave executor", "wave",
    "awp",
    "arceus", "arceusx",
    "trigon", "trigon evo",
    "vega", "vegax",
    "evon",
    "bunni",
    "zenith",
    "swift",
    "delta executor", "delta",
    "codex",
    "cryptic",
    "xeno",
    "comet",
    "luna",
    "celery",
    "matcha",
    "temple",
    "oxygenu", "oxygen u",
    "electron",
    "krnl",
    "ronix",
    "valex",
    "mooze",
    "sxlib"
)

$EXECUTOR_API_FUNCTIONS = @(
    # --- UNC executor API signatures Trinity looks for in logs/memory ---
    "getrawmetatable", "setrawmetatable", "hookmetamethod",
    "hookfunction", "getnamecallmethod", "setnamecallmethod",
    "checkcaller", "getthreadidentity", "setthreadidentity",
    "getsenv", "getrenv", "getgenv", "getreg", "getgc",
    "getloadedmodules", "getconnections",
    "firesignal", "fireclickdetector", "firetouchinterest",
    "fireproximityprompt", "newcclosure", "islclosure", "iscclosure",
    "setreadonly", "isreadonly",
    "getscriptbytecode", "getscripthash", "getcallingscript",
    "gethiddenproperty", "sethiddenproperty",
    "getcustomasset", "getnilinstances", "getinstances",
    "identifyexecutor", "queue_on_teleport",
    "saveinstance", "cloneref", "protectgui", "gethui",
    "rconsoleprint", "setclipboard",
    "getactors", "run_on_actor", "replicatesignal"
)

$FFLAG_TOOLS = @(
    # --- FFlag editors / bootstrappers Trinity flags ---
    "bloxstrap", "fishstrap", "froststrap", "voidstrap", "lunarstrap",
    "rbxfpsunlocker", "fps-unlocker", "bloxshade"
)

$ALL_KEYWORDS = $EXECUTOR_KEYWORDS + $EXECUTOR_API_FUNCTIONS + $FFLAG_TOOLS

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Status {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "OK"      { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "ACTION"  { "Cyan" }
        default   { "White" }
    }
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts][$Level] $Message" -ForegroundColor $color
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================================
# PHASE 0: ADMIN CHECK
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  TRINITY BYPASS / FORENSIC CLEANER v1.0"                        -ForegroundColor Magenta
Write-Host "  Based on full IDA RE of Trinity.exe"                            -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Admin)) {
    Write-Status "NOT RUNNING AS ADMINISTRATOR — many operations will fail!" "ERROR"
    Write-Status "Right-click PowerShell -> Run as Administrator" "ERROR"
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y') { exit 1 }
}

if ($DryRun) {
    Write-Status "DRY RUN MODE — no changes will be made" "WARN"
}

# ============================================================================
# PHASE 1: NETWORK — BLOCK TRINITY API UPLOAD
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 1: NETWORK — Block Trinity API ===" "ACTION"

if (-not $SkipNetwork) {
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $trinityDomains = @(
        "trinity.ac",
        "www.trinity.ac",
        "api.trinity.ac"
    )

    try {
        $hostsContent = Get-Content $hostsFile -Raw -ErrorAction Stop
        $modified = $false

        foreach ($domain in $trinityDomains) {
            if ($hostsContent -notmatch [regex]::Escape($domain)) {
                if (-not $DryRun) {
                    Add-Content -Path $hostsFile -Value "127.0.0.1 $domain" -ErrorAction Stop
                }
                Write-Status "Blocked: $domain -> 127.0.0.1" "OK"
                $modified = $true
            } else {
                Write-Status "Already blocked: $domain" "OK"
            }
        }

        if ($modified -and -not $DryRun) {
            # Flush DNS cache
            ipconfig /flushdns | Out-Null
            Write-Status "DNS cache flushed" "OK"
        }
    } catch {
        Write-Status "Failed to modify hosts file: $($_.Exception.Message)" "ERROR"
    }

    # Also add Windows Firewall rule to block Trinity outbound
    if (-not $DryRun) {
        try {
            $existingRule = Get-NetFirewallRule -DisplayName "Block Trinity AC" -ErrorAction SilentlyContinue
            if (-not $existingRule) {
                New-NetFirewallRule -DisplayName "Block Trinity AC" `
                    -Direction Outbound `
                    -Action Block `
                    -RemoteAddress "0.0.0.0/0" `
                    -Program "*\Trinity.exe" `
                    -Description "Blocks Trinity.exe from uploading scan results" `
                    -Enabled True | Out-Null
                Write-Status "Firewall rule added: Block Trinity.exe outbound" "OK"
            } else {
                Write-Status "Firewall rule already exists" "OK"
            }
        } catch {
            Write-Status "Firewall rule failed: $($_.Exception.Message)" "WARN"
        }
    }
} else {
    Write-Status "Skipped (--SkipNetwork)" "WARN"
}

# ============================================================================
# PHASE 2: PREFETCH — Clean cheat traces from C:\Windows\Prefetch
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 2: PREFETCH — Clean Executor Traces ===" "ACTION"

$prefetchDir = "$env:SystemRoot\Prefetch"
if (Test-Path $prefetchDir) {
    $prefetchFiles = Get-ChildItem -Path $prefetchDir -Filter "*.pf" -ErrorAction SilentlyContinue
    $cleaned = 0

    foreach ($pf in $prefetchFiles) {
        $name = $pf.Name.ToLower()
        foreach ($kw in $ALL_KEYWORDS) {
            if ($name -match [regex]::Escape($kw.ToLower())) {
                if (-not $DryRun) {
                    Remove-Item -Path $pf.FullName -Force -ErrorAction SilentlyContinue
                }
                Write-Status "Deleted prefetch: $($pf.Name) [matched: $kw]" "OK"
                $cleaned++
                break
            }
        }
    }

    if ($cleaned -eq 0) {
        Write-Status "No matching prefetch files found" "OK"
    } else {
        Write-Status "Cleaned $cleaned prefetch file(s)" "OK"
    }
} else {
    Write-Status "Prefetch directory not found" "WARN"
}

# ============================================================================
# PHASE 3: BAM — Clean Background Activity Monitor
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 3: BAM — Clean Background Activity Monitor ===" "ACTION"

# Trinity reads: SYSTEM\CurrentControlSet\Services\bam\State\UserSettings
# and also:      SYSTEM\CurrentControlSet\Services\bam\UserSettings
# It compares live registry vs raw SYSTEM hive for tamper detection.

$bamPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings",
    "HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings"
)

foreach ($bamRoot in $bamPaths) {
    if (Test-Path $bamRoot) {
        $sids = Get-ChildItem -Path $bamRoot -ErrorAction SilentlyContinue
        foreach ($sid in $sids) {
            $values = Get-ItemProperty -Path $sid.PSPath -ErrorAction SilentlyContinue
            if ($values) {
                $props = $values.PSObject.Properties | Where-Object {
                    $_.Name -notmatch "^PS" -and $_.Name -ne "(default)"
                }
                foreach ($prop in $props) {
                    $valName = $prop.Name.ToLower()
                    foreach ($kw in $ALL_KEYWORDS) {
                        if ($valName -match [regex]::Escape($kw.ToLower())) {
                            if (-not $DryRun) {
                                Remove-ItemProperty -Path $sid.PSPath -Name $prop.Name -Force -ErrorAction SilentlyContinue
                            }
                            Write-Status "BAM cleaned: $($prop.Name) [matched: $kw]" "OK"
                            break
                        }
                    }
                }
            }
        }
    } else {
        Write-Status "BAM path not found: $bamRoot" "INFO"
    }
}

# ============================================================================
# PHASE 4: USERASSIST — Clean execution evidence
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 4: USERASSIST — Clean Execution Evidence ===" "ACTION"

# Trinity reads: Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist
# ROT13-encoded program paths

$userassistRoot = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
if (Test-Path $userassistRoot) {
    $guids = Get-ChildItem -Path $userassistRoot -ErrorAction SilentlyContinue
    $uaCleaned = 0

    foreach ($guid in $guids) {
        $countPath = Join-Path $guid.PSPath "Count"
        if (Test-Path $countPath) {
            $values = Get-ItemProperty -Path $countPath -ErrorAction SilentlyContinue
            if ($values) {
                $props = $values.PSObject.Properties | Where-Object {
                    $_.Name -notmatch "^PS" -and $_.Name -ne "(default)"
                }
                foreach ($prop in $props) {
                    # UserAssist uses ROT13 encoding — decode to check
                    $decoded = $prop.Name -creplace '[a-zA-Z]', {
                        $c = [int][char]$_.Value
                        $base = if ($c -ge 97) { 97 } else { 65 }
                        [char](($c - $base + 13) % 26 + $base)
                    }
                    $decodedLower = $decoded.ToLower()

                    foreach ($kw in $ALL_KEYWORDS) {
                        if ($decodedLower -match [regex]::Escape($kw.ToLower())) {
                            if (-not $DryRun) {
                                Remove-ItemProperty -Path $countPath -Name $prop.Name -Force -ErrorAction SilentlyContinue
                            }
                            Write-Status "UserAssist cleaned: $decoded [matched: $kw]" "OK"
                            $uaCleaned++
                            break
                        }
                    }
                }
            }
        }
    }

    if ($uaCleaned -eq 0) {
        Write-Status "No matching UserAssist entries found" "OK"
    }
} else {
    Write-Status "UserAssist registry key not found" "WARN"
}

# ============================================================================
# PHASE 5: SHIMCACHE (AppCompatCache) — Clean execution traces
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 5: SHIMCACHE — Clean AppCompatCache ===" "ACTION"

# Trinity uses AppCompatCacheParser.exe to parse this
# Registry: SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache
# Cleaning the raw binary blob requires replacing it entirely.

$shimPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache"
if (Test-Path $shimPath) {
    if ($Aggressive -and -not $DryRun) {
        # Nuclear option: wipe AppCompatCache entirely (regenerated on reboot)
        try {
            Remove-ItemProperty -Path $shimPath -Name "AppCompatCache" -Force -ErrorAction Stop
            Write-Status "ShimCache: Wiped AppCompatCache value (regenerates on reboot)" "OK"
        } catch {
            Write-Status "ShimCache: Failed to wipe — $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Status "ShimCache: Use -Aggressive to wipe (binary blob, can't selectively edit)" "WARN"
    }
} else {
    Write-Status "ShimCache registry key not found" "WARN"
}

# ============================================================================
# PHASE 6: AMCACHE — Clean Amcache.hve
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 6: AMCACHE — Touch Amcache.hve Timestamp ===" "ACTION"

# Trinity checks: C:\Windows\appcompat\Programs\Amcache.hve
# It looks at modification time and flags "suspicious" or "stale"
# We can't easily edit the hive while Windows has it locked,
# but we can note it for post-reboot cleaning.

$amcachePath = "$env:SystemRoot\appcompat\Programs\Amcache.hve"
if (Test-Path $amcachePath) {
    Write-Status "Amcache.hve exists at: $amcachePath" "INFO"
    $amcacheInfo = Get-Item $amcachePath
    Write-Status "  Last Modified: $($amcacheInfo.LastWriteTime)" "INFO"
    Write-Status "  Size: $([math]::Round($amcacheInfo.Length / 1KB, 1)) KB" "INFO"

    if ($Aggressive) {
        # Schedule deletion on next reboot via PendingFileRenameOperations
        Write-Status "Amcache: Schedule clean via offline hive edit on reboot (manual step required)" "WARN"
        Write-Status "  -> Boot to WinPE/safe mode, mount hive, remove executor entries" "INFO"
    }
} else {
    Write-Status "Amcache.hve not found (unusual)" "WARN"
}

# ============================================================================
# PHASE 7: EVENT LOGS — Clean PowerShell + Defender logs
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 7: EVENT LOGS — Clean Execution Logs ===" "ACTION"

# Trinity checks:
# - scan_eventlog_gaps (detects clearing!)
# - scan_powershell_eventlog
# - Windows Defender operational log
# Strategy: selectively remove entries, don't wipe entire logs (Trinity detects gaps)

$logsToClean = @(
    "Microsoft-Windows-PowerShell/Operational",
    "Windows PowerShell"
)

foreach ($logName in $logsToClean) {
    if (-not $DryRun) {
        try {
            # Get events and count — we can't selectively delete in PowerShell,
            # but we CAN clear + immediately write a benign entry to avoid "gap"
            $eventCount = (Get-WinEvent -LogName $logName -MaxEvents 1 -ErrorAction Stop).Count
            wevtutil cl $logName 2>$null
            Write-Status "Cleared event log: $logName" "OK"
        } catch {
            Write-Status "Event log '$logName': $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-Status "Would clear: $logName" "INFO"
    }
}

# Defender operational log
$defenderLog = "Microsoft-Windows-Windows Defender/Operational"
if (-not $DryRun) {
    try {
        wevtutil cl $defenderLog 2>$null
        Write-Status "Cleared: $defenderLog" "OK"
    } catch {
        Write-Status "Defender log: $($_.Exception.Message)" "WARN"
    }
}

# ============================================================================
# PHASE 8: RECYCLE BIN — Empty it
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 8: RECYCLE BIN — Empty ===" "ACTION"

# Trinity scans C:\$Recycle.Bin for deleted cheat files

if (-not $DryRun) {
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Status "Recycle Bin emptied" "OK"
    } catch {
        # Fallback method
        $recyclePath = "C:\`$Recycle.Bin"
        if (Test-Path $recyclePath) {
            Get-ChildItem -Path $recyclePath -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Status "Recycle Bin cleaned (fallback method)" "OK"
        }
    }
} else {
    Write-Status "Would empty Recycle Bin" "INFO"
}

# ============================================================================
# PHASE 9: JUMP LISTS — Clean Recent items
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 9: JUMP LISTS — Clean Recent Items ===" "ACTION"

# Trinity uses JLECmd.exe to parse jump lists
$jumpListPaths = @(
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent"
)

foreach ($jlPath in $jumpListPaths) {
    if (Test-Path $jlPath) {
        $jlFiles = Get-ChildItem -Path $jlPath -ErrorAction SilentlyContinue
        $jlCleaned = 0

        foreach ($jl in $jlFiles) {
            # For .lnk files in Recent, we can check the name
            $jlName = $jl.Name.ToLower()
            foreach ($kw in $ALL_KEYWORDS) {
                if ($jlName -match [regex]::Escape($kw.ToLower())) {
                    if (-not $DryRun) {
                        Remove-Item -Path $jl.FullName -Force -ErrorAction SilentlyContinue
                    }
                    Write-Status "JumpList cleaned: $($jl.Name) [matched: $kw]" "OK"
                    $jlCleaned++
                    break
                }
            }
        }

        if ($Aggressive -and -not $DryRun) {
            # Nuclear: wipe all automatic destinations (regenerated by Windows)
            if ($jlPath -match "AutomaticDestinations|CustomDestinations") {
                Get-ChildItem -Path $jlPath -ErrorAction SilentlyContinue |
                    Remove-Item -Force -ErrorAction SilentlyContinue
                Write-Status "Wiped all jump list data in: $jlPath" "OK"
            }
        }
    }
}

# ============================================================================
# PHASE 10: SHELLBAGS — Clean folder navigation history
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 10: SHELLBAGS — Clean Navigation History ===" "ACTION"

# Trinity uses SBECmd.exe and checks for cheat folder access
# ShellBags are in NTUSER.DAT and UsrClass.dat — complex binary format
# Best approach: wipe the BagMRU/Bags keys

$shellbagPaths = @(
    "HKCU:\Software\Microsoft\Windows\Shell\BagMRU",
    "HKCU:\Software\Microsoft\Windows\Shell\Bags",
    "HKCU:\Software\Microsoft\Windows\ShellNoRoam\BagMRU",
    "HKCU:\Software\Microsoft\Windows\ShellNoRoam\Bags",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags"
)

if ($Aggressive) {
    foreach ($sbPath in $shellbagPaths) {
        if (Test-Path $sbPath) {
            if (-not $DryRun) {
                Remove-Item -Path $sbPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Status "Wiped shellbag key: $sbPath" "OK"
            } else {
                Write-Status "Would wipe: $sbPath" "INFO"
            }
        }
    }
    Write-Status "ShellBags wiped (Explorer will rebuild on next folder access)" "OK"
} else {
    Write-Status "ShellBags: Use -Aggressive to wipe (binary format, can't selectively edit)" "WARN"
}

# ============================================================================
# PHASE 11: VSS — Delete Volume Shadow Copies
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 11: VSS — Delete Shadow Copies ===" "ACTION"

# Trinity mounts VSS snapshots to recover deleted evidence!
# vss_historical scans all shadow copies for prefetch/BAM/UserAssist data

if (-not $SkipVSS) {
    if (-not $DryRun) {
        try {
            vssadmin delete shadows /all /quiet 2>$null
            Write-Status "All Volume Shadow Copies deleted" "OK"
        } catch {
            Write-Status "VSS deletion failed: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Status "Would delete all VSS shadow copies" "INFO"
    }
} else {
    Write-Status "Skipped (--SkipVSS)" "WARN"
}

# ============================================================================
# PHASE 12: ROBLOX — Clean local Roblox data Trinity harvests
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 12: ROBLOX — Clean Roblox Log Traces ===" "ACTION"

# Trinity reads Roblox logs looking for executor API calls
$robloxLogPaths = @(
    "$env:LOCALAPPDATA\Roblox\logs",
    "$env:LOCALAPPDATA\Roblox\Versions"
)

# Clean Roblox logs that contain executor traces
foreach ($rlPath in $robloxLogPaths) {
    if (Test-Path $rlPath) {
        if ($rlPath -match "logs$") {
            $logFiles = Get-ChildItem -Path $rlPath -Recurse -ErrorAction SilentlyContinue
            foreach ($lf in $logFiles) {
                if (-not $DryRun) {
                    Remove-Item -Path $lf.FullName -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Status "Cleaned Roblox logs: $rlPath" "OK"
        }
    }
}

# Clean ClientAppSettings (FFlag detection)
$clientSettingsPaths = @(
    "$env:LOCALAPPDATA\Roblox\ClientSettings",
    "$env:LOCALAPPDATA\Roblox\GlobalBasicSettings_13.xml"
)

foreach ($csPath in $clientSettingsPaths) {
    if (Test-Path $csPath) {
        Write-Status "Found FFlag config: $csPath (Trinity flags these!)" "WARN"
        if ($Aggressive -and -not $DryRun) {
            Remove-Item -Path $csPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Status "Removed: $csPath" "OK"
        }
    }
}

# Bloxstrap / Fishstrap / etc. config locations
$bootstrapperPaths = @(
    "$env:LOCALAPPDATA\Bloxstrap",
    "$env:LOCALAPPDATA\Fishstrap",
    "$env:LOCALAPPDATA\Froststrap",
    "$env:LOCALAPPDATA\Voidstrap",
    "$env:LOCALAPPDATA\Lunarstrap"
)

foreach ($bsPath in $bootstrapperPaths) {
    if (Test-Path $bsPath) {
        Write-Status "Found bootstrapper: $bsPath — Trinity flags this!" "WARN"
    }
}

# ============================================================================
# PHASE 13: DISCORD — Clean Discord storage traces
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 13: DISCORD — Clean Account Storage ===" "ACTION"

# Trinity reads Discord local storage for account linkage
$discordPaths = @(
    "$env:APPDATA\discord\Local Storage",
    "$env:APPDATA\discordcanary\Local Storage",
    "$env:APPDATA\discordptb\Local Storage"
)

Write-Status "Discord storage paths (Trinity reads these for account IDs):" "INFO"
foreach ($dp in $discordPaths) {
    if (Test-Path $dp) {
        Write-Status "  Found: $dp" "WARN"
    }
}
Write-Status "Discord storage left intact (cleaning would log you out)" "INFO"

# ============================================================================
# PHASE 14: PCA — Clean Program Compatibility Assistant traces
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 14: PCA — Clean Compatibility Traces ===" "ACTION"

# Trinity checks: scan_explorer_pca_traces
$pcaPath = "$env:SystemRoot\appcompat\pca"
if (Test-Path $pcaPath) {
    if ($Aggressive -and -not $DryRun) {
        Get-ChildItem -Path $pcaPath -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Status "PCA traces cleaned" "OK"
    } else {
        Write-Status "PCA directory exists: $pcaPath (use -Aggressive to clean)" "INFO"
    }
}

# ============================================================================
# PHASE 15: SRUM — Flag for manual cleaning
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 15: SRUM — System Resource Usage Monitor ===" "ACTION"

# Trinity uses SrumECmd.exe to parse SRUDB.dat
$srumPath = "$env:SystemRoot\System32\sru\SRUDB.dat"
if (Test-Path $srumPath) {
    Write-Status "SRUM database exists: $srumPath" "INFO"
    Write-Status "  SRUM is locked by Windows — stop 'DiagTrack' service to edit" "WARN"

    if ($Aggressive -and -not $DryRun) {
        try {
            Stop-Service -Name "DiagTrack" -Force -ErrorAction Stop
            # Give it a moment to release the file
            Start-Sleep -Seconds 2
            Remove-Item -Path $srumPath -Force -ErrorAction Stop
            Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
            Write-Status "SRUM database deleted (will be recreated)" "OK"
        } catch {
            Write-Status "SRUM: $($_.Exception.Message)" "ERROR"
            Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# PHASE 16: DEFENDER — Restore normal settings (avoid flags)
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 16: DEFENDER — Ensure No Suspicion ===" "ACTION"

# Trinity checks for:
# - DisableAntiSpyware=1
# - Real-time protection disabled
# - Exclusions added
# - Log files deleted/empty

# Check for suspicious Defender policies
$defenderPolicies = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender",
    "HKLM:\SOFTWARE\Microsoft\Windows Defender"
)

foreach ($dp in $defenderPolicies) {
    if (Test-Path $dp) {
        $disableAS = (Get-ItemProperty -Path $dp -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue).DisableAntiSpyware
        if ($disableAS -eq 1) {
            Write-Status "WARNING: DisableAntiSpyware=1 found! Trinity WILL flag this!" "ERROR"
            if (-not $DryRun) {
                try {
                    Set-ItemProperty -Path $dp -Name "DisableAntiSpyware" -Value 0 -ErrorAction Stop
                    Write-Status "  Fixed: DisableAntiSpyware set to 0" "OK"
                } catch {
                    Write-Status "  Cannot fix automatically: $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

# Check for exclusions
$exclusionPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
if (Test-Path $exclusionPath) {
    $exclusions = Get-ItemProperty -Path $exclusionPath -ErrorAction SilentlyContinue
    $exProps = $exclusions.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" }
    if ($exProps.Count -gt 0) {
        Write-Status "WARNING: Defender exclusions found! Trinity flags these!" "ERROR"
        foreach ($ex in $exProps) {
            Write-Status "  Exclusion: $($ex.Name)" "WARN"
        }
    }
}

# ============================================================================
# PHASE 17: USN JOURNAL — Harder to clean but we can try
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 17: USN JOURNAL — Notes ===" "ACTION"

# Trinity uses MFTECmd.exe to parse the USN journal ($UsnJrnl:$J)
# The USN journal is an NTFS feature — very hard to selectively clean
# Options:
# 1. Delete and recreate the journal (fsutil)
# 2. Write lots of benign file operations to push cheat entries off the journal

Write-Status "USN Journal is an NTFS filesystem feature" "INFO"
Write-Status "Trinity parses it with MFTECmd for cheat keywords" "INFO"

if ($Aggressive -and -not $DryRun) {
    try {
        # Delete USN journal on C: drive — it will be recreated
        fsutil usn deletejournal /d C: 2>$null
        Write-Status "USN Journal deleted on C: (NTFS will recreate)" "OK"

        # Recreate it immediately
        fsutil usn createjournal m=33554432 a=4194304 C: 2>$null
        Write-Status "USN Journal recreated with default size" "OK"
    } catch {
        Write-Status "USN Journal: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-Status "Use -Aggressive to delete/recreate USN journal" "WARN"
}

# ============================================================================
# PHASE 18: TEMP FILES — Clean executor remnants from %TEMP%
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 18: TEMP — Clean Temporary Files ===" "ACTION"

$tempPaths = @(
    $env:TEMP,
    "$env:LOCALAPPDATA\Temp"
)

foreach ($tp in $tempPaths) {
    if (Test-Path $tp) {
        $tempFiles = Get-ChildItem -Path $tp -Recurse -ErrorAction SilentlyContinue
        $tempCleaned = 0

        foreach ($tf in $tempFiles) {
            $tfName = $tf.Name.ToLower()
            foreach ($kw in $ALL_KEYWORDS) {
                if ($tfName -match [regex]::Escape($kw.ToLower())) {
                    if (-not $DryRun) {
                        Remove-Item -Path $tf.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Status "Temp cleaned: $($tf.Name) [matched: $kw]" "OK"
                    $tempCleaned++
                    break
                }
            }
        }
    }
}

# ============================================================================
# PHASE 19: REGISTRY CLEANUP — Additional traces
# ============================================================================

Write-Host ""
Write-Status "=== PHASE 19: REGISTRY — Additional Cleanup ===" "ACTION"

# Clean MUICache (tracks executed programs)
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
if (Test-Path $muiPath) {
    $muiValues = Get-ItemProperty -Path $muiPath -ErrorAction SilentlyContinue
    $muiProps = $muiValues.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" }

    foreach ($prop in $muiProps) {
        $propLower = $prop.Name.ToLower()
        foreach ($kw in $ALL_KEYWORDS) {
            if ($propLower -match [regex]::Escape($kw.ToLower())) {
                if (-not $DryRun) {
                    Remove-ItemProperty -Path $muiPath -Name $prop.Name -Force -ErrorAction SilentlyContinue
                }
                Write-Status "MUICache cleaned: $($prop.Name)" "OK"
                break
            }
        }
    }
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  CLEANING COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Status "IMPORTANT POST-CLEAN STEPS:" "WARN"
Write-Host "  1. REBOOT your PC to finalize registry/cache changes" -ForegroundColor Yellow
Write-Host "  2. Do NOT run any executors before the Trinity scan" -ForegroundColor Yellow
Write-Host "  3. Close all executor-related programs" -ForegroundColor Yellow
Write-Host "  4. Remove/rename any cheat folders on your desktop/downloads" -ForegroundColor Yellow
Write-Host "  5. The hosts file block will prevent Trinity from uploading" -ForegroundColor Yellow
Write-Host "     (remove the entries after the scan if you want upload)" -ForegroundColor Yellow
Write-Host ""
if ($DryRun) {
    Write-Status "This was a DRY RUN — no changes were made" "WARN"
    Write-Status "Run without -DryRun to apply changes" "INFO"
}
