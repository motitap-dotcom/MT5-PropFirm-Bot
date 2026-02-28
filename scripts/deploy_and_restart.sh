#!/bin/bash
# Deploy updated EA files to VPS, recompile, and restart MT5
set -e

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"
NOW=$(date '+%Y-%m-%d %H:%M:%S UTC')

echo "============================================"
echo "  PropFirmBot - Deploy & Recompile"
echo "  $NOW"
echo "============================================"

# 1. Update repo
echo ""
echo ">>> Updating repo..."
cd "$REPO"
git fetch origin
# Try to checkout the new branch if it exists, else try old branch
git checkout claude/check-bot-status-1N9wR 2>/dev/null || git checkout claude/build-cfd-trading-bot-fl0ld 2>/dev/null || true
git pull origin $(git branch --show-current) 2>/dev/null || true
echo "Branch: $(git branch --show-current)"
echo "Latest commit: $(git log --oneline -1)"

# 2. Copy EA files
echo ""
echo ">>> Copying EA files..."
cp -v "$REPO/EA/PropFirmBot.mq5" "$EA_DIR/"
cp -v "$REPO/EA/SignalEngine.mqh" "$EA_DIR/"
cp -v "$REPO/EA/RiskManager.mqh" "$EA_DIR/"
cp -v "$REPO/EA/TradeManager.mqh" "$EA_DIR/"
cp -v "$REPO/EA/Guardian.mqh" "$EA_DIR/"
cp -v "$REPO/EA/Dashboard.mqh" "$EA_DIR/"
cp -v "$REPO/EA/TradeJournal.mqh" "$EA_DIR/"
cp -v "$REPO/EA/Notifications.mqh" "$EA_DIR/"
cp -v "$REPO/EA/NewsFilter.mqh" "$EA_DIR/"
cp -v "$REPO/EA/TradeAnalyzer.mqh" "$EA_DIR/"
cp -v "$REPO/EA/AccountStateManager.mqh" "$EA_DIR/"

echo ""
echo ">>> Files copied:"
ls -la "$EA_DIR/"

# 3. Compile EA
echo ""
echo ">>> Compiling EA..."
cd "$MT5"
METAEDITOR="$MT5/metaeditor64.exe"
if [ -f "$METAEDITOR" ]; then
    export DISPLAY=:99
    wine "$METAEDITOR" /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log:compile.log 2>/dev/null
    sleep 5
    echo "Compile log:"
    cat compile.log 2>/dev/null | tr -d '\0' || echo "(no compile log)"
    echo ""
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        echo "COMPILED: PropFirmBot.ex5 exists"
        ls -la "$EA_DIR/PropFirmBot.ex5"
    else
        echo "WARNING: PropFirmBot.ex5 not found after compile!"
    fi
else
    echo "WARNING: metaeditor64.exe not found at $METAEDITOR"
    echo "EA will be recompiled when MT5 restarts"
fi

# 4. Restart MT5
echo ""
echo ">>> Restarting MT5..."

# Kill existing MT5
pkill -f terminal64 2>/dev/null || true
sleep 3

# Make sure Xvfb is running
if ! pgrep -x Xvfb > /dev/null; then
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
export DISPLAY=:99

# Make sure x11vnc is running
if ! pgrep -x x11vnc > /dev/null; then
    echo "Starting x11vnc..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
    sleep 1
fi

# Start MT5
echo "Starting MT5..."
CONFIG="$MT5/config/startup.ini"
if [ -f "$CONFIG" ]; then
    wine "$MT5/terminal64.exe" /config:"$CONFIG" &
else
    wine "$MT5/terminal64.exe" &
fi
sleep 10

# 5. Verify
echo ""
echo ">>> Verification..."
MT5_PROC=$(ps aux | grep -i terminal64 | grep -v grep)
if [ -n "$MT5_PROC" ]; then
    echo "MT5: RUNNING"
    echo "$MT5_PROC"
else
    echo "MT5: NOT RUNNING - trying again..."
    wine "$MT5/terminal64.exe" &
    sleep 10
    ps aux | grep -i terminal64 | grep -v grep || echo "STILL NOT RUNNING!"
fi

echo ""
echo "Xvfb: $(pgrep -x Xvfb > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "x11vnc: $(pgrep -x x11vnc > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"

echo ""
echo ">>> EA .ex5 file:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "NOT FOUND"

echo ""
echo "============================================"
echo "  Deploy Complete - $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
