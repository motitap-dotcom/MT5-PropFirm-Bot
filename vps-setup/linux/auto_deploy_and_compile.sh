#!/bin/bash
#=============================================================================
# PropFirmBot - ONE COMMAND AUTO DEPLOY + COMPILE
# This script does EVERYTHING: pull code, deploy EA, compile, report status
# Run: bash <(curl -s URL) OR paste into terminal
#=============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}  PropFirmBot - Auto Deploy & Compile    ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# --- Step 1: Pull latest code ---
echo -e "${YELLOW}[1/5] Pulling latest code...${NC}"
cd /root
if [ -d "MT5-PropFirm-Bot" ]; then
    cd MT5-PropFirm-Bot
    git fetch origin claude/build-cfd-trading-bot-fl0ld 2>/dev/null || true
    git checkout claude/build-cfd-trading-bot-fl0ld 2>/dev/null || true
    git pull origin claude/build-cfd-trading-bot-fl0ld 2>/dev/null || true
    echo -e "${GREEN}[OK] Code updated${NC}"
else
    echo -e "${YELLOW}Cloning repository...${NC}"
    git clone https://github.com/motitap-dotcom/MT5-PropFirm-Bot.git
    cd MT5-PropFirm-Bot
    git checkout claude/build-cfd-trading-bot-fl0ld
    echo -e "${GREEN}[OK] Code cloned${NC}"
fi

PROJECT_DIR="/root/MT5-PropFirm-Bot"
EA_SOURCE="$PROJECT_DIR/EA"
CONFIG_SOURCE="$PROJECT_DIR/configs"

# --- Step 2: Find MT5 installation ---
echo ""
echo -e "${YELLOW}[2/5] Finding MT5 installation...${NC}"

MT5_PATH=""
# Search common locations
for path in \
    "$HOME/.wine/drive_c/Program Files/MetaTrader 5" \
    "$HOME/.wine/drive_c/Program Files (x86)/MetaTrader 5" \
    "/root/.wine/drive_c/Program Files/MetaTrader 5" \
    "/root/.wine/drive_c/Program Files (x86)/MetaTrader 5"; do
    if [ -f "$path/terminal64.exe" ]; then
        MT5_PATH="$path"
        break
    fi
done

# Deep search if not found
if [ -z "$MT5_PATH" ]; then
    echo -e "${YELLOW}Searching deeper...${NC}"
    FOUND=$(find /root/.wine -name "terminal64.exe" 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        MT5_PATH=$(dirname "$FOUND")
    fi
fi

if [ -z "$MT5_PATH" ]; then
    echo -e "${RED}[ERROR] MT5 not found! Is MT5 installed?${NC}"
    echo -e "${YELLOW}Searching for any MT5 files...${NC}"
    find / -name "terminal64.exe" 2>/dev/null || echo "No MT5 found anywhere"
    exit 1
fi

echo -e "${GREEN}[OK] MT5 found: $MT5_PATH${NC}"

MQL5_PATH="$MT5_PATH/MQL5"
EA_DEST="$MQL5_PATH/Experts/PropFirmBot"

# --- Step 3: Copy EA files ---
echo ""
echo -e "${YELLOW}[3/5] Copying EA files to MT5...${NC}"

mkdir -p "$EA_DEST"

EA_FILES=(
    "PropFirmBot.mq5"
    "SignalEngine.mqh"
    "RiskManager.mqh"
    "TradeManager.mqh"
    "Guardian.mqh"
    "Dashboard.mqh"
    "TradeJournal.mqh"
    "Notifications.mqh"
    "NewsFilter.mqh"
    "TradeAnalyzer.mqh"
    "AccountStateManager.mqh"
)

COPIED=0
for file in "${EA_FILES[@]}"; do
    if [ -f "$EA_SOURCE/$file" ]; then
        cp -f "$EA_SOURCE/$file" "$EA_DEST/$file"
        echo -e "  ${GREEN}✓ $file${NC}"
        COPIED=$((COPIED + 1))
    else
        echo -e "  ${RED}✗ $file (NOT FOUND!)${NC}"
    fi
done

echo -e "${GREEN}[OK] Copied $COPIED/${#EA_FILES[@]} EA files${NC}"

# --- Step 4: Copy config files ---
echo ""
echo -e "${YELLOW}[4/5] Copying config files...${NC}"

CONFIG_DEST="$MQL5_PATH/Files/PropFirmBot"
mkdir -p "$CONFIG_DEST"

if [ -d "$CONFIG_SOURCE" ]; then
    CONFIG_COUNT=0
    for json_file in "$CONFIG_SOURCE"/*.json; do
        if [ -f "$json_file" ]; then
            cp -f "$json_file" "$CONFIG_DEST/"
            echo -e "  ${GREEN}✓ $(basename "$json_file")${NC}"
            CONFIG_COUNT=$((CONFIG_COUNT + 1))
        fi
    done
    echo -e "${GREEN}[OK] Copied $CONFIG_COUNT config files${NC}"
else
    echo -e "${YELLOW}[SKIP] No config folder found${NC}"
fi

# --- Step 5: Try to compile EA ---
echo ""
echo -e "${YELLOW}[5/5] Attempting to compile EA...${NC}"

METAEDITOR=""
if [ -f "$MT5_PATH/metaeditor64.exe" ]; then
    METAEDITOR="$MT5_PATH/metaeditor64.exe"
elif [ -f "$MT5_PATH/MetaEditor64.exe" ]; then
    METAEDITOR="$MT5_PATH/MetaEditor64.exe"
fi

if [ -n "$METAEDITOR" ]; then
    echo -e "${YELLOW}Found MetaEditor, compiling...${NC}"
    export DISPLAY=:99
    export WINEPREFIX=/root/.wine

    # Try command-line compilation
    wine "$METAEDITOR" /compile:"$EA_DEST/PropFirmBot.mq5" /log 2>/dev/null || true

    # Check if .ex5 was created
    if [ -f "$EA_DEST/PropFirmBot.ex5" ]; then
        echo -e "${GREEN}[OK] EA compiled successfully! PropFirmBot.ex5 created${NC}"
    else
        echo -e "${YELLOW}[INFO] Command-line compile didn't produce .ex5${NC}"
        echo -e "${YELLOW}You'll need to compile manually in MT5 (see instructions below)${NC}"
    fi
else
    echo -e "${YELLOW}[INFO] MetaEditor not found for command-line compilation${NC}"
    echo -e "${YELLOW}You'll need to compile manually in MT5 (see instructions below)${NC}"
fi

# --- Summary ---
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}  DEPLOYMENT COMPLETE!${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${CYAN}EA files location:${NC}"
echo -e "  $EA_DEST"
echo ""
echo -e "${CYAN}Config files location:${NC}"
echo -e "  $CONFIG_DEST"
echo ""

if [ ! -f "$EA_DEST/PropFirmBot.ex5" ]; then
    echo -e "${CYAN}TO COMPILE THE EA IN MT5:${NC}"
    echo -e "  1. In MT5, press ${YELLOW}F4${NC} to open MetaEditor"
    echo -e "  2. Click ${YELLOW}File → Open${NC}"
    echo -e "  3. Navigate to: ${YELLOW}Experts/PropFirmBot/PropFirmBot.mq5${NC}"
    echo -e "  4. Press ${YELLOW}F7${NC} (or click Compile)"
    echo -e "  5. Close MetaEditor (go back to MT5)"
    echo ""
fi

echo -e "${CYAN}TO ATTACH THE EA TO A CHART:${NC}"
echo -e "  1. In MT5, open a ${YELLOW}EURUSD${NC} chart"
echo -e "  2. In Navigator panel (left), expand ${YELLOW}Expert Advisors${NC}"
echo -e "  3. Find ${YELLOW}PropFirmBot/PropFirmBot${NC}"
echo -e "  4. ${YELLOW}Drag it onto the chart${NC} (or double-click)"
echo -e "  5. In settings, check ${YELLOW}'Allow Algo Trading'${NC}"
echo -e "  6. Click ${YELLOW}OK${NC}"
echo -e "  7. Click ${YELLOW}AutoTrading${NC} button in toolbar (make it green!)"
echo ""
echo -e "${GREEN}Done! The bot will start trading automatically.${NC}"
echo ""
