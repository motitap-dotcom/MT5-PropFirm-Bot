#!/bin/bash
#=============================================================================
# PropFirmBot - EA Deployment for Ubuntu VPS
# Run: chmod +x 02_deploy_ea.sh && sudo ./02_deploy_ea.sh
#=============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  PropFirmBot - Deploy EA to MT5${NC}"
echo -e "${CYAN}  Step 2: Copy EA + Config files${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# --- Check root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root: sudo ./02_deploy_ea.sh${NC}"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")
BOT_DIR="$ACTUAL_HOME/PropFirmBot"

# --- Find MT5 installation ---
echo -e "${YELLOW}[1/4] Finding MT5 installation...${NC}"

MT5_PATH=""

# Check saved path
if [ -f "$BOT_DIR/mt5_path.txt" ]; then
    MT5_PATH=$(cat "$BOT_DIR/mt5_path.txt")
fi

# Search if not found
if [ -z "$MT5_PATH" ] || [ ! -d "$MT5_PATH" ]; then
    POSSIBLE_PATHS=(
        "$ACTUAL_HOME/.wine/drive_c/Program Files/MetaTrader 5"
        "$ACTUAL_HOME/.wine/drive_c/Program Files (x86)/MetaTrader 5"
    )
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$path/terminal64.exe" ]; then
            MT5_PATH="$path"
            break
        fi
    done
fi

if [ -z "$MT5_PATH" ] || [ ! -d "$MT5_PATH" ]; then
    echo -e "${RED}[ERROR] MT5 not found! Run 01_install_mt5.sh first.${NC}"
    echo -e "${YELLOW}Or find it manually: find ~/.wine -name terminal64.exe${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] MT5 found: $MT5_PATH${NC}"

# --- Find project EA source files ---
echo ""
echo -e "${YELLOW}[2/4] Locating EA source files...${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
EA_SOURCE="$PROJECT_DIR/EA"

# Fallback locations
if [ ! -d "$EA_SOURCE" ]; then
    EA_SOURCE="$BOT_DIR/EA"
fi
if [ ! -d "$EA_SOURCE" ]; then
    EA_SOURCE="$ACTUAL_HOME/MT5-PropFirm-Bot/EA"
fi

if [ ! -d "$EA_SOURCE" ]; then
    echo -e "${RED}[ERROR] EA source files not found!${NC}"
    echo -e "${YELLOW}Clone the project first:${NC}"
    echo -e "  git clone <repo-url> $ACTUAL_HOME/MT5-PropFirm-Bot"
    exit 1
fi

echo -e "${GREEN}[OK] EA source: $EA_SOURCE${NC}"

# --- Copy EA files to MT5 ---
echo ""
echo -e "${YELLOW}[3/4] Copying EA files to MT5...${NC}"

# MT5 MQL5 data folder (inside Wine)
MQL5_PATH="$MT5_PATH/MQL5"
EA_DEST="$MQL5_PATH/Experts/PropFirmBot"

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
        echo -e "  ${GREEN}[OK] $file${NC}"
        ((COPIED++))
    else
        echo -e "  ${YELLOW}[SKIP] $file (not found)${NC}"
    fi
done

echo -e "${GREEN}[OK] Copied $COPIED/${#EA_FILES[@]} EA files${NC}"

# --- Copy config files ---
echo ""
echo -e "${YELLOW}[4/4] Copying config files...${NC}"

CONFIG_SOURCE="$PROJECT_DIR/configs"
if [ ! -d "$CONFIG_SOURCE" ]; then
    CONFIG_SOURCE="$ACTUAL_HOME/MT5-PropFirm-Bot/configs"
fi

CONFIG_DEST="$MQL5_PATH/Files/PropFirmBot"
mkdir -p "$CONFIG_DEST"

if [ -d "$CONFIG_SOURCE" ]; then
    for json_file in "$CONFIG_SOURCE"/*.json; do
        if [ -f "$json_file" ]; then
            cp -f "$json_file" "$CONFIG_DEST/"
            echo -e "  ${GREEN}[OK] $(basename "$json_file")${NC}"
        fi
    done
else
    echo -e "  ${YELLOW}[SKIP] Config folder not found${NC}"
fi

# Fix permissions
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$MT5_PATH/MQL5"

# --- Create MT5 startup script ---
echo ""
echo -e "${YELLOW}Creating MT5 startup script...${NC}"

cat > "$BOT_DIR/start_mt5.sh" << STARTUP_EOF
#!/bin/bash
# Start MetaTrader 5 in headless mode
export DISPLAY=:99
export WINEPREFIX=$ACTUAL_HOME/.wine

# Start MT5
wine "$MT5_PATH/terminal64.exe" &
echo "MT5 started with PID: \$!"
echo "To view MT5 GUI, connect with VNC on port 5900"
STARTUP_EOF

chmod +x "$BOT_DIR/start_mt5.sh"
chown "$ACTUAL_USER:$ACTUAL_USER" "$BOT_DIR/start_mt5.sh"
echo -e "${GREEN}[OK] Startup script: $BOT_DIR/start_mt5.sh${NC}"

# --- Create VNC access script (optional) ---
cat > "$BOT_DIR/start_vnc.sh" << VNC_EOF
#!/bin/bash
# Start VNC server to view MT5 remotely
# Connect with any VNC client to VPS_IP:5900
export DISPLAY=:99
x11vnc -display :99 -forever -nopw -shared &
echo "VNC server started on port 5900"
echo "Connect with VNC client to your VPS IP:5900"
VNC_EOF

chmod +x "$BOT_DIR/start_vnc.sh"
chown "$ACTUAL_USER:$ACTUAL_USER" "$BOT_DIR/start_vnc.sh"
echo -e "${GREEN}[OK] VNC script: $BOT_DIR/start_vnc.sh (for remote viewing)${NC}"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  EA Deployment Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}NEXT STEPS:${NC}"
echo -e "1. Start MT5: ${YELLOW}$BOT_DIR/start_mt5.sh${NC}"
echo -e "2. (Optional) View MT5 GUI via VNC: ${YELLOW}$BOT_DIR/start_vnc.sh${NC}"
echo -e "3. Run monitoring: ${YELLOW}sudo ./03_monitor.sh${NC}"
echo ""
echo -e "${CYAN}TO LOG IN TO YOUR BROKER:${NC}"
echo -e "1. Start VNC: ${YELLOW}$BOT_DIR/start_vnc.sh${NC}"
echo -e "2. Connect VNC client to your VPS IP:5900"
echo -e "3. You'll see MT5 - log in with your broker credentials"
echo -e "4. Compile & attach the EA to a chart"
echo ""
