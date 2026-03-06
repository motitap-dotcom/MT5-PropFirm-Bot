#!/bin/bash
# Try multiple methods to enable AutoTrading
echo "=== AUTOTRADING METHODS $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Install xdotool extras
apt-get install -y -qq xautomation xdotool wmctrl 2>/dev/null

echo "[1] Current AutoTrading log entries:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -5

echo "[2] Windows:"
W=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
CHART_W=$(xdotool search --name "EURUSD" 2>/dev/null | head -1)
echo "  Main: $W = $(xdotool getwindowname "$W" 2>/dev/null)"
echo "  Chart: $CHART_W = $(xdotool getwindowname "$CHART_W" 2>/dev/null)"

echo "[3] Method A: xdotool windowactivate + windowfocus + key --clearmodifiers"
if [ -n "$W" ]; then
    xdotool windowactivate --sync "$W" 2>/dev/null
    xdotool windowfocus --sync "$W" 2>/dev/null
    sleep 1
    xdotool key --clearmodifiers ctrl+e
    sleep 2
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1
fi

echo "[4] Method B: xdotool keydown/keyup"
if [ -n "$W" ]; then
    xdotool windowactivate --sync "$W" 2>/dev/null
    sleep 1
    xdotool keydown ctrl
    xdotool key e
    xdotool keyup ctrl
    sleep 2
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1
fi

echo "[5] Method C: xte (xautomation)"
if which xte >/dev/null 2>&1 && [ -n "$W" ]; then
    xdotool windowactivate --sync "$W" 2>/dev/null
    sleep 1
    xte 'keydown Control_L' 'key e' 'keyup Control_L'
    sleep 2
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1
else
    echo "  xte not available"
fi

echo "[6] Method D: xdotool to chart window"
if [ -n "$CHART_W" ]; then
    xdotool windowactivate --sync "$CHART_W" 2>/dev/null
    xdotool windowfocus --sync "$CHART_W" 2>/dev/null
    sleep 1
    xdotool key --clearmodifiers ctrl+e
    sleep 2
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1
fi

echo "[7] Method E: restart MT5 and modify terminal.ini while stopped"
# Kill MT5
screen -X -S mt5 quit 2>/dev/null
pkill -9 -f terminal64.exe 2>/dev/null
sleep 3

# Read full terminal.ini content
echo "  Current terminal.ini:"
cat "$MT5/config/terminal.ini" 2>/dev/null | tr -d '\0' | head -30

# Create a clean terminal.ini with all AutoTrading settings
cat > "$MT5/config/terminal.ini" << 'INIEOF'
[Common]
AutoTrading=1
ExpertsEnabled=1

[Network]
Enable=1

[Experts]
AutoTrading=1
AllowLiveTrading=1
AllowDLL=0
Enabled=1
Account=0
Profile=0
INIEOF

# Also ensure common.ini has AutoTrading
if ! grep -q "\[Common\]" "$MT5/config/common.ini" 2>/dev/null; then
    echo -e "\n[Common]\nAutoTrading=1" >> "$MT5/config/common.ini"
fi
sed -i 's/AutoTrading=0/AutoTrading=1/g' "$MT5/config/common.ini" 2>/dev/null

# Start MT5 fresh
echo "  Starting MT5..."
cd "$MT5"
screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
sleep 20

# Check if AutoTrading is now ON
echo "[8] After restart check:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
echo "  Last 5 lines:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "=== DONE $(date -u) ==="
