# Trinity Bypass Toolkit

> **⚠️ WORK IN PROGRESS — This toolkit is not finished yet. last update: 11/10/26
**

> **⚠️ READ THIS — run emegency_clean.bat and replicatedpc_check.bat / any tools as administrator or else they will not work.
**

**Completely open source.** Use it, fork it, improve it.

**Credits:** [@snippetcarried](https://github.com/snippetcarried) (meko) · [@lovecooler](https://github.com/lovecooler) (cooler)

Full bypass suite for **[Trinity](https://trinity.ac/)**, a Roblox PC checker. Built from IDA Pro reverse engineering of the Nuitka-compiled binary (`Trinity.exe`).

Includes a MITM proxy for PIN bypass + result interception, two forensic cleaners (CMD stealth + PowerShell), a complete reverse engineering database, and one-click launchers.

---

## Project Structure

```
trinity_bypass/
├── certs/
│   ├── openssl.cnf                 # SAN config for cert generation
│   ├── trinity.pem                 # Self-signed cert (auto-generated)
│   ├── trinity-key.pem             # Private key (auto-generated)
│   └── combined_ca_bundle.pem      # Certifi CAs + proxy cert (auto-generated)
├── proxy_logs/                     # Intercepted requests + scan results (gitignored)
├── trinity_proxy.py                # MITM proxy — PIN bypass + API interceptor
├── trinity_stealth.bat             # CMD-native forensic cleaner (zero PS footprint)
├── trinity_cleaner.ps1             # PowerShell forensic cleaner (more thorough)
├── trinity_report.py               # Full RE database — every detection vector
├── make_bundle.py                  # Builds combined CA bundle for Trinity's requests lib
├── launch_trinity.bat              # One-click launcher (cert + proxy + Trinity)
├── launch_proxy.bat                # Simple proxy launcher with auto-elevation
├── README.txt                      # Legacy docs
└── .gitignore
```

---

## Tools

### `trinity_proxy.py` — MITM Proxy

The core of the bypass. Intercepts all communication between Trinity and `trinity.ac`.

**What it does:**
- Redirects `trinity.ac`, `www.trinity.ac`, and `api.trinity.ac` to `127.0.0.1` via the hosts file
- Runs a local HTTPS server with a self-signed certificate matching Trinity's domain
- Builds a combined CA bundle (system certifi CAs + our cert) so Trinity's Nuitka-bundled `requests` library trusts the proxy
- Installs the cert to the Windows Trusted Root store as a fallback
- Accepts **any PIN code** — always returns a valid authentication response
- Intercepts scan result uploads — data is saved locally, never forwarded to Trinity's servers
- Logs every request to `proxy_logs/` with full headers and body
- Falls back to port 8443 + `netsh portproxy` if port 443 is occupied

**Why raw HTTP responses:** Trinity's bundled `requests` library chokes on `BaseHTTPRequestHandler`'s default `HTTP/1.0` response + duplicate `Server` header. The proxy writes raw `HTTP/1.1` bytes directly to the socket to fix this.

**Why a combined CA bundle:** Trinity ships with Nuitka-compiled Python that bundles its own `certifi` CA store. Our self-signed cert isn't in it, so `requests.get()` throws `SSLError`. The combined bundle merges the real CAs with our proxy cert, and `REQUESTS_CA_BUNDLE` / `SSL_CERT_FILE` env vars point Trinity at it.

```
python trinity_proxy.py                # start (auto-elevates to admin)
python trinity_proxy.py --restore      # remove all modifications
python trinity_proxy.py --log-only     # intercept without modifying hosts
python trinity_proxy.py --no-elevate   # skip auto-elevation (used by launchers)
```

---

### `trinity_stealth.bat` — CMD Stealth Cleaner

Forensic cleaner written entirely in `cmd.exe` — **zero PowerShell footprint**.

**Why this exists:** Trinity checks PowerShell event logs for `.ps1` script execution in the last 7 days. Running `trinity_cleaner.ps1` itself becomes evidence. This `.bat` file uses only `cmd.exe` built-ins and native Windows tools.

**The stealth technique:**
1. **Phase 0** — Disable PowerShell event log channels with `wevtutil sl /e:false`
2. Do all the cleaning (phases 1–19)
3. Delete the `.evtx` log files while channels are offline
4. **Phase 20** — Re-enable channels with `wevtutil sl /e:true`
5. Windows creates fresh `.evtx` files — looks like normal log rotation
6. No Event ID 1102 ("log was cleared"), no timestamp gaps, no coordinated clearing

**20 cleaning phases:**

| Phase | Target | What it cleans |
|-------|--------|----------------|
| 0 | Event Log Channels | Disables PS logging before any action |
| 1 | Network | Blocks `trinity.ac` via hosts + firewall rule |
| 2 | Prefetch | Deletes `.pf` files matching executor keywords |
| 3 | BAM | Cleans Background Activity Monitor (both registry paths) |
| 4 | UserAssist | Skipped (ROT13 needs PowerShell — run PS cleaner 7+ days early) |
| 5 | ShimCache | Wipes `AppCompatCache` registry value (`/AGGRESSIVE`) |
| 6 | Amcache | Reports status (locked by Windows — needs WinPE) |
| 7 | Event Logs | Deletes PS + Defender `.evtx` files, leaves System/Security/App alone |
| 8 | Recycle Bin | Empties `C:\$Recycle.Bin` |
| 9 | Jump Lists | Keyword match on Recent, wipe Auto/Custom destinations (`/AGGRESSIVE`) |
| 10 | ShellBags | Wipes all BagMRU/Bags registry keys (`/AGGRESSIVE`) |
| 11 | VSS | Deletes all Volume Shadow Copies |
| 12 | Roblox | Cleans logs, flags ClientAppSettings and bootstrappers |
| 13 | Discord | Reports storage paths (left intact — cleaning = logout) |
| 14 | PCA | Cleans Program Compatibility Assistant traces (`/AGGRESSIVE`) |
| 15 | SRUM | Stops DiagTrack, deletes `SRUDB.dat` (`/AGGRESSIVE`) |
| 16 | Defender | Fixes `DisableAntiSpyware=1`, reports exclusions |
| 17 | USN Journal | Deletes and recreates NTFS journal (`/AGGRESSIVE`) |
| 18 | Temp | Keyword match on `%TEMP%` files |
| 19 | Registry | Cleans MUICache entries |
| 20 | Event Log Channels | Re-enables PS logging (fresh logs created) |

```
trinity_stealth.bat                        # normal run
trinity_stealth.bat /AGGRESSIVE            # wipe ShimCache, ShellBags, SRUM, USN, PCA
trinity_stealth.bat /DRYRUN                # preview without changes
trinity_stealth.bat /SKIPVSS               # skip shadow copy deletion
trinity_stealth.bat /SKIPNET               # skip network blocking
trinity_stealth.bat /AGGRESSIVE /SKIPVSS   # combine flags
```

---

### `trinity_cleaner.ps1` — PowerShell Cleaner

More thorough than the `.bat` version — can decode ROT13 UserAssist entries and do selective registry edits. But **Trinity will see it in PowerShell event logs** if run within 7 days of a scan.

**Use case:** Run this 7+ days before a Trinity scan to handle UserAssist and anything the `.bat` can't do, then use the stealth `.bat` for last-minute cleanup.

Same 19 phases as the stealth cleaner (minus Phase 0/20 event log suspension), plus full UserAssist ROT13 decoding and selective cleanup.

```powershell
.\trinity_cleaner.ps1                      # normal run
.\trinity_cleaner.ps1 -Aggressive          # nuclear options (ShimCache, ShellBags, SRUM, USN)
.\trinity_cleaner.ps1 -DryRun              # preview
.\trinity_cleaner.ps1 -SkipVSS             # skip shadow copies
.\trinity_cleaner.ps1 -SkipNetwork         # skip hosts/firewall
```

---

### `trinity_report.py` — RE Database

Complete reverse engineering reference extracted from IDA Pro analysis of `Trinity.exe`.

**Contains:**
- **Binary metadata** — compiler, GUI framework, API endpoints, auth flow
- **Bundled tools** — Eric Zimmerman forensic suite (PECmd, MFTECmd, SBECmd, AmcacheParser, AppCompatCacheParser, SrumECmd, JLECmd)
- **Full scan flow** — call chain from `TrinityApp.__init__()` through all scan phases
- **44 executor keywords** — exact string matches from IDA (`synapse x`, `scriptware`, `solara`, `krnl`, etc.)
- **40+ UNC API signatures** — executor function names Trinity searches for in logs and memory (`getrawmetatable`, `hookfunction`, `firesignal`, etc.)
- **18 FFlag/bootstrapper patterns** — Bloxstrap, Fishstrap, rbxfpsunlocker, specific FFlags
- **11 Roblox binary patterns** — process names, paths, Luau internals
- **9 integrity/tamper checks** — each with detection logic, function name, and bypass notes (BAM tamper, prefetch integrity, eventlog gaps, VSS historical, etc.)
- **23 uploaded data fields** — everything Trinity sends to `trinity.ac/api/results`
- **Network endpoints** — API, VirusTotal, Roblox user lookups

```
python trinity_report.py    # prints the full report to stdout
```

---

### `make_bundle.py` — CA Bundle Builder

Combines system `certifi` CAs with the proxy's self-signed cert into a single PEM file. Called by `launch_trinity.bat` during setup.

Trinity's Nuitka-compiled Python bundles its own `certifi` store. Without the combined bundle, `requests.get("https://trinity.ac")` throws `SSLError` because our proxy cert isn't trusted.

```
python make_bundle.py    # outputs certs/combined_ca_bundle.pem
```

---

### `launch_trinity.bat` — One-Click Launcher

Handles everything in sequence:

1. **Certificate** — generates if missing via `trinity_proxy.py`
2. **CA Bundle** — builds combined bundle via `make_bundle.py`
3. **SSL Environment** — sets `REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`, `CURL_CA_BUNDLE`
4. **Network + Proxy** — adds hosts entries, starts proxy in background
5. **Launch** — finds and runs `Trinity.exe` (checks Downloads, Desktop, parent dir, script dir, or asks)
6. **Cleanup** — kills proxy, removes port forwarding on exit

Auto-elevates to Administrator. Pass the path to `Trinity.exe` as an argument or let it search.

```
launch_trinity.bat                         # auto-find Trinity.exe
launch_trinity.bat "C:\path\to\Trinity.exe"  # specify path
```

---

### `launch_proxy.bat` — Simple Proxy Launcher

Minimal launcher — just auto-elevates and runs `trinity_proxy.py`. For when you want to start the proxy separately.

```
launch_proxy.bat    # double-click, it handles admin
```

---

## Trinity Detection Vectors

What Trinity scans for, and what each cleaner targets:

| Vector | How Trinity checks it | Cleaner coverage |
|--------|----------------------|------------------|
| **Prefetch** | `PECmd.exe` parses `.pf` files for executor names | Both cleaners delete matching `.pf` files |
| **BAM** | Reads live registry AND raw SYSTEM hive, compares for tampering | Both clean live registry; raw hive needs offline edit |
| **UserAssist** | ROT13-decoded program execution history | PS cleaner only (ROT13 decode) |
| **ShimCache** | `AppCompatCacheParser.exe` on binary blob | Both wipe with `/AGGRESSIVE` flag |
| **AmCache** | Checks `Amcache.hve` modification time and size | Flagged only — locked by Windows |
| **Event Logs** | Gap detection, Event ID 1102, coordinated clearing timestamps | Stealth `.bat` uses channel disable trick; PS cleaner does `wevtutil cl` |
| **SRUM** | `SrumECmd.exe` parses `SRUDB.dat` | Both delete with `/AGGRESSIVE` (stops DiagTrack first) |
| **USN Journal** | `MFTECmd.exe` on `$UsnJrnl:$J` | Both reset with `/AGGRESSIVE` (fsutil) |
| **VSS** | Mounts shadow copies, re-scans historical prefetch/BAM/UserAssist | Both delete all shadows |
| **ShellBags** | `SBECmd.exe` checks folder navigation history | Both wipe with `/AGGRESSIVE` |
| **Jump Lists** | `JLECmd.exe` parses recent/pinned items | Both do keyword + aggressive wipe |
| **Recycle Bin** | Scans `C:\$Recycle.Bin` for deleted cheat files | Both empty it |
| **Roblox Logs** | Searches log files for executor API calls | Both delete all logs |
| **Discord** | Harvests account IDs from local storage | Reported only (cleaning = logout) |
| **Process Memory** | Scans Discord + system process strings | Not cleanable pre-scan |
| **Defender** | Checks disabled status, exclusions, log health | Both fix `DisableAntiSpyware`, report exclusions |
| **PCA** | Program Compatibility Assistant traces | Both clean with `/AGGRESSIVE` |
| **Registry** | MUICache, general execution traces | Both do keyword match |

---

## Recommended Workflow

1. Run `trinity_cleaner.ps1 -Aggressive` **7+ days** before the scan (handles UserAssist ROT13)
2. Run `trinity_stealth.bat /AGGRESSIVE` right before the scan (no PS footprint)
3. **Reboot** (critical for ShimCache/Amcache regeneration)
4. Move/rename any cheat folders off Desktop and Downloads
5. Close all executor-related programs
6. Run `launch_trinity.bat` — enter any PIN
7. Results intercepted locally in `proxy_logs/`
8. Run `python trinity_proxy.py --restore` to clean up proxy modifications

---

## Requirements

- Windows 10/11
- Python 3.8+
- Administrator privileges

---

https://t.me/papaofskidisducduc
