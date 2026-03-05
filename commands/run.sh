#!/bin/bash
# =============================================================
# Deploy updated EA files and restart MT5
# =============================================================

echo "============================================"
echo "  Deploy EA + Restart MT5"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
CONFIG_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

# Step 1: Pull latest code
echo "=== [1] Pull latest code ==="
cd "$REPO"
git fetch --all 2>&1
git checkout claude/build-cfd-trading-bot-fl0ld 2>&1
git pull origin claude/build-cfd-trading-bot-fl0ld 2>&1
echo ""

# Step 2: Create directories
echo "=== [2] Create directories ==="
mkdir -p "$EA_DIR"
mkdir -p "$CONFIG_DIR"
ls -la "$EA_DIR/" 2>&1
echo ""

# Step 3: Copy EA files
echo "=== [3] Copy EA files ==="
cp -v "$REPO"/EA/*.mq5 "$EA_DIR/" 2>&1
cp -v "$REPO"/EA/*.mqh "$EA_DIR/" 2>&1
echo ""

# Step 4: Copy config files
echo "=== [4] Copy config files ==="
cp -v "$REPO"/configs/*.json "$CONFIG_DIR/" 2>&1 || echo "(no config files to copy)"
echo ""

# Step 5: List deployed files
echo "=== [5] Deployed files ==="
ls -la "$EA_DIR/" 2>&1
echo ""

# Step 6: Try to compile
echo "=== [6] Compile EA ==="
WINEPREFIX=/root/.wine wine "$MT5_BASE/metaeditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>/dev/null &
COMPILE_PID=$!
sleep 10
kill $COMPILE_PID 2>/dev/null || true
ls -la "$EA_DIR/"*.ex5 2>&1 && echo "Compilation OK" || echo "Warning: .ex5 not found - MT5 will compile on load"
echo ""

# Step 7: Restart MT5
echo "=== [7] Restart MT5 ==="
# Kill existing MT5
pkill -f terminal64.exe 2>/dev/null || true
sleep 3

# Ensure display is running
export DISPLAY=:99
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi

# Start MT5
cd "$MT5_BASE"
WINEPREFIX=/root/.wine wine "$MT5_BASE/terminal64.exe" /login:11797849 /password:gazDE62## /server:FundedNext-Server &
sleep 10

# Check if MT5 is running
echo "=== [8] Verify ==="
if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 is RUNNING"
else
    echo "MT5 FAILED to start!"
fi

# Check connections
ss -tnp | grep -i wine 2>/dev/null | head -5
echo ""

# Show latest terminal log
echo "=== [9] Terminal log (last 20 lines) ==="
LATEST_LOG=$(ls -t "$MT5_BASE/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    tail -20 "$LATEST_LOG" 2>/dev/null
else
    echo "(no log files found)"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
