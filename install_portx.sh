#!/bin/bash

set -e

INSTALL_DIR="/opt/port_limiter"
BIN_ALIAS="/usr/local/bin/portx"

echo "📦 Installing PortLimiterX..."

# 1. نصب پیش‌نیازها
echo "🔧 Installing dependencies (python3, jq, nftables)..."
apt update -y >/dev/null 2>&1
apt install -y python3 jq nftables >/dev/null 2>&1

# 2. ساخت مسیر نصب
mkdir -p $INSTALL_DIR
cp portlimiterx.sh $INSTALL_DIR/cli.sh
chmod +x $INSTALL_DIR/cli.sh

# 3. ایجاد alias با نام portx
echo "# PortLimiterX CLI alias" > $BIN_ALIAS
echo "#!/bin/bash" >> $BIN_ALIAS
echo "$INSTALL_DIR/cli.sh" >> $BIN_ALIAS
chmod +x $BIN_ALIAS

# 4. پیغام پایان
echo ""
echo "✅ PortLimiterX installed successfully!"
echo "🚀 Run it using: ${CYAN}portx${RESET}"
echo ""

# 5. فعال‌سازی nftables اگر فعال نیست
if ! systemctl is-active nftables >/dev/null 2>&1; then
    echo "🔒 Enabling nftables..."
    systemctl enable --now nftables
fi
