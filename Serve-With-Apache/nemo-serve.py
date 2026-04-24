#!/usr/bin/env python3
"""
nemo-serve.py — Nemo action script to serve a directory/file via Apache on port 6161.
Usage: nemo-serve.py <path>
"""

import sys
import os
import subprocess
import shutil
import tempfile

PORT = 6161
VHOST_DEST = "/etc/apache2/sites-enabled/nemo-dev.conf"
VHOST_TMP  = "/tmp/nemo-dev.conf"
BROWSER_CMD = "xdg-open"

VHOST_TEMPLATE = """<VirtualHost *:{port}>
    ServerName localhost
    DocumentRoot "{docroot}"

    <Directory "{docroot}">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \\.php$>
        SetHandler application/x-httpd-php
    </FilesMatch>

    ErrorLog /tmp/nemo-apache-error.log
    CustomLog /tmp/nemo-apache-access.log combined
</VirtualHost>
"""

def notify(title, message, urgency="normal"):
    """Send a desktop notification."""
    try:
        subprocess.Popen([
            "notify-send",
            "-i", "network-server",
            "-u", urgency,
            title,
            message
        ])
    except FileNotFoundError:
        pass  # notify-send not installed, silently skip

def check_apache():
    """Make sure apache2 is installed."""
    if not shutil.which("apache2ctl"):
        notify("Dev Server Error", "apache2 is not installed or not in PATH.", "critical")
        sys.exit(1)

def ensure_port_listener():
    """
    Make sure Apache is listening on port 6161.
    Adds the port to /etc/apache2/ports.conf if missing.
    """
    ports_file = "/etc/apache2/ports.conf"
    listen_line = f"Listen {PORT}\n"
    try:
        with open(ports_file, "r") as f:
            content = f.read()
        if listen_line.strip() not in content:
            tmp = "/tmp/nemo-ports.conf"
            with open(tmp, "w") as f:
                f.write(content)
                if not content.endswith("\n"):
                    f.write("\n")
                f.write(listen_line)
            subprocess.run(["sudo", "cp", tmp, ports_file], check=True)
    except Exception as e:
        notify("Dev Server Warning", f"Could not update ports.conf: {e}", "normal")

def write_vhost(docroot):
    """Write the vhost config to a temp file, then sudo-copy it into place."""
    config = VHOST_TEMPLATE.format(port=PORT, docroot=docroot)
    with open(VHOST_TMP, "w") as f:
        f.write(config)
    result = subprocess.run(
        ["sudo", "cp", VHOST_TMP, VHOST_DEST],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        notify("Dev Server Error", f"Could not write vhost config:\n{result.stderr}", "critical")
        sys.exit(1)

def reload_apache():
    """Graceful reload — no downtime."""
    result = subprocess.run(
        ["sudo", "apache2ctl", "graceful"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        notify("Dev Server Error", f"Apache reload failed:\n{result.stderr}", "critical")
        sys.exit(1)

def enable_mod(mod):
    """Enable an Apache module if not already enabled."""
    mod_path = f"/etc/apache2/mods-enabled/{mod}.load"
    if not os.path.exists(mod_path):
        subprocess.run(["sudo", "a2enmod", mod],
                       capture_output=True)

def open_browser(url):
    """Open URL in default browser."""
    subprocess.Popen([BROWSER_CMD, url])

def main():
    if len(sys.argv) < 2:
        print("Usage: nemo-serve.py <path>")
        sys.exit(1)

    target = os.path.abspath(sys.argv[1])

    # Determine docroot and optional sub-path
    if os.path.isdir(target):
        docroot = target
        url_path = ""
    elif os.path.isfile(target):
        docroot = os.path.dirname(target)
        url_path = "/" + os.path.basename(target)
    else:
        notify("Dev Server Error", f"Path does not exist:\n{target}", "critical")
        sys.exit(1)

    check_apache()

    # Enable required modules
    enable_mod("rewrite")
    enable_mod("php")       # works for php8.x via libapache2-mod-php
    enable_mod("headers")

    ensure_port_listener()
    write_vhost(docroot)
    reload_apache()

    url = f"http://localhost:{PORT}{url_path}"
    open_browser(url)

    folder_display = docroot if len(docroot) <= 50 else "…" + docroot[-47:]
    notify(
        "Dev Server Ready",
        f"Serving: {folder_display}\n{url}"
    )

if __name__ == "__main__":
    main()
