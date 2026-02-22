#!/bin/bash
#=============================================================================
# PropFirmBot - FINISH SETUP (compile + attach EA + restart MT5)
# This is the LAST script you need to run!
#=============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}  PropFirmBot - Final Setup              ${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# --- Step 1: Compile EA ---
echo -e "${YELLOW}[1/4] Compiling EA...${NC}"
if [ -f "$MT5/metaeditor64.exe" ]; then
    wine "$MT5/metaeditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>/dev/null
    sleep 3
elif [ -f "$MT5/MetaEditor64.exe" ]; then
    wine "$MT5/MetaEditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>/dev/null
    sleep 3
fi

if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo -e "${GREEN}[OK] PropFirmBot.ex5 exists ($(stat -c%s "$EA_DIR/PropFirmBot.ex5") bytes)${NC}"
else
    echo -e "${RED}[WARNING] PropFirmBot.ex5 not found - will try to compile in MT5${NC}"
fi

# --- Step 2: Create chart template with EA attached ---
echo ""
echo -e "${YELLOW}[2/4] Creating chart template with EA...${NC}"

PROFILES_DIR="$MT5/MQL5/Profiles"
CHARTS_DIR="$PROFILES_DIR/Charts/Default"
mkdir -p "$CHARTS_DIR"

# Create a chart file for EURUSD with EA attached
cat > "$CHARTS_DIR/chart01.chr" << 'CHREOF'
<chart>
id=1
symbol=EURUSD
period_type=0
period_size=15
digits=5
point_size=0.000010
graph_mode=1
foreground=0
grid=0
volume=0
scroll=1
shift=1
ohlc=1
askline=1
days=1
descriptions=0
shift_size=20
fixed_pos=0
window_left=0
window_top=0
window_right=0
window_bottom=0
window_type=1
background_color=0
foreground_color=16777215
barup_color=65280
bardown_color=255
bullcandle_color=65280
bearcandle_color=255
chartline_color=65280
volumes_color=32768
grid_color=2105376
askline_color=255
stops_color=255

<expert>
name=PropFirmBot\PropFirmBot
path=Experts\PropFirmBot\PropFirmBot.ex5
expertmode=1
<inputs>
</inputs>
</expert>

<window>
height=200
fixed_height=0
<indicator>
name=main
</indicator>
</window>
</chart>
CHREOF

echo -e "${GREEN}[OK] Chart template created with EURUSD M15 + EA attached${NC}"

# --- Step 3: Enable AutoTrading in MT5 config ---
echo ""
echo -e "${YELLOW}[3/4] Enabling AutoTrading...${NC}"

# Find and update MT5 terminal.ini
INI_FILE="$MT5/terminal64.ini"
if [ ! -f "$INI_FILE" ]; then
    INI_FILE="$MT5/config/terminal.ini"
fi

if [ -f "$INI_FILE" ]; then
    # Enable Expert Advisors
    if grep -q "ExpertEnabled" "$INI_FILE"; then
        sed -i 's/ExpertEnabled=0/ExpertEnabled=1/' "$INI_FILE"
    else
        echo "ExpertEnabled=1" >> "$INI_FILE"
    fi
    if grep -q "ExpertAllowLive" "$INI_FILE"; then
        sed -i 's/ExpertAllowLive=0/ExpertAllowLive=1/' "$INI_FILE"
    else
        echo "ExpertAllowLive=1" >> "$INI_FILE"
    fi
    echo -e "${GREEN}[OK] AutoTrading enabled in config${NC}"
else
    echo -e "${YELLOW}[INFO] terminal.ini not found - you may need to enable AutoTrading manually${NC}"
fi

# --- Step 4: Restart MT5 ---
echo ""
echo -e "${YELLOW}[4/4] Restarting MT5 with EA...${NC}"

# Kill existing MT5
pkill -f terminal64.exe 2>/dev/null || true
sleep 3

# Start MT5
wine "$MT5/terminal64.exe" &
MT5_PID=$!
echo -e "${GREEN}[OK] MT5 started (PID: $MT5_PID)${NC}"

# Wait for MT5 to initialize
echo -e "${YELLOW}Waiting for MT5 to load (30 seconds)...${NC}"
sleep 30

# --- Done! ---
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}  SETUP COMPLETE!${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${GREEN}The bot should now be running on EURUSD M15.${NC}"
echo -e "${GREEN}Check your Telegram for notifications!${NC}"
echo ""
echo -e "${CYAN}To verify:${NC}"
echo -e "  - Open VNC and check MT5 - you should see the EA on the chart"
echo -e "  - The AutoTrading button should be green"
echo -e "  - Check Experts tab (bottom of MT5) for EA messages"
echo ""
echo -e "${CYAN}If AutoTrading is not green:${NC}"
echo -e "  - Click the AutoTrading button in the MT5 toolbar"
echo ""
