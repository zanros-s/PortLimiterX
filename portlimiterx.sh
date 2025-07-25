#!/bin/bash

INSTALL_DIR="/opt/port_limiter"
mkdir -p $INSTALL_DIR

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

show_menu() {
  echo -e "\n${CYAN}🚦 PortLimiterX - Traffic Limiter${RESET}"
  echo -e "==============================================="
  echo -e "${YELLOW}1.${RESET} Add new port limit"
  echo -e "${YELLOW}2.${RESET} Remove specific port limit"
  echo -e "${YELLOW}3.${RESET} Remove all port limits"
  echo -e "${YELLOW}4.${RESET} View usage for a port"
  echo -e "${YELLOW}5.${RESET} Full uninstall"
  echo -e "${YELLOW}6.${RESET} Exit"
  echo ""
  read -p "Choose an option [1-6]: " OPTION
  case $OPTION in
    1) add_limit ;;
    2) remove_port ;;
    3) remove_all ;;
    4) view_usage ;;
    5) full_uninstall ;;
    6) exit 0 ;;
    *) echo -e "${RED}❌ Invalid option.${RESET}"; show_menu ;;
  esac
}

add_limit() {
  read -p "Port number: " PORT
  read -p "Traffic limit (in MB): " LIMIT
  read -p "Check interval in seconds [default: 10]: " INTERVAL
  INTERVAL=${INTERVAL:-10}

  echo -e "${CYAN}➕ Adding port $PORT with $LIMIT MB limit and ${INTERVAL}s interval...${RESET}"

  bash $INSTALL_DIR/cli.sh internal_remove $PORT
  python3 $INSTALL_DIR/gen_port_script.py $PORT $LIMIT $INTERVAL
  systemctl daemon-reload
  systemctl enable --now port-limit-$PORT.service
  echo -e "${GREEN}✅ Port $PORT is now monitored.${RESET}"
  show_menu
}

remove_port() {
  read -p "Enter port to remove: " PORT
  internal_remove $PORT
  echo -e "${GREEN}✅ Limit removed for port $PORT.${RESET}"
  show_menu
}

remove_all() {
  echo -e "${YELLOW}🧹 Removing all port limits...${RESET}"
  for SERVICE in /etc/systemd/system/port-limit-*.service; do
    [ -f "$SERVICE" ] || continue
    PORT=$(basename "$SERVICE" | grep -oP '\d+')
    echo -e " → Removing port $PORT"
    internal_remove $PORT
  done
  echo -e "${GREEN}✅ All port limits removed.${RESET}"
  show_menu
}

view_usage() {
  echo ""
  echo -e "${CYAN}📊 Active monitored ports:${RESET}"
  FOUND=0
  for FILE in $INSTALL_DIR/traffic_*.json; do
    [ -f "$FILE" ] || continue
    PORT=$(basename "$FILE" | grep -oP '\d+')
    echo -e " - Port ${YELLOW}$PORT${RESET}"
    FOUND=1
  done
  [[ $FOUND -eq 0 ]] && echo -e "${RED}No usage data found.${RESET}" && show_menu

  read -p "Enter port to view usage: " PORT
  FILE="$INSTALL_DIR/traffic_$PORT.json"
  if [[ -f "$FILE" ]]; then
    TOTAL=$(jq .total_mb "$FILE")
    echo -e "\n${CYAN}Usage for port $PORT:${RESET}"
    echo -e "   → Total used: ${YELLOW}$TOTAL MB${RESET}"
    echo ""
  else
    echo -e "${RED}❌ No data found for port $PORT.${RESET}"
  fi
  show_menu
}

full_uninstall() {
  echo -e "${RED}⚠️  This will remove PortLimiterX completely.${RESET}"
  read -p "Are you sure? [y/N]: " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    remove_all
    rm -rf "$INSTALL_DIR"
    rm -f /usr/local/bin/portx
    echo -e "${GREEN}✅ Fully uninstalled.${RESET}"
    exit 0
  else
    show_menu
  fi
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
