"""
Trinity Anti-Cheat — Full Reverse Engineering Report & Bypass Reference
========================================================================
Generated from IDA Pro MCP analysis of Trinity.exe (Nuitka-compiled x64 PE)

This module documents every detection vector Trinity uses and provides
the complete keyword/signature database extracted from the binary.
"""

# ============================================================================
# TRINITY BINARY METADATA
# ============================================================================

TRINITY_INFO = {
    "binary":       "Trinity.exe",
    "compiler":     "Nuitka (Python 3.x -> native C -> MSVC x64)",
    "gui":          "CustomTkinter",
    "api_base":     "https://trinity.ac",
    "api_upload":   "/api/results",
    "discord":      "https://discord.gg/fjgYd3WVwD",
    "privacy":      "https://trinity.ac/privacy",
    "jurisdiction": "New Jersey, USA",
    "imagebase":    "0x140000000",
    "auth":         "PIN-based (TrinityApp._create_pin_page)",
}

# ============================================================================
# BUNDLED FORENSIC TOOLS (Eric Zimmerman suite)
# ============================================================================

BUNDLED_TOOLS = {
    "PECmd.exe":                "Prefetch parser",
    "MFTECmd.exe":              "MFT / USN journal ($UsnJrnl:$J) parser",
    "SBECmd.exe":               "ShellBag explorer / parser",
    "AmcacheParser.exe":        "Amcache.hve parser",
    "AppCompatCacheParser.exe": "ShimCache (AppCompatCache) parser",
    "SrumECmd.exe":             "SRUM database parser",
    "JLECmd.exe":               "Jump List explorer",
}

# ============================================================================
# SCAN FLOW (call chain from IDA)
# ============================================================================

SCAN_FLOW = """
TrinityApp.__init__()
  -> _create_welcome_page()           # Welcome screen
  -> _create_pin_page()               # PIN entry (validates with trinity.ac)
  -> _show_terms()                    # ToS / consent
  -> _start_scan()                    # Begins scan
     -> _run_scan()
        -> run_windows_scan()          # Main orchestrator
           |
           |-- get_system_info()       # OS, hardware, install date
           |-- get_trash()             # Recycle bin contents
           |-- get_roblox_logs()       # Roblox log files + shadow recovery
           |
           |-- _do_backend()           # -> _run_backend_scan_inner()
           |   |-- _pecmd_scan()       #    Prefetch via PECmd.exe
           |   |-- _pre_bam()          #    BAM preprocessing
           |   |-- _pre_registry()     #    Registry activity
           |   |-- _pre_integrity()    #    Integrity baseline
           |   |-- _run_amcache()      #    AmcacheParser.exe
           |   |-- _run_shimcache()    #    AppCompatCacheParser.exe
           |   |-- _run_srum()         #    SrumECmd.exe
           |   |-- _run_shellbag()     #    SBECmd.exe
           |   |-- _run_pecmd()        #    PECmd.exe (full)
           |   |-- _run_i30()          #    NTFS $I30 index extraction
           |   |-- _run_jumplist()     #    JLECmd.exe
           |   |-- _run_vss()          #    Volume Shadow Copy walk
           |   |-- _post_usb()         #    USB device history
           |   |-- _post_integrity()   #    Tamper verification
           |   |-- _post_custom()      #    Custom detection rules
           |   `-- _post_recycle()     #    Deep recycle bin scan
           |
           |-- _do_memory()            # Process memory scanning
           |   |-- _discord()          #    Discord process strings
           |   |-- _pca()              #    Program Compatibility Assistant
           |   `-- _system()           #    General process memory
           |
           `-- _do_discord_accounts()  # Discord account harvesting
               `-- get_discord_accounts_from_storage()

        -> Upload results to trinity.ac/api/results via requests library
"""

# ============================================================================
# COMPLETE EXECUTOR DETECTION DATABASE
# ============================================================================

# These are the EXACT strings Trinity matches against, extracted from IDA.
# Format: { "match_keyword": "detection_tag" }

EXECUTOR_DETECTIONS = {
    # --- Named Executors ---
    "synapse x":            "exec:SynapseX",
    "scriptware":           "exec:ScriptWare",
    "script-ware":          "exec:ScriptWare",
    "solara":               "exec:Solara",
    "fluxus":               "exec:Fluxus",
    "hydrogen":             "exec:Hydrogen",
    "macsploit":            "exec:Macsploit",
    "jjsploit":             "exec:JJSploit",
    "wearedevs":            "exec:WeAreDevs",
    "sirhurt":              "exec:SirHurt",
    "nezur":                "exec:Nezur",
    "seliware":             "exec:Seliware",
    "potassium":            "exec:Potassium",
    "velostrap":            "exec:Velostrap",
    "madium":               "exec:Madium",
    "exoduz":               "exec:Exoduz",
    "injware":              "exec:Injware",
    "rbxstu":               "exec:RbxStu",
    "robloxplayerexecutor": "exec:RobloxPlayerExecutor",
    "wave executor":        "exec:Wave",
    "awp":                  "exec:AWP",
    "arceus x":             "exec:ArceusX",
    "trigon evo":           "exec:Trigon",
    "vega x":               "exec:VegaX",
    "evon executor":        "exec:Evon",
    "bunni":                "exec:Bunni",
    "zenith":               "exec:Zenith",
    "swift":                "exec:Swift",
    "delta executor":       "exec:Delta",
    "codex":                "exec:Codex",
    "cryptic":              "exec:Cryptic",
    "xeno":                 "exec:Xeno",
    "comet executor":       "exec:Comet",
    "luna":                 "exec:Luna",
    "celery executor":      "exec:Celery",
    "matcha":               "exec:Matcha",
    "temple":               "exec:Temple",
    "oxygen u":             "exec:OxygenU",
    "electron exploit":     "exec:Electron",
    "krnl":                 "exec:Krnl",
    "ronix":                "exec:Ronix",
    "valex":                "exec:Valex",
    "mooze":                "exec:Mooze",
    "sxlib":                "exec:sxlib",
}

# ============================================================================
# UNC EXECUTOR API FUNCTION SIGNATURES
# ============================================================================

# Trinity searches Roblox logs and memory for these Luau executor API calls.
# If ANY of these appear in logs, BAM, prefetch, or memory — it's flagged.

EXECUTOR_API_SIGNATURES = [
    # --- Metatable manipulation ---
    "executor:getrawmetatable",
    "executor:setrawmetatable",
    "executor:hookmetamethod",
    "executor:hookfunction",

    # --- Thread identity ---
    "executor:getnamecallmethod",
    "executor:setnamecallmethod",
    "executor:checkcaller",
    "executor:getthreadidentity",
    "executor:setthreadidentity",

    # --- Environment access ---
    "executor:getsenv",
    "executor:getrenv",
    "executor:getgenv",
    "executor:getreg",
    "executor:getgc",
    "executor:getloadedmodules",
    "executor:getconnections",

    # --- Event firing ---
    "executor:firesignal",
    "executor:fireclickdetector",
    "executor:firetouchinterest",
    "executor:fireproximityprompt",

    # --- Closure manipulation ---
    "executor:newcclosure",
    "executor:islclosure",
    "executor:iscclosure",

    # --- Table/readonly ---
    "executor:setreadonly",
    "executor:isreadonly",

    # --- Script analysis ---
    "executor:getscriptbytecode",
    "executor:getscripthash",
    "executor:getcallingscript",

    # --- Property manipulation ---
    "executor:gethiddenproperty",
    "executor:sethiddenproperty",

    # --- Instance access ---
    "executor:getcustomasset",
    "executor:getnilinstances",
    "executor:getinstances",
    "executor:identifyexecutor",
    "executor:queue_on_teleport",

    # --- Synapse-specific ---
    "executor:synapse-api",

    # --- Utility ---
    "executor:saveinstance",
    "executor:cloneref",
    "executor:protectgui",
    "executor:gethui",
    "executor:rconsoleprint",
    "executor:setclipboard",
    "executor:getactors",
    "executor:run_on_actor",
    "executor:replicatesignal",
]

# ============================================================================
# FFLAG / BOOTSTRAPPER DETECTION
# ============================================================================

FFLAG_DETECTIONS = {
    # --- Bootstrapper programs ---
    "bloxstrap":        "fflag:Bloxstrap",
    "fishstrap":        "fflag:Fishstrap",
    "froststrap":       "fflag:Froststrap",
    "voidstrap":        "fflag:Voidstrap",
    "lunarstrap":       "fflag:Lunarstrap",

    # --- FPS unlockers ---
    "rbxfpsunlocker":   "fflag:rbxfpsunlocker",
    "fps-unlocker":     "fflag:fps-unlocker",

    # --- Visual mods ---
    "bloxshade":        "fflag:Bloxshade",

    # --- FFlag file detection ---
    "ClientAppSettings": "fflag:ClientAppSettings",

    # --- Specific FFlags Trinity checks ---
    "TargetFps":        "fflag:TargetFps",
    "AltEnter":         "fflag:AltEnter",
    "MouseSmoothing":   "fflag:MouseSmoothing",
    "MaxZoom":          "fflag:MaxZoom",
    "PreferD3D11":      "fflag:PreferD3D11",
    "PreferOpenGL":     "fflag:PreferOpenGL",
    "MTUSize":          "fflag:MTUSize",
    "ShadowIntensity":  "fflag:ShadowIntensity",
    "DisableIGMin":     "fflag:DisableIGMin",
}

# ============================================================================
# ROBLOX-SPECIFIC DETECTION PATTERNS
# ============================================================================

ROBLOX_PATTERNS = {
    # --- Binary/process references ---
    "robloxplayerbeta.exe":  "roblox:player-exe",
    "robloxplayerbeta":      "roblox:player-ref",
    "robloxstudiobeta":      "roblox:studio-ref",
    "robloxsecurity":        "roblox:security-ref",

    # --- Script context ---
    "scriptctx":             "roblox:scriptctx",
    "datamodel":             "roblox:datamodel",
    "script-sig":            "roblox:script-sig",

    # --- Path patterns ---
    "\\roblox\\versions\\":  "roblox:versions-path",
    "roblox-player:":        "roblox:url-protocol",
    "roblox-studio-mode-x":  "roblox:studio-protocol",

    # --- Luau internals ---
    "lua_pcall":             "luau:pcall",
}

# ============================================================================
# INTEGRITY / TAMPER DETECTION CHECKS
# ============================================================================

TAMPER_CHECKS = {
    "bam_tamper": {
        "what": "Compares live BAM registry vs raw SYSTEM hive",
        "detection": "If entries deleted from live but present in hive -> TAMPERED",
        "function": "get_bam_tamper_report()",
        "bypass": "Must clean BOTH live registry AND raw hive, or clean neither",
    },
    "bam_integrity": {
        "what": "Checks BAM entry count, service status",
        "detection": "BAM disabled, service deleted, or entry count too low -> flagged",
        "function": "check_bam_integrity()",
        "bypass": "Keep BAM enabled, don't delete the service",
    },
    "prefetch_integrity": {
        "what": "Compares prefetch file count vs Windows install date",
        "detection": "Too few files relative to install age = CLEARED",
        "function": "check_prefetch_integrity()",
        "bypass": "Don't bulk-delete prefetch; only remove specific cheat entries",
    },
    "shellbag_integrity": {
        "what": "Checks shellbag count and most recent entry age",
        "detection": "Very few entries or disabled logging -> MANIPULATED",
        "function": "scan_shellbags_for_cheats()",
        "bypass": "Don't wipe all shellbags; only remove cheat-folder entries (hard w/o tool)",
    },
    "amcache_integrity": {
        "what": "Checks Amcache.hve modification time and size",
        "detection": "Recent modification or stale/small file -> SUSPICIOUS",
        "function": "Multiple checks in _run_backend_scan_inner",
        "bypass": "Don't touch Amcache.hve modification time directly",
    },
    "shimcache_integrity": {
        "what": "Checks for recent ShimCache modifications",
        "detection": "Recent modification -> tampering warning",
        "function": "_run_shimcache()",
        "bypass": "Wipe AppCompatCache reg value + reboot (it regenerates cleanly)",
    },
    "eventlog_gaps": {
        "what": "Scans for gaps/clearing in event logs",
        "detection": "Log cleared event (ID 1102) or empty logs -> flagged",
        "function": "scan_eventlog_gaps()",
        "bypass": "Don't clear entire logs; ideally clean individual events",
    },
    "defender_integrity": {
        "what": "Checks Defender status, exclusions, and log health",
        "detection": "Disabled, exclusions added, or logs deleted -> flagged",
        "function": "check_defender_integrity()",
        "bypass": "Remove all Defender exclusions, re-enable if disabled",
    },
    "userassist_integrity": {
        "what": "Checks if UserAssist keys exist and have entries",
        "detection": "Key missing or cleaned -> flagged",
        "function": "get_userassist_bat_cmd_files()",
        "bypass": "Selectively remove entries (ROT13), don't delete entire key",
    },
    "vss_historical": {
        "what": "Mounts shadow copies and re-scans historical prefetch/BAM/UserAssist",
        "detection": "Evidence found in ANY shadow copy -> flagged",
        "function": "scan_vss_historical_sections()",
        "bypass": "DELETE ALL SHADOW COPIES before scan (vssadmin delete shadows /all)",
    },
}

# ============================================================================
# DATA COLLECTION (what Trinity uploads to trinity.ac/api/results)
# ============================================================================

COLLECTED_DATA = {
    "system_info":          "OS version, install date, build, hardware",
    "roblox_logs":          "All Roblox log files (including shadow copy recovery)",
    "roblox_accounts":      "Roblox user IDs from registry + local storage",
    "roblox_flags":         "ClientAppSettings / FFlag configurations",
    "discord_accounts":     "Discord account IDs from local storage",
    "discord_memory":       "Strings from Discord process memory",
    "system_memory":        "Strings from general process memory",
    "bam_activity":         "BAM execution records",
    "bam_tamper":           "BAM live-vs-hive comparison results",
    "prefetch_activity":    "Prefetch execution records",
    "prefetch_modules":     "DLLs loaded (from prefetch)",
    "shellbag_activity":    "Folder navigation history",
    "userassist_activity":  "Program execution history",
    "eventlog_gaps":        "Event log clearing evidence",
    "usn_events":           "NTFS journal activity",
    "recycle_bin":          "Deleted file info",
    "usb_history":          "USB device connection history",
    "jumplist_hits":        "Recent/pinned program entries",
    "pca_traces":           "Program Compatibility Assistant data",
    "defender_integrity":   "Defender status/exclusions/log health",
    "registry_activity":    "General registry traces",
    "deleted_cheat_hits":   "Evidence of deleted cheat files",
    "vss_historical":       "Shadow copy recovered evidence",
}

# ============================================================================
# NETWORK ENDPOINTS
# ============================================================================

NETWORK = {
    "api_base":     "https://trinity.ac",
    "api_results":  "https://trinity.ac/api/results",
    "virustotal":   "https://www.virustotal.com/api/v3/files/",
    "roblox_users": "https://users.roblox.com/v1/users",
    "roblox_games": "https://www.roblox.com/games/",
    "roblox_users_profile": "https://www.roblox.com/users/",
}


def print_report():
    """Print the full Trinity analysis report."""
    print("=" * 80)
    print("  TRINITY.EXE — FULL REVERSE ENGINEERING REPORT")
    print("  Generated from IDA Pro MCP analysis")
    print("=" * 80)

    print("\n[BINARY INFO]")
    for k, v in TRINITY_INFO.items():
        print(f"  {k:20s}: {v}")

    print("\n[BUNDLED FORENSIC TOOLS]")
    for tool, desc in BUNDLED_TOOLS.items():
        print(f"  {tool:35s} — {desc}")

    print("\n[SCAN FLOW]")
    print(SCAN_FLOW)

    print(f"\n[EXECUTOR DETECTIONS] ({len(EXECUTOR_DETECTIONS)} executors)")
    for kw, tag in sorted(EXECUTOR_DETECTIONS.items()):
        print(f"  {kw:30s} -> {tag}")

    print(f"\n[EXECUTOR API SIGNATURES] ({len(EXECUTOR_API_SIGNATURES)} functions)")
    for sig in EXECUTOR_API_SIGNATURES:
        print(f"  {sig}")

    print(f"\n[FFLAG DETECTIONS] ({len(FFLAG_DETECTIONS)} patterns)")
    for kw, tag in sorted(FFLAG_DETECTIONS.items()):
        print(f"  {kw:25s} -> {tag}")

    print(f"\n[TAMPER DETECTION CHECKS] ({len(TAMPER_CHECKS)} checks)")
    for name, info in TAMPER_CHECKS.items():
        print(f"\n  [{name}]")
        for k, v in info.items():
            print(f"    {k:12s}: {v}")

    print(f"\n[DATA UPLOADED TO trinity.ac/api/results] ({len(COLLECTED_DATA)} fields)")
    for field, desc in COLLECTED_DATA.items():
        print(f"  {field:30s}: {desc}")

    print(f"\n[NETWORK ENDPOINTS]")
    for name, url in NETWORK.items():
        print(f"  {name:25s}: {url}")

    print("\n" + "=" * 80)
    print("  END OF REPORT")
    print("=" * 80)


if __name__ == "__main__":
    print_report()
