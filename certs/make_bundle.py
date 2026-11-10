"""
Create a combined CA bundle: system certifi CAs + our self-signed proxy cert.
Used by launch_trinity.bat to make Trinity's requests lib trust our proxy.
"""
import sys, os, shutil

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cert_dir = os.path.join(script_dir, "certs")
    cert_file = os.path.join(cert_dir, "trinity.pem")
    combined = os.path.join(cert_dir, "combined_ca_bundle.pem")

    if not os.path.exists(cert_file):
        print(f"[!] Cert not found: {cert_file}")
        sys.exit(1)

    # Try to find certifi's CA bundle
    certifi_path = None
    try:
        import certifi
        certifi_path = certifi.where()
    except ImportError:
        pass

    if certifi_path and os.path.exists(certifi_path):
        # Combine: real CAs + our cert
        with open(certifi_path, "r") as f:
            real_cas = f.read()
        with open(cert_file, "r") as f:
            our_cert = f.read()
        with open(combined, "w") as f:
            f.write(real_cas)
            f.write("\n# Trinity Bypass Proxy Certificate\n")
            f.write(our_cert)
        print(f"[+] Combined bundle: certifi ({len(real_cas)} bytes) + proxy cert")
    else:
        # No certifi — just use our cert alone
        shutil.copy2(cert_file, combined)
        print("[!] certifi not found — using proxy cert only")
        print("[!] Trinity VirusTotal checks may fail (harmless)")

    print(f"[+] Bundle saved: {combined}")

if __name__ == "__main__":
    main()
