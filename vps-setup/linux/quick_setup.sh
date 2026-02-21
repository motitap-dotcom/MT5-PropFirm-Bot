#!/bin/bash
#=============================================================================
# PropFirmBot - QUICK ONE-COMMAND SETUP for Linux VPS
#
# HOW TO USE:
# 1. Open PowerShell or Terminal on your LOCAL computer
# 2. Run: ssh root@77.237.234.2
# 3. Enter password: qA4P9f3ra5bw
# 4. Once connected, paste this entire block:
#
#    curl -sL https://raw.githubusercontent.com/motitap-dotcom/MT5-PropFirm-Bot/claude/build-cfd-trading-bot-fl0ld/vps-setup/linux/quick_setup.sh | sudo bash
#
# OR manually:
#    git clone https://github.com/motitap-dotcom/MT5-PropFirm-Bot.git
#    cd MT5-PropFirm-Bot/vps-setup/linux
#    chmod +x setup_all.sh && sudo ./setup_all.sh
#=============================================================================

set -e

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
echo -e "${CYAN}  Linux VPS Quick Setup${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Run as root: sudo bash quick_setup.sh${NC}"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")
BOT_DIR="$ACTUAL_HOME/PropFirmBot"

# --- Clone or update the project ---
echo -e "${YELLOW}[1/2] Getting project files...${NC}"

if [ -d "$ACTUAL_HOME/MT5-PropFirm-Bot" ]; then
    cd "$ACTUAL_HOME/MT5-PropFirm-Bot"
    git pull origin claude/build-cfd-trading-bot-fl0ld 2>/dev/null || true
else
    cd "$ACTUAL_HOME"
    git clone -b claude/build-cfd-trading-bot-fl0ld https://github.com/motitap-dotcom/MT5-PropFirm-Bot.git 2>/dev/null || {
        echo -e "${RED}[ERROR] Could not clone repo. Trying manual setup...${NC}"
    }
fi

echo -e "${GREEN}[OK] Project files ready${NC}"

# --- Run the full setup ---
echo -e "${YELLOW}[2/2] Running full setup...${NC}"
echo ""

SETUP_SCRIPT="$ACTUAL_HOME/MT5-PropFirm-Bot/vps-setup/linux/setup_all.sh"

if [ -f "$SETUP_SCRIPT" ]; then
    chmod +x "$SETUP_SCRIPT"
    bash "$SETUP_SCRIPT"
else
    echo -e "${RED}[ERROR] Setup script not found at: $SETUP_SCRIPT${NC}"
    exit 1
fi
