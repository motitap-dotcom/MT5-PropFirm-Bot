#!/bin/bash
# =============================================================
# Check EA logs + deploy updated RiskManager with wider spreads
# =============================================================

echo "============================================"
echo "  Deploy fix + Check EA logs"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

# Step 1: Pull latest code
echo "=== [1] Pull latest code ==="
cd "$REPO"
git fetch --all 2>&1
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull --rebase origin "$CURRENT_BRANCH" 2>&1 || git pull --ff-only origin "$CURRENT_BRANCH" 2>&1 || echo "Pull failed, using local files"
echo ""

# Step 2: Copy updated RiskManager
echo "=== [2] Copy updated RiskManager ==="
cp -v "$REPO"/EA/RiskManager.mqh "$EA_DIR/" 2>&1
echo ""

# Step 3: Check spread settings in new file
echo "=== [3] New spread settings ==="
grep -n "m_max_spread" "$EA_DIR/RiskManager.mqh" | head -5
echo ""

# Step 4: Show full EA log
echo "=== [4] EA Expert Log (last 80 lines) ==="
LATEST_LOG=$(ls -t "$MT5_BASE/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    # Remove Unicode padding for readability
    tail -80 "$LATEST_LOG" 2>/dev/null | sed 's/ \x00//g; s/\x00//g' | strings
else
    echo "(no log files found)"
fi
echo ""

# Step 5: Check terminal log too
echo "=== [5] Terminal Journal (last 30 lines) ==="
TERM_LOG=$(ls -t "$MT5_BASE/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "Log file: $TERM_LOG"
    tail -30 "$TERM_LOG" 2>/dev/null | sed 's/ \x00//g; s/\x00//g' | strings
else
    echo "(no terminal logs found)"
fi
echo ""

# Step 6: Restart MT5 to load new code
echo "=== [6] Restart MT5 ==="
pkill -f terminal64.exe 2>/dev/null || true
sleep 3

export DISPLAY=:99
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi

cd "$MT5_BASE"
WINEPREFIX=/root/.wine wine "$MT5_BASE/terminal64.exe" /login:11797849 /password:gazDE62## /server:FundedNext-Server &
sleep 15

# Step 7: Verify
echo "=== [7] Verify ==="
if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 is RUNNING"
else
    echo "MT5 FAILED to start!"
fi

# Check latest log after restart
echo ""
echo "=== [8] Post-restart log ==="
LATEST_LOG=$(ls -t "$MT5_BASE/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    tail -20 "$LATEST_LOG" 2>/dev/null | sed 's/ \x00//g; s/\x00//g' | strings
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
