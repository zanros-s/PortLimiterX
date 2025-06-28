#!/bin/bash

INSTALL_DIR="/opt/port_limiter"
mkdir -p $INSTALL_DIR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

TITLE="${CYAN}🔥 PortLimiterX — Smart Traffic Port Controller 🔥${RESET}"

# Ensure nftables setup
nft list table inet traffic >/dev/null 2>&1 || nft add table inet traffic
nft list chain inet traffic input >/dev/null 2>&1 || nft add chain inet traffic input { type filter hook input priority 0 \; }
nft list chain inet traffic output >/dev/null 2>&1 || nft add chain inet traffic output { type filter hook output priority 0 \; }

show_menu() {
  echo ""
  echo -e "$TITLE"
  echo -e "${YELLOW}==============================================${RESET}"
  echo -e "${GREEN}1.${RESET} ➕ Add new port limit"
  echo -e "${GREEN}2.${RESET} 🛠 Edit existing port limit"
  echo -e "${GREEN}3.${RESET} ❌ Remove a specific port"
  echo -e "${GREEN}4.${RESET} 🧹 Remove all limits"
  echo -e "${GREEN}5.${RESET} 📊 View port usage"
  echo -e "${GREEN}6.${RESET} 🚪 Exit"
  echo -e "${YELLOW}==============================================${RESET}"
  read -p "Select an option: " OPTION
  case $OPTION in
    1) add_limit ;;
    2) edit_limit ;;
    3) remove_port ;;
    4) remove_all ;;
    5) view_usage ;;
    6) exit 0 ;;
    *) echo -e "${RED}❌ Invalid option.${RESET}"; show_menu ;;
  esac
}

add_limit() {
  read -p "Port number: " PORT
  read -p "Traffic limit (MB): " LIMIT

  echo -e "➕ Adding port ${CYAN}$PORT${RESET} with limit ${YELLOW}${LIMIT}MB${RESET}"

  bash $INSTALL_DIR/cli.sh internal_remove $PORT

  nft add rule inet traffic input tcp dport $PORT counter accept 2>/dev/null
  nft add rule inet traffic output tcp sport $PORT counter accept 2>/dev/null

  python3 $INSTALL_DIR/gen_port_script.py $PORT $LIMIT
  systemctl daemon-reload
  systemctl enable --now port-limit-$PORT.service
  echo -e "${GREEN}✅ Port $PORT activated with limit.${RESET}"
  show_menu
}

edit_limit() {
  read -p "Port to edit: " PORT
  if [[ ! -f "$INSTALL_DIR/traffic_$PORT.json" ]]; then
    echo -e "${RED}❌ No limit found for port $PORT.${RESET}"
    show_menu
    return
  fi
  read -p "New traffic limit (MB): " LIMIT
  echo -e "🔁 Updating limit for port ${CYAN}$PORT${RESET} to ${YELLOW}${LIMIT}MB${RESET} ..."
  bash $INSTALL_DIR/cli.sh internal_remove $PORT
  nft add rule inet traffic input tcp dport $PORT counter accept 2>/dev/null
  nft add rule inet traffic output tcp sport $PORT counter accept 2>/dev/null
  python3 $INSTALL_DIR/gen_port_script.py $PORT $LIMIT
  systemctl daemon-reload
  systemctl enable --now port-limit-$PORT.service
  echo -e "${GREEN}✅ Limit updated successfully.${RESET}"
  show_menu
}

remove_port() {
  read -p "Port to remove: " PORT
  internal_remove $PORT
  echo -e "${GREEN}✅ Port $PORT limit removed.${RESET}"
  show_menu
}

remove_all() {
  echo -e "${YELLOW}🚫 Removing all limits...${RESET}"
  for SERVICE in /etc/systemd/system/port-limit-*.service; do
    [ -e "$SERVICE" ] || continue
    PORT=$(basename "$SERVICE" | grep -oP '\d+')
    echo -e " → Removing port ${CYAN}$PORT${RESET}"
    internal_remove $PORT
  done
  echo -e "${GREEN}✅ All limits removed.${RESET}"
  show_menu
}

view_usage() {
  echo -e "\n📊 ${CYAN}Active Ports:${RESET}"
  for FILE in $INSTALL_DIR/traffic_*.json; do
    PORT=$(basename "$FILE" | grep -oP '\d+')
    echo -e " - Port $PORT"
  done
  read -p "Port to view: " PORT
  FILE="$INSTALL_DIR/traffic_$PORT.json"
  if [[ -f "$FILE" ]]; then
    TOTAL=$(jq -r '.total_mb' "$FILE")
    SERVICE=$(systemctl is-active port-limit-$PORT.service)
    SCRIPT=$(grep "LIMIT =" $INSTALL_DIR/monitor_$PORT.py | awk '{print $3}')
    LIMIT_MB=$((SCRIPT / 1024 / 1024))
    REMAIN=$(echo "$LIMIT_MB - $TOTAL" | bc)
    echo ""
    echo -e "${BLUE}┌──────────────────────────────────────────┐${RESET}"
    printf "${BLUE}│${RESET} 🔢 Current Usage:     ${YELLOW}%10.2f MB${RESET} ${BLUE}│\n" "$TOTAL"
    printf "${BLUE}│${RESET} 🎯 Max Limit:         ${YELLOW}%10.0f MB${RESET} ${BLUE}│\n" "$LIMIT_MB"
    printf "${BLUE}│${RESET} ⏳ Remaining:         ${YELLOW}%10.2f MB${RESET} ${BLUE}│\n" "$REMAIN"
    printf "${BLUE}│${RESET} 🔄 Service Status:    ${GREEN}%12s${RESET} ${BLUE}│\n" "$SERVICE"
    echo -e "${BLUE}└──────────────────────────────────────────┘${RESET}"
  else
    echo -e "${RED}❌ No data found for port $PORT.${RESET}"
  fi
  show_menu
}

internal_remove() {
  PORT=$1
  systemctl stop port-limit-$PORT.service 2>/dev/null
  systemctl disable port-limit-$PORT.service 2>/dev/null
  rm -f /etc/systemd/system/port-limit-$PORT.service
  nft delete rule inet traffic input tcp dport $PORT 2>/dev/null
  nft delete rule inet traffic output tcp sport $PORT 2>/dev/null
  rm -f "$INSTALL_DIR/monitor_$PORT.py"
  rm -f "$INSTALL_DIR/traffic_$PORT.json"
  rm -f "/var/log/port_limit_$PORT.log"
}

if [[ "$1" == "internal_remove" ]]; then
  internal_remove $2
  exit 0
fi

show_menu
