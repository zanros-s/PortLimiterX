#!/bin/bash

set -e

INSTALL_DIR="/opt/port_limiter"
BIN_ALIAS="/usr/local/bin/portx"
LOG_FILE="/var/log/portlimiterx_install.log"

mkdir -p $(dirname "$LOG_FILE")

echo "🔧 [$(date)] Starting PortLimiterX installation..." | tee -a $LOG_FILE

if [ -f "$BIN_ALIAS" ]; then
  echo "✅ PortLimiterX already installed. Launching CLI..." | tee -a $LOG_FILE
  exec $BIN_ALIAS
fi

echo "📦 Installing PortLimiterX from GitHub..." | tee -a $LOG_FILE

# Dependencies
echo "📦 Installing dependencies..." | tee -a $LOG_FILE
apt update -y >> $LOG_FILE 2>&1
apt install -y python3 jq nftables curl >> $LOG_FILE 2>&1

# Create directory
mkdir -p $INSTALL_DIR

# Download components from GitHub raw
RAW_BASE="https://raw.githubusercontent.com/zanros-s/PortLimiterX/main"

download_file() {
  local URL=$1
  local OUT=$2
  echo "⬇️ Downloading $(basename "$OUT")..."
  curl -# -L "$URL" -o "$OUT"
  if [[ ! -s "$OUT" ]]; then
    echo "❌ Failed to download $(basename "$OUT"). File is missing or empty." | tee -a $LOG_FILE
    exit 1
  fi
}

download_file "$RAW_BASE/portlimiterx.sh" "$INSTALL_DIR/cli.sh"
download_file "$RAW_BASE/gen_port_script.py" "$INSTALL_DIR/gen_port_script.py"

chmod +x $INSTALL_DIR/cli.sh

# Create alias
echo "#!/bin/bash" > $BIN_ALIAS
echo "$INSTALL_DIR/cli.sh" >> $BIN_ALIAS
chmod +x $BIN_ALIAS

# Enable nftables
echo "🧯 Enabling nftables..." | tee -a $LOG_FILE
systemctl enable --now nftables >> $LOG_FILE 2>&1 || true

echo "✅ Installation complete. You can now run PortLimiterX using: portx" | tee -a $LOG_FILE
