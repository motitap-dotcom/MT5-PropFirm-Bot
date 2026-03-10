#!/bin/bash
# =============================================================
# Restart MT5 to load newly compiled EA
# =============================================================

echo "============================================"
echo "  Restart MT5 to load new EA version"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

# 1. Show current .ex5 timestamp BEFORE restart
echo "=== [1] Current .ex5 (BEFORE restart) ==="
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

# 2. Kill MT5
echo "=== [2] Stopping MT5 ==="
pkill -f terminal64.exe 2>/dev/null
sleep 3
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "Force killing..."
    pkill -9 -f terminal64.exe 2>/dev/null
    sleep 2
fi
echo "MT5 stopped."
echo ""

# 3. Recompile to make sure .ex5 is fresh
echo "=== [3] Recompile EA ==="
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5
echo "Recompile done."
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

# 4. Start MT5
echo "=== [4] Starting MT5 ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "${MT5_BASE}"
wine terminal64.exe &
sleep 15
echo ""

# 5. Verify MT5 is running
echo "=== [5] Verify MT5 ==="
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "OK - MT5 is RUNNING (PID: $(pgrep -f terminal64.exe | head -1))"
else
    echo "ERROR - MT5 did not start!"
fi
echo ""

# 6. Check .ex5 timestamp AFTER
echo "=== [6] .ex5 file (AFTER restart) ==="
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

# 7. Wait for EA to initialize and check logs
echo "=== [7] EA Logs (waiting for init...) ==="
sleep 10
EA_LOGS="${MT5_BASE}/MQL5/Logs"
LATEST_EA_LOG=$(ls -t "$EA_LOGS"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA_LOG" ]; then
    echo "Log: $LATEST_EA_LOG"
    tail -30 "$LATEST_EA_LOG" 2>/dev/null
fi
echo ""

# 8. Check status.json
echo "=== [8] Status ==="
STATUS_FILE="${MT5_BASE}/MQL5/Files/PropFirmBot/status.json"
sleep 5
if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE" 2>/dev/null
else
    echo "Waiting for status..."
    sleep 10
    cat "$STATUS_FILE" 2>/dev/null || echo "No status yet"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
