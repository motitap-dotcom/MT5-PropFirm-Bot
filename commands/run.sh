#!/bin/bash
# Deploy updated EA files and restart MT5
echo "=== DEPLOY HARDENING FIXES $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

# 1. Pull latest code
echo "--- Pulling latest code ---"
cd "$REPO"
git fetch origin claude/fix-bot-trading-config-N1uDv 2>&1
git checkout claude/fix-bot-trading-config-N1uDv 2>&1
git pull origin claude/fix-bot-trading-config-N1uDv 2>&1

# 2. Copy updated EA files
echo ""
echo "--- Copying EA files ---"
for f in "$REPO"/EA/*.mq5 "$REPO"/EA/*.mqh; do
    if [ -f "$f" ]; then
        cp -v "$f" "$EA_DIR/" 2>&1
    fi
done

# 3. Remove old .ex5 to force recompile
echo ""
echo "--- Removing old .ex5 ---"
rm -f "$EA_DIR/PropFirmBot.ex5"
echo "Removed PropFirmBot.ex5"

# 4. Restart MT5
echo ""
echo "--- Restarting MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    echo "Stopping MT5 (PID=$MT5_PID)..."
    kill "$MT5_PID" 2>/dev/null
    sleep 5
    if pgrep -f "terminal64.exe" > /dev/null; then
        echo "Force killing..."
        kill -9 "$MT5_PID" 2>/dev/null
        sleep 3
    fi
fi

echo "Starting MT5..."
cd "$MT5_BASE"
DISPLAY=:99 WINEPREFIX=/root/.wine nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
sleep 20

if pgrep -f "terminal64.exe" > /dev/null; then
    NEW_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5 started (PID=$NEW_PID)"
else
    echo "ERROR: MT5 failed to start!"
fi

# 5. Check compilation
sleep 10
echo ""
echo "--- .ex5 status ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "NO .ex5 - compilation may still be in progress"

# 6. Check new log for fix markers
echo ""
echo "--- New EA log (checking for hardening markers) ---"
EA_LATEST=$(ls -t "$MT5_BASE/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    TMPLOG="/tmp/ea_deploy.txt"
    iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
      sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"
    echo "Log: $EA_LATEST ($(wc -l < "$TMPLOG") lines)"
    echo ""
    echo "Init messages:"
    grep "\[INIT\]" "$TMPLOG" 2>/dev/null | tail -20
    echo ""
    echo "SignalEngine init (check for M15 forcing):"
    grep "\[SignalEngine\]" "$TMPLOG" 2>/dev/null | tail -10
    echo ""
    echo "Last 20 lines:"
    tail -20 "$TMPLOG"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
