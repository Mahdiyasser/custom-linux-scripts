#!/usr/bin/env bash
# setup.sh — One-time setup for nemo-serve
# Run with: bash setup.sh
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Nemo Dev Server — One-time Setup ===${NC}\n"

# 1. Check apache2
if ! command -v apache2ctl &>/dev/null; then
    echo -e "${RED}✗ apache2 not found. Install it first: sudo apt install apache2${NC}"
    exit 1
fi
echo -e "${GREEN}✓ apache2 found${NC}"

# 2. Copy the main script
echo "→ Installing nemo-serve.py to /usr/local/bin/"
sudo cp nemo-serve.py /usr/local/bin/nemo-serve.py
sudo chmod +x /usr/local/bin/nemo-serve.py
echo -e "${GREEN}✓ Script installed${NC}"

# 3. Install Nemo action
echo "→ Installing Nemo action..."
mkdir -p ~/.local/share/nemo/actions/
cp serve_here.nemo_action ~/.local/share/nemo/actions/
echo -e "${GREEN}✓ Nemo action installed${NC}"

# 4. Add sudoers rules (no password prompt for specific commands)
SUDOERS_FILE="/etc/sudoers.d/nemo-serve"
CURRENT_USER=$(whoami)

echo "→ Adding sudoers rules for passwordless apache reload..."
sudo bash -c "cat > $SUDOERS_FILE" << EOF
# Nemo dev server — allow graceful Apache reload and vhost config writes without password
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/sbin/apache2ctl graceful
$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/cp /tmp/nemo-dev.conf /etc/apache2/sites-enabled/nemo-dev.conf
$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/cp /tmp/nemo-ports.conf /etc/apache2/ports.conf
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/sbin/a2enmod rewrite
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/sbin/a2enmod php*
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/sbin/a2enmod headers
EOF
sudo chmod 440 $SUDOERS_FILE
echo -e "${GREEN}✓ Sudoers rules added${NC}"

# 5. Enable required Apache modules now
echo "→ Enabling Apache modules (rewrite, headers)..."
sudo a2enmod rewrite headers 2>/dev/null || true

# Try to enable php mod (could be php8.1, php8.2, php8.3...)
PHP_MOD=$(ls /etc/apache2/mods-available/php*.load 2>/dev/null | head -1 | xargs basename | sed 's/.load//')
if [ -n "$PHP_MOD" ]; then
    sudo a2enmod "$PHP_MOD" 2>/dev/null || true
    echo -e "${GREEN}✓ PHP module enabled: $PHP_MOD${NC}"
else
    echo -e "${YELLOW}⚠ No PHP Apache module found. Install with: sudo apt install libapache2-mod-php${NC}"
fi

# 6. Reload Apache to apply module changes
echo "→ Reloading Apache..."
sudo apache2ctl graceful
echo -e "${GREEN}✓ Apache reloaded${NC}"

# 7. Restart Nemo to pick up the new action
echo "→ Restarting Nemo..."
nemo -q 2>/dev/null || true
echo -e "${GREEN}✓ Nemo restarted${NC}"

echo ""
echo -e "${GREEN}=== All done! ===${NC}"
echo -e "Right-click any file or folder in Nemo and choose:"
echo -e "  ${YELLOW}\"Serve with Apache (port 6161)\"${NC}"
echo ""
echo -e "Apache error log: ${YELLOW}/tmp/nemo-apache-error.log${NC}"
echo -e "Apache access log: ${YELLOW}/tmp/nemo-apache-access.log${NC}"
