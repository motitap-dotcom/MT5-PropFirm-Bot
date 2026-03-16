#!/bin/bash
# Restart MT5 to reset circuit breaker and load new EA code - 2026-03-16e
echo "=== MT5 RESTART $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

# 1. Try to recompile EA first (with the fixed Guardian.mqh)
echo "--- Attempting EA recompile ---"
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>&1 || echo "MetaEditor compile returned error (may still work)"
sleep 3
echo "ex5 file:"
ls -la PropFirmBot.ex5 2>/dev/null

# 2. Stop MT5 gracefully
echo ""
echo "--- Stopping MT5 ---"
MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    echo "Killing MT5 PID=$MT5_PID"
    kill "$MT5_PID" 2>/dev/null
    sleep 5
    # Force kill if still alive
    if kill -0 "$MT5_PID" 2>/dev/null; then
        echo "Force killing..."
        kill -9 "$MT5_PID" 2>/dev/null
        sleep 2
    fi
    echo "MT5 stopped"
else
    echo "MT5 was not running"
fi

# 3. Clean up any leftover wine processes for MT5
pkill -f "terminal64" 2>/dev/null || true
sleep 2

# 4. Start MT5
echo ""
echo "--- Starting MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
nohup wine "${MT5_BASE}/terminal64.exe" /portable > /dev/null 2>&1 &
echo "MT5 starting... PID=$!"

# 5. Wait for MT5 to initialize
echo "Waiting 30 seconds for MT5 to start and load EA..."
sleep 30

# 6. Verify MT5 is running
echo ""
echo "--- Verification ---"
if pgrep -f "terminal64" > /dev/null 2>&1; then
    NEW_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5: RUNNING (PID=$NEW_PID)"
else
    echo "MT5: NOT RUNNING - may need manual start via VNC!"
fi

# 7. Check status.json (should be fresh after EA reinit)
echo ""
echo "--- Status after restart ---"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
if [ -f "$EA_FILES_DIR/status.json" ]; then
    cat "$EA_FILES_DIR/status.json"
else
    echo "status.json not found yet (EA may still be initializing)"
fi

# 8. Check latest log for INIT messages
echo ""
echo "--- Latest EA Log (last 15 lines) ---"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
sleep 5
TODAY_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TODAY_LOG" ]; then
    echo "Log file: $(basename $TODAY_LOG)"
    iconv -f UTF-16LE -t UTF-8 "$TODAY_LOG" 2>/dev/null | tail -15
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
