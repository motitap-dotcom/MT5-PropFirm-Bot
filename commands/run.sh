#!/bin/bash
# =============================================================
# Manual deploy + recompile + restart EA
# =============================================================

echo "============================================"
echo "  MANUAL DEPLOY + RECOMPILE"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_BASE/MQL5/Experts/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# 1. Update repo
echo "=== [1] Updating repo ==="
cd "$REPO_DIR"
git fetch origin
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $BRANCH"
git pull origin claude/debug-bot-transactions-g9Mpr 2>&1 || git pull 2>&1
echo ""

# 2. Copy EA files
echo "=== [2] Copying EA files ==="
cp -v EA/*.mq5 "$EA_DIR/" 2>&1
cp -v EA/*.mqh "$EA_DIR/" 2>&1
echo ""

# 3. Copy config files
echo "=== [3] Copying config files ==="
cp -v configs/*.json "$MT5_BASE/MQL5/Files/PropFirmBot/" 2>&1
echo ""

# 4. Check timestamps before compile
echo "=== [4] Before compile ==="
echo "Source:"
ls -la "$EA_DIR/PropFirmBot.mq5" 2>/dev/null
echo "Compiled:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

# 5. Compile EA
echo "=== [5] Compiling EA ==="
export DISPLAY=:99
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "$MT5_BASE/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>&1 || true
sleep 5
echo ""

# 6. Check compilation result
echo "=== [6] After compile ==="
echo "Compiled:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""
# Check compile log
if [ -f "$EA_DIR/PropFirmBot.log" ]; then
    echo "Compile log:"
    cat "$EA_DIR/PropFirmBot.log" | tr -d '\0'
fi
echo ""

# 7. Restart MT5 to load new EA
echo "=== [7] Restarting MT5 ==="
# Kill MT5
pkill -f terminal64.exe 2>/dev/null
sleep 3

# Verify killed
if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 still running, force killing..."
    kill -9 $(pgrep -f terminal64.exe) 2>/dev/null
    sleep 2
fi
echo "MT5 stopped"

# Start MT5
cd "$MT5_BASE"
DISPLAY=:99 WINEPREFIX=/root/.wine wine terminal64.exe &
sleep 10

# Check if running
if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 RESTARTED successfully (PID: $(pgrep -f terminal64.exe | head -1))"
else
    echo "ERROR: MT5 failed to start!"
fi
echo ""

# 8. Wait for EA to init and check log
echo "=== [8] Waiting for EA init (15 sec)... ==="
sleep 15
TODAY=$(date '+%Y%m%d')
EA_LOG="$MT5_BASE/MQL5/Logs/${TODAY}.log"
if [ -f "$EA_LOG" ]; then
    echo "EA Log (last 30 lines):"
    tail -30 "$EA_LOG" | tr -d '\0'
else
    echo "No EA log yet"
fi
echo ""

echo "============================================"
echo "  DONE $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
