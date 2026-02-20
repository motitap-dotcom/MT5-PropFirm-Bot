#!/bin/bash
#=============================================================================
# PropFirmBot - One-Command Ubuntu VPS Setup
#
# Usage:
#   chmod +x setup_all.sh && sudo ./setup_all.sh
#
# This script runs all 3 steps automatically:
#   1. Install Wine + MT5
#   2. Deploy EA files
#   3. Set up monitoring
#=============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}"
echo "  ____                 _____ _                ____        _   "
echo " |  _ \ _ __ ___  _ __|  ___(_)_ __ _ __ ___ | __ )  ___ | |_ "
echo " | |_) | '__/ _ \| '_ \ |_  | | '__| '_ \` _ \|  _ \ / _ \| __|"
echo " |  __/| | | (_) | |_) |  _| | |  | | | | | | |_) | (_) | |_ "
echo " |_|   |_|  \___/| .__/|_|  |_|_|  |_| |_| |_|____/ \___/ \__|"
echo "                  |_|                                           "
echo -e "${NC}"
echo -e "${CYAN}  Ubuntu VPS Auto-Setup${NC}"
echo -e "${CYAN}  Installing Wine + MT5 + EA + Monitoring${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root: sudo ./setup_all.sh${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${YELLOW}========== STEP 1/3: Installing MT5 ==========${NC}"
echo ""
bash "$SCRIPT_DIR/01_install_mt5.sh"

echo ""
echo -e "${YELLOW}========== STEP 2/3: Deploying EA ==========${NC}"
echo ""
bash "$SCRIPT_DIR/02_deploy_ea.sh"

echo ""
echo -e "${YELLOW}========== STEP 3/3: Setting up monitoring ==========${NC}"
echo ""
bash "$SCRIPT_DIR/03_monitor.sh"

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")

echo ""
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}     VPS SETUP COMPLETE!${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}Your VPS is ready. Here's what to do next:${NC}"
echo ""
echo -e "${BOLD}1. Start MT5:${NC}"
echo -e "   ${YELLOW}sudo systemctl start mt5${NC}"
echo ""
echo -e "${BOLD}2. View MT5 GUI (to log in to broker):${NC}"
echo -e "   ${YELLOW}$ACTUAL_HOME/PropFirmBot/start_vnc.sh${NC}"
echo -e "   Then connect VNC client to ${BOLD}YOUR_VPS_IP:5900${NC}"
echo ""
echo -e "${BOLD}3. In MT5 (via VNC):${NC}"
echo -e "   a. Log in with your broker account"
echo -e "   b. Navigator -> Expert Advisors -> PropFirmBot"
echo -e "   c. Right-click PropFirmBot.mq5 -> Compile"
echo -e "   d. Drag PropFirmBot onto a chart"
echo -e "   e. Enable 'Algo Trading'"
echo ""
echo -e "${BOLD}4. Verify it's working:${NC}"
echo -e "   ${YELLOW}sudo systemctl status mt5${NC}"
echo -e "   ${YELLOW}tail -f $ACTUAL_HOME/PropFirmBot/logs/watchdog.log${NC}"
echo ""
echo -e "${CYAN}Useful commands:${NC}"
echo -e "  sudo systemctl start mt5    # Start MT5"
echo -e "  sudo systemctl stop mt5     # Stop MT5"
echo -e "  sudo systemctl status mt5   # Check status"
echo -e "  sudo systemctl restart mt5  # Restart MT5"
echo ""
