#!/bin/bash

set -e

INSTALL_DIR="/opt/port_limiter"
BIN_ALIAS="/usr/local/bin/portx"

if [ -f "$BIN_ALIAS" ]; then
  echo "✅ PortLimiterX is already installed."
  echo "🚀 Launching CLI..."
  exec $BIN_ALIAS
fi

echo "📦 Installing PortLimiterX from GitHub..."

# Dependencies
apt update -y >/dev/null 2>&1
apt install -y python3 jq nftables curl >/dev/null 2>&1

# Create directory
mkdir -p $INSTALL_DIR

# Download components from GitHub raw
RAW_BASE="https://raw.githubusercontent.com/zanros-s/PortLimiterX/main"

echo "⬇️ Downloading files..."
curl -sSL "$RAW_BASE/portlimiterx.sh" -o $INSTALL_DIR/cli.sh
curl -sSL "$RAW_BASE/gen_port_script.py" -o $INSTALL_DIR/gen_port_script.py
chmod +x $INSTALL_DIR/cli.sh

# Create alias
echo "#!/bin/bash" > $BIN_ALIAS
echo "$INSTALL_DIR/cli.sh" >> $BIN_ALIAS
chmod +x $BIN_ALIAS

# Enable nftables
systemctl enable --now nftables >/dev/null 2>&1 || true

echo ""
echo "✅ Installed successfully!"
echo "🚀 Run PortLimiterX using: portx"
