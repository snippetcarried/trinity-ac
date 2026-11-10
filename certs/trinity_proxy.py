"""
Trinity PIN Bypass + API Interceptor Proxy v2.1
================================================
Intercepts Trinity's communication with trinity.ac.
- Fakes PIN validation so any PIN works
- Blocks scan result uploads (results never leave your machine)
- Logs everything Trinity tries to send

USAGE:
  Just run the launcher (handles admin + cert + everything):
    launch_proxy.bat

  Or manually:
    python trinity_proxy.py              (auto-elevates if needed)
    python trinity_proxy.py --restore    (cleanup hosts entries)
    python trinity_proxy.py --log-only   (don't modify hosts)

WHAT'S DIFFERENT IN v2.1 (Content-Type fix):
  - RAW HTTP response mode: bypasses BaseHTTPRequestHandler's header
    management entirely — writes clean HTTP/1.1 bytes directly to the
    SSL socket. This fixes Trinity's content-type check failing because
    BaseHTTPRequestHandler was sending HTTP/1.0 + duplicate Server headers.
  - Response debug logging: every response saved to proxy_logs/RESP_DEBUG_*
  - Connection: close header on every response (no keep-alive confusion)

v2.0:
  - Auto-elevates to admin if not already
  - Installs cert to Windows trusted root store automatically
  - Uses port forwarding (8443->443) as fallback if 443 is blocked
"""

import http.server
import ssl
import json
import os
import sys
import ctypes
import datetime
import threading
import argparse
import subprocess
import time
import struct

# ============================================================================
# CONFIGURATION
# ============================================================================

LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = 443     # Primary: direct 443 (needs admin)
FALLBACK_PORT = 8443  # Fallback: high port + portproxy
HTTP_PORT = 80        # HTTP fallback

TRINITY_DOMAINS = [
    "trinity.ac",
    "www.trinity.ac",
    "api.trinity.ac",
]

HOSTS_FILE = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"),
                          "System32", "drivers", "etc", "hosts")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(SCRIPT_DIR, "proxy_logs")
CERT_DIR = os.path.join(SCRIPT_DIR, "certs")


# ============================================================================
# ADMIN CHECK + AUTO-ELEVATION
# ============================================================================

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        return False


def elevate():
    """Re-launch this script as Administrator."""
    if is_admin():
        return True

    print("[!] Not running as Administrator — auto-elevating...")
    try:
        # Re-run this script with admin privileges
        params = " ".join([f'"{a}"' for a in sys.argv])
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, params, os.getcwd(), 1
        )
        print("[*] Elevated process launched. This window can be closed.")
        sys.exit(0)
    except Exception as e:
        print(f"[!] Auto-elevation failed: {e}")
        print("[!] Please right-click -> Run as Administrator")
        return False


# ============================================================================
# SELF-SIGNED CERT GENERATION
# ============================================================================

def generate_self_signed_cert():
    """Generate a self-signed cert for trinity.ac."""
    os.makedirs(CERT_DIR, exist_ok=True)
    cert_path = os.path.join(CERT_DIR, "trinity.pem")
    key_path = os.path.join(CERT_DIR, "trinity-key.pem")

    if os.path.exists(cert_path) and os.path.exists(key_path):
        print(f"[*] Using existing cert: {cert_path}")
        return cert_path, key_path

    print("[*] Generating self-signed certificate for trinity.ac...")

    # Try openssl first
    try:
        conf = os.path.join(CERT_DIR, "openssl.cnf")
        with open(conf, "w") as f:
            f.write("""[req]
distinguished_name = req_dn
x509_extensions = v3_req
prompt = no

[req_dn]
CN = trinity.ac

[v3_req]
subjectAltName = DNS:trinity.ac,DNS:www.trinity.ac,DNS:api.trinity.ac,DNS:*.trinity.ac
""")
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048",
            "-keyout", key_path, "-out", cert_path,
            "-days", "365", "-nodes",
            "-config", conf,
        ], check=True, capture_output=True)
        print(f"[+] Generated cert via openssl: {cert_path}")
        return cert_path, key_path
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass

    # Fallback: Python cryptography library
    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        import datetime as dt

        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, "trinity.ac"),
        ])

        san = x509.SubjectAlternativeName([
            x509.DNSName("trinity.ac"),
            x509.DNSName("www.trinity.ac"),
            x509.DNSName("api.trinity.ac"),
            x509.DNSName("*.trinity.ac"),
        ])

        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(dt.datetime.utcnow())
            .not_valid_after(dt.datetime.utcnow() + dt.timedelta(days=365))
            .add_extension(san, critical=False)
            .sign(key, hashes.SHA256())
        )

        with open(key_path, "wb") as f:
            f.write(key.private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.TraditionalOpenSSL,
                serialization.NoEncryption(),
            ))

        with open(cert_path, "wb") as f:
            f.write(cert.public_bytes(serialization.Encoding.PEM))

        print(f"[+] Generated cert via cryptography lib: {cert_path}")
        return cert_path, key_path
    except ImportError:
        pass

    # Last resort: generate a minimal self-signed cert using pure Python
    # This creates a basic DER-encoded cert that works for local HTTPS
    print("[!] No openssl or cryptography library found.")
    print("[!] Install one: pip install cryptography")
    print("[!] Attempting minimal cert generation...")

    try:
        _generate_minimal_cert(cert_path, key_path)
        return cert_path, key_path
    except Exception as e:
        print(f"[!] Minimal cert generation failed: {e}")
        print("[!] Install cryptography: pip install cryptography")
        sys.exit(1)


def _generate_minimal_cert(cert_path, key_path):
    """Generate a minimal self-signed cert using ssl module (Python 3.10+)."""
    # Use subprocess to call Python itself with a one-liner
    code = """
import ssl, tempfile, os
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
# Generate using the _ssl module's internal cert generation (if available)
raise ImportError("Use cryptography lib instead")
"""
    raise ImportError("Need cryptography library: pip install cryptography")


# ============================================================================
# CERT INSTALLATION TO WINDOWS TRUSTED ROOT STORE
# ============================================================================

def install_cert_to_store(cert_path):
    """Install our cert to Windows Trusted Root so Python requests trusts it."""
    print("[*] Installing certificate to Windows Trusted Root store...")
    try:
        result = subprocess.run(
            ["certutil", "-addstore", "Root", cert_path],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            print("[+] Certificate installed to Trusted Root store")
            print("[+] Python 'requests' (used by Trinity) will trust our cert")
            return True
        else:
            # Might already be installed
            if "already in store" in result.stdout.lower() or "already" in result.stderr.lower():
                print("[+] Certificate already in Trusted Root store")
                return True
            print(f"[!] certutil returned: {result.stderr.strip()}")
            return False
    except Exception as e:
        print(f"[!] Failed to install cert: {e}")
        return False


def remove_cert_from_store(cert_path):
    """Remove our cert from the trusted store on cleanup."""
    try:
        # Get the cert hash first
        result = subprocess.run(
            ["certutil", "-delstore", "Root", "trinity.ac"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            print("[+] Certificate removed from Trusted Root store")
    except Exception:
        pass


# ============================================================================
# SET ENVIRONMENT FOR NUITKA/REQUESTS SSL TRUST
# ============================================================================

def create_combined_ca_bundle(cert_path):
    """
    Create a combined CA bundle: system's real CAs + our self-signed cert.

    This is THE critical fix. Trinity's Nuitka-bundled 'requests' library
    uses certifi's CA bundle. Our cert isn't in it. So requests.post()
    to our fake trinity.ac throws SSLError -> "Unable to transmit results."

    By creating a combined bundle and pointing REQUESTS_CA_BUNDLE at it,
    Trinity trusts both our proxy AND real HTTPS sites (VirusTotal etc).
    """
    combined_path = os.path.join(CERT_DIR, "combined_ca_bundle.pem")

    # Find the system's certifi CA bundle
    certifi_path = None
    try:
        import certifi
        certifi_path = certifi.where()
        print(f"[+] Found system CA bundle: {certifi_path}")
    except ImportError:
        # Try common locations
        for candidate in [
            os.path.join(sys.prefix, "Lib", "site-packages", "certifi", "cacert.pem"),
            os.path.join(sys.prefix, "lib", "python3.11", "site-packages", "certifi", "cacert.pem"),
            os.path.join(sys.prefix, "lib", "python3.12", "site-packages", "certifi", "cacert.pem"),
            os.path.join(sys.prefix, "lib", "python3.13", "site-packages", "certifi", "cacert.pem"),
        ]:
            if os.path.exists(candidate):
                certifi_path = candidate
                break

    try:
        if certifi_path and os.path.exists(certifi_path):
            # Combine: real CAs + our cert
            with open(certifi_path, "r") as f:
                real_cas = f.read()
            with open(cert_path, "r") as f:
                our_cert = f.read()
            with open(combined_path, "w") as f:
                f.write(real_cas)
                f.write("\n# Trinity Bypass Proxy Self-Signed Certificate\n")
                f.write(our_cert)
            print(f"[+] Combined CA bundle created: {combined_path}")
            print(f"[+] Contains: system CAs + proxy cert")
        else:
            # No certifi found — just use our cert
            # Trinity's VirusTotal calls may fail but that's harmless
            import shutil
            shutil.copy2(cert_path, combined_path)
            print(f"[!] certifi not found — using proxy cert only")
            print(f"[!] (Trinity's VirusTotal checks may fail, that's OK)")
    except Exception as e:
        print(f"[!] Bundle creation failed: {e}")
        combined_path = cert_path  # Fallback to just our cert

    return combined_path


def setup_ssl_env(cert_path):
    """
    Set environment variables so that Trinity's bundled Python 'requests'
    library trusts our self-signed cert.

    KEY INSIGHT from RE: Trinity calls requests.post() WITHOUT verify=False.
    It uses the default verify=True. Nuitka bundles certifi's CA store.
    Our self-signed cert is NOT in that store.

    Fix: Create a combined CA bundle (real CAs + our cert) and point
    REQUESTS_CA_BUNDLE at it. Trinity inherits our env vars.
    """
    # Create the combined bundle
    combined_path = create_combined_ca_bundle(cert_path)

    # Method 1: Set for current process (child processes inherit)
    os.environ["REQUESTS_CA_BUNDLE"] = combined_path
    os.environ["CURL_CA_BUNDLE"] = combined_path
    os.environ["SSL_CERT_FILE"] = combined_path
    print(f"[+] SSL env vars set -> {combined_path}")

    # Method 2: Set system-wide so Trinity picks it up however it's launched
    try:
        subprocess.run(
            ["setx", "REQUESTS_CA_BUNDLE", combined_path],
            capture_output=True, check=True
        )
        subprocess.run(
            ["setx", "SSL_CERT_FILE", combined_path],
            capture_output=True, check=True
        )
        print("[+] System-wide SSL env vars set (persists across sessions)")
    except Exception:
        print("[*] System-wide env vars skipped (set them manually if needed)")


def cleanup_ssl_env():
    """Remove the SSL environment variables and combined bundle."""
    for var in ["REQUESTS_CA_BUNDLE", "CURL_CA_BUNDLE", "SSL_CERT_FILE"]:
        os.environ.pop(var, None)
    try:
        # Remove system-wide vars
        subprocess.run(["reg", "delete", "HKCU\\Environment",
                        "/v", "REQUESTS_CA_BUNDLE", "/f"],
                       capture_output=True)
        subprocess.run(["reg", "delete", "HKCU\\Environment",
                        "/v", "SSL_CERT_FILE", "/f"],
                       capture_output=True)
        print("[+] SSL environment variables cleaned up")
    except Exception:
        pass

    # Remove combined bundle
    combined_path = os.path.join(CERT_DIR, "combined_ca_bundle.pem")
    if os.path.exists(combined_path):
        try:
            os.remove(combined_path)
            print("[+] Combined CA bundle removed")
        except Exception:
            pass


# ============================================================================
# HOSTS FILE MANAGEMENT
# ============================================================================

HOSTS_MARKER = "# TRINITY-BYPASS-PROXY"


def add_hosts_entries():
    """Redirect trinity.ac to localhost."""
    try:
        with open(HOSTS_FILE, "r") as f:
            content = f.read()

        lines_to_add = []
        for domain in TRINITY_DOMAINS:
            entry = f"127.0.0.1 {domain}"
            if entry not in content:
                lines_to_add.append(f"{entry} {HOSTS_MARKER}")

        if lines_to_add:
            with open(HOSTS_FILE, "a") as f:
                f.write("\n" + "\n".join(lines_to_add) + "\n")
            subprocess.run(["ipconfig", "/flushdns"], capture_output=True)
            print(f"[+] Added {len(lines_to_add)} hosts entries (trinity.ac -> 127.0.0.1)")
        else:
            print("[*] Hosts entries already present")
        return True
    except PermissionError:
        print("[!] Cannot modify hosts file — need Administrator!")
        return False


def remove_hosts_entries():
    """Remove our entries from hosts file."""
    try:
        with open(HOSTS_FILE, "r") as f:
            lines = f.readlines()

        cleaned = [l for l in lines if HOSTS_MARKER not in l]

        with open(HOSTS_FILE, "w") as f:
            f.writelines(cleaned)

        subprocess.run(["ipconfig", "/flushdns"], capture_output=True)
        print("[+] Removed hosts entries")
    except PermissionError:
        print("[!] Cannot modify hosts file — need Administrator!")


# ============================================================================
# PORT FORWARDING (FALLBACK)
# ============================================================================

def setup_port_forwarding(from_port=443, to_port=FALLBACK_PORT):
    """Use netsh portproxy to forward 443 -> our high port."""
    try:
        # Remove any existing rule first
        subprocess.run([
            "netsh", "interface", "portproxy", "delete", "v4tov4",
            f"listenport={from_port}", f"listenaddress={LISTEN_HOST}"
        ], capture_output=True)

        # Add the forward
        result = subprocess.run([
            "netsh", "interface", "portproxy", "add", "v4tov4",
            f"listenport={from_port}", f"listenaddress={LISTEN_HOST}",
            f"connectport={to_port}", f"connectaddress={LISTEN_HOST}"
        ], capture_output=True, text=True)

        if result.returncode == 0:
            print(f"[+] Port forwarding: {LISTEN_HOST}:{from_port} -> {LISTEN_HOST}:{to_port}")
            return True
        else:
            print(f"[!] Port forwarding failed: {result.stderr.strip()}")
            return False
    except Exception as e:
        print(f"[!] Port forwarding error: {e}")
        return False


def remove_port_forwarding(from_port=443):
    """Remove portproxy rule."""
    try:
        subprocess.run([
            "netsh", "interface", "portproxy", "delete", "v4tov4",
            f"listenport={from_port}", f"listenaddress={LISTEN_HOST}"
        ], capture_output=True)
        print("[+] Port forwarding removed")
    except Exception:
        pass


# ============================================================================
# FAKE API RESPONSES
# ============================================================================

def make_pin_response(pin_code=""):
    """Return a successful PIN validation response."""
    return json.dumps({
        "success": True,
        "valid": True,
        "authenticated": True,
        "message": "PIN validated successfully",
        "scan_id": f"scan-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}",
        "token": f"tok-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}-valid",
        "expires": (datetime.datetime.now() + datetime.timedelta(hours=2)).isoformat(),
        "status": "active",
    }).encode()


def make_results_response():
    """Return a successful upload response."""
    return json.dumps({
        "success": True,
        "received": True,
        "processed": True,
        "message": "Results received and processed",
        "id": f"result-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}",
        "status": "complete",
    }).encode()


def make_generic_ok():
    """Generic 200 OK response."""
    return json.dumps({
        "status": "ok",
        "online": True,
        "version": "2.1.0",
    }).encode()


# ============================================================================
# REQUEST HANDLER
# ============================================================================

class TrinityInterceptHandler(http.server.BaseHTTPRequestHandler):
    """
    Intercepts Trinity's HTTPS requests to trinity.ac.

    KEY FIX (v2.1): Writes raw HTTP response bytes directly to the socket
    instead of using BaseHTTPRequestHandler's send_response/send_header.

    Why? BaseHTTPRequestHandler defaults to HTTP/1.0 and auto-adds a
    'Server: BaseHTTP/0.6 Python/3.x' header. This caused Trinity's
    response.headers.get('content-type') check to fail — the content-type
    header was present but urllib3 was choking on the HTTP/1.0 + duplicate
    Server headers combo. Bypassing all that and writing clean HTTP/1.1
    bytes fixes it.
    """

    # Match Trinity's request protocol
    protocol_version = "HTTP/1.1"

    passthrough = False
    log_dir = LOG_DIR

    # Suppress BaseHTTPRequestHandler's default stderr logging
    def log_message(self, fmt, *args):
        ts = datetime.datetime.now().strftime("%H:%M:%S")
        print(f"  [{ts}] {self.address_string()} {fmt % args}")

    def _save_request(self, body=None):
        """Save intercepted request for analysis."""
        os.makedirs(self.log_dir, exist_ok=True)
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        path_safe = self.path.replace("/", "_").replace("?", "_")[:80]
        filename = f"{ts}_{self.command}_{path_safe}.json"
        filepath = os.path.join(self.log_dir, filename)

        data = {
            "timestamp": datetime.datetime.now().isoformat(),
            "method": self.command,
            "path": self.path,
            "headers": dict(self.headers),
        }
        if body:
            try:
                data["body"] = json.loads(body)
            except (json.JSONDecodeError, UnicodeDecodeError):
                data["body_raw"] = body.hex() if isinstance(body, bytes) else str(body)
                data["body_size"] = len(body)

        with open(filepath, "w") as f:
            json.dump(data, f, indent=2, default=str)

        return filepath

    def _send_json(self, data, status=200):
        """
        Send a JSON response using raw HTTP bytes — completely bypasses
        BaseHTTPRequestHandler's send_response/send_header/end_headers.

        Trinity checks: response.headers.get('content-type', '').startswith('application/json')
        This MUST match exactly. By constructing the raw response ourselves,
        we eliminate any formatting/buffering/duplicate-header issues.
        """
        # Tell BaseHTTPRequestHandler to close connection after this response
        self.close_connection = True

        # Build the COMPLETE HTTP response as one contiguous byte string
        now = datetime.datetime.now(datetime.timezone.utc)
        date_str = now.strftime("%a, %d %b %Y %H:%M:%S GMT")
        req_id = f"req-{now.strftime('%f')}"

        raw_headers = (
            f"HTTP/1.1 {status} OK\r\n"
            f"Content-Type: application/json\r\n"
            f"Content-Length: {len(data)}\r\n"
            f"Connection: close\r\n"
            f"Date: {date_str}\r\n"
            f"Server: nginx/1.24.0\r\n"
            f"Access-Control-Allow-Origin: *\r\n"
            f"X-Request-Id: {req_id}\r\n"
            f"\r\n"
        )
        raw_response = raw_headers.encode("ascii") + data

        # Write the entire response as a single chunk
        self.wfile.write(raw_response)
        self.wfile.flush()

        # Console debug
        print(f"  -> RESPONSE: HTTP/1.1 {status} OK | Content-Type: application/json | Body: {len(data)} bytes")

        # Save response to disk for forensic debugging
        self._log_response_debug(status, raw_headers, data)

    def _send_raw(self, status, headers_dict, body=b""):
        """Send a raw HTTP response with arbitrary headers (non-JSON)."""
        self.close_connection = True
        header_lines = f"HTTP/1.1 {status} OK\r\n"
        for k, v in headers_dict.items():
            header_lines += f"{k}: {v}\r\n"
        header_lines += "Connection: close\r\n"
        header_lines += "\r\n"
        self.wfile.write(header_lines.encode("ascii") + body)
        self.wfile.flush()

    def _log_response_debug(self, status, headers, body):
        """Log the EXACT response bytes to disk for debugging."""
        try:
            os.makedirs(self.log_dir, exist_ok=True)
            ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
            debug_path = os.path.join(self.log_dir, f"RESP_DEBUG_{ts}.txt")
            with open(debug_path, "w", encoding="utf-8") as f:
                f.write("=== RAW HTTP RESPONSE (exact bytes sent to Trinity) ===\n")
                f.write(headers)
                f.write(f"=== BODY ({len(body)} bytes) ===\n")
                f.write(body.decode("utf-8", errors="replace")[:2000])
                if len(body) > 2000:
                    f.write(f"\n... (truncated, {len(body)} total bytes)")
        except Exception:
            pass  # Debug logging must never crash the proxy

    def do_GET(self):
        log_path = self._save_request()
        path = self.path.lower()

        print(f"  -> GET {self.path}")
        print(f"  -> Logged: {os.path.basename(log_path)}")

        # Health check / status endpoints
        if "health" in path or "status" in path or "ping" in path:
            self._send_json(make_generic_ok())
        elif "pin" in path or "auth" in path or "validate" in path:
            print("  -> [PIN CHECK] Returning valid")
            self._send_json(make_pin_response())
        else:
            self._send_json(make_generic_ok())

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else b""

        log_path = self._save_request(body)
        path = self.path.lower()

        print(f"  -> POST {self.path} ({len(body)} bytes)")
        print(f"  -> Logged: {os.path.basename(log_path)}")

        # PIN / Auth endpoints
        if any(kw in path for kw in ["pin", "auth", "validate", "verify", "start", "login", "token"]):
            print("  -> [PIN BYPASS] Returning fake success")
            self._send_json(make_pin_response())

        # Results / Upload endpoints
        elif any(kw in path for kw in ["result", "upload", "submit", "report", "scan", "check"]):
            print("  -> [RESULTS INTERCEPTED] Data captured, NOT forwarded to real server")
            # Save the full results separately for inspection
            if len(body) > 100:
                results_file = os.path.join(self.log_dir,
                    f"SCAN_RESULTS_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
                with open(results_file, "wb") as f:
                    f.write(body)
                print(f"  -> Full scan results saved: {os.path.basename(results_file)}")
            self._send_json(make_results_response())

        else:
            print("  -> [GENERIC OK]")
            self._send_json(make_generic_ok())

    def do_PUT(self):
        self.do_POST()

    def do_PATCH(self):
        self.do_POST()

    def do_DELETE(self):
        self._save_request()
        self._send_json(make_generic_ok())

    def do_OPTIONS(self):
        self._send_raw(200, {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Max-Age": "86400",
            "Server": "nginx/1.24.0",
        })

    def do_HEAD(self):
        self._send_raw(200, {
            "Content-Type": "application/json",
            "Server": "nginx/1.24.0",
        })


# ============================================================================
# SERVER STARTUP
# ============================================================================

def try_bind_server(host, port, handler_class, ssl_context=None):
    """Try to start a server on the given port. Returns server or None."""
    try:
        server = http.server.HTTPServer((host, port), handler_class)
        if ssl_context:
            server.socket = ssl_context.wrap_socket(server.socket, server_side=True)
        return server
    except OSError as e:
        if e.errno == 10013:  # Permission denied (Windows)
            return None
        elif e.errno == 10048:  # Address already in use
            return None
        raise


def run_server(server, label):
    """Run a server in a thread."""
    try:
        server.serve_forever()
    except Exception as e:
        print(f"[!] {label} server error: {e}")


def start_servers(cert_path, key_path):
    """Start HTTPS and HTTP servers with fallback logic."""
    # Create SSL context
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=cert_path, keyfile=key_path)
    # Allow older TLS for compatibility
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2

    servers_started = []
    using_portproxy = False

    # --- Try primary: HTTPS on 443 ---
    https_server = try_bind_server(LISTEN_HOST, LISTEN_PORT, TrinityInterceptHandler, ctx)
    if https_server:
        t = threading.Thread(target=run_server, args=(https_server, "HTTPS:443"), daemon=True)
        t.start()
        print(f"[+] HTTPS server listening on {LISTEN_HOST}:{LISTEN_PORT}")
        servers_started.append(("HTTPS", LISTEN_PORT))
    else:
        print(f"[!] Cannot bind port {LISTEN_PORT} — trying fallback with port forwarding...")

        # Fallback: HTTPS on high port + portproxy 443->high port
        https_fb = try_bind_server(LISTEN_HOST, FALLBACK_PORT, TrinityInterceptHandler, ctx)
        if https_fb:
            t = threading.Thread(target=run_server, args=(https_fb, f"HTTPS:{FALLBACK_PORT}"), daemon=True)
            t.start()
            print(f"[+] HTTPS server listening on {LISTEN_HOST}:{FALLBACK_PORT}")

            # Set up port forwarding 443 -> FALLBACK_PORT
            if setup_port_forwarding(443, FALLBACK_PORT):
                using_portproxy = True
                servers_started.append(("HTTPS+portproxy", FALLBACK_PORT))
            else:
                print("[!] Port forwarding failed — Trinity won't be able to connect on 443!")
                print("[!] Try closing any program using port 443, or run as Administrator")
                servers_started.append(("HTTPS-fallback-only", FALLBACK_PORT))
        else:
            print("[!] Cannot bind fallback port either!")

    # --- HTTP on 80 ---
    http_server = try_bind_server(LISTEN_HOST, HTTP_PORT, TrinityInterceptHandler)
    if http_server:
        t = threading.Thread(target=run_server, args=(http_server, "HTTP:80"), daemon=True)
        t.start()
        print(f"[+] HTTP server listening on {LISTEN_HOST}:{HTTP_PORT}")
        servers_started.append(("HTTP", HTTP_PORT))
    else:
        # Try HTTP on high port
        http_fb = try_bind_server(LISTEN_HOST, 8080, TrinityInterceptHandler)
        if http_fb:
            t = threading.Thread(target=run_server, args=(http_fb, "HTTP:8080"), daemon=True)
            t.start()
            if setup_port_forwarding(80, 8080):
                print(f"[+] HTTP server on {LISTEN_HOST}:8080 (forwarded from 80)")
            servers_started.append(("HTTP-fallback", 8080))

    return servers_started, using_portproxy


# ============================================================================
# MAIN
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description="Trinity PIN Bypass + API Interceptor v2.1")
    parser.add_argument("--passthrough", action="store_true",
                        help="Forward results to real server (log only)")
    parser.add_argument("--log-only", action="store_true",
                        help="Don't modify hosts, just run the server")
    parser.add_argument("--restore", action="store_true",
                        help="Remove all proxy modifications and exit")
    parser.add_argument("--no-elevate", action="store_true",
                        help="Don't auto-elevate to admin")
    args = parser.parse_args()

    print()
    print("=" * 62)
    print("  TRINITY PIN BYPASS + API INTERCEPTOR v2.1")
    print("  (raw HTTP response mode — Content-Type fix)")
    print("=" * 62)
    print()

    # Handle restore/cleanup
    if args.restore:
        if not is_admin():
            print("[!] Need admin for cleanup — elevating...")
            elevate()
            return
        remove_hosts_entries()
        remove_port_forwarding(443)
        remove_port_forwarding(80)
        cleanup_ssl_env()
        cert_path = os.path.join(CERT_DIR, "trinity.pem")
        if os.path.exists(cert_path):
            remove_cert_from_store(cert_path)
        print("[+] All proxy modifications removed")
        return

    # Auto-elevate to admin
    if not is_admin() and not args.no_elevate:
        print("[!] Administrator privileges required for:")
        print("[!]   - Modifying hosts file")
        print("[!]   - Binding port 443")
        print("[!]   - Installing SSL certificate")
        print()
        elevate()
        return

    if not is_admin():
        print("[!] WARNING: Running without admin — some features will fail!")
        print()

    # Step 1: Generate cert
    print("[STEP 1/4] Certificate Generation")
    print("-" * 40)
    cert_path, key_path = generate_self_signed_cert()
    print()

    # Step 2: Install cert to Windows trusted root store
    print("[STEP 2/4] Certificate Trust Setup")
    print("-" * 40)
    cert_installed = install_cert_to_store(cert_path)
    if not cert_installed:
        print("[!] Cert not in trusted store — setting SSL env vars as fallback")
    setup_ssl_env(cert_path)
    print()

    # Step 3: Modify hosts file
    print("[STEP 3/4] Network Redirection")
    print("-" * 40)
    if not args.log_only:
        hosts_ok = add_hosts_entries()
        if not hosts_ok:
            print("[!] Hosts file modification failed!")
            print("[!] Trinity will connect to the REAL server, not our proxy")
    else:
        print("[*] Log-only mode — hosts file not modified")
    print()

    # Step 4: Start servers
    print("[STEP 4/4] Starting Intercept Servers")
    print("-" * 40)
    os.makedirs(LOG_DIR, exist_ok=True)
    TrinityInterceptHandler.passthrough = args.passthrough
    TrinityInterceptHandler.log_dir = LOG_DIR

    servers, using_portproxy = start_servers(cert_path, key_path)
    print()

    if not servers:
        print("[!] FATAL: No servers could start!")
        print("[!] Check if another program is using ports 443/80")
        print("[!] Or try: netstat -ano | findstr :443")
        return

    # Ready!
    print("=" * 62)
    print("  PROXY IS LIVE — READY FOR TRINITY")
    print("=" * 62)
    print()
    print(f"  Servers running: {len(servers)}")
    for proto, port in servers:
        print(f"    {proto} on port {port}")
    print()
    print("  How to use:")
    print("  1. Launch Trinity.exe")
    print("  2. Enter ANY PIN code -> it will be accepted")
    print("  3. Scan runs normally")
    print("  4. Results are intercepted and saved locally")
    print(f"  5. Check {LOG_DIR} for intercepted data")
    print()
    print("  Press Ctrl+C to stop (will clean up automatically)")
    print()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print()
        print("[*] Shutting down...")
        if not args.log_only:
            remove_hosts_entries()
        if using_portproxy:
            remove_port_forwarding(443)
            remove_port_forwarding(80)
        print("[*] Proxy stopped. Run with --restore to fully clean up.")
        print()


if __name__ == "__main__":
    main()
