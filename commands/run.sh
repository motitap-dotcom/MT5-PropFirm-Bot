#!/bin/bash
# Full status check
echo "=== BOT STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
TERM_LOG_DIR="${MT5_BASE}/logs"
FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# 1. MT5 process
echo "--- MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5: RUNNING (PID=$MT5_PID)"
    ps -p $MT5_PID -o pid,etime,rss --no-headers 2>/dev/null
else
    echo "MT5: NOT RUNNING!"
fi

# 2. Status.json (EA writes this every tick)
echo ""
echo "--- status.json ---"
if [ -f "$FILES_DIR/status.json" ]; then
    cat "$FILES_DIR/status.json" 2>/dev/null
    echo ""
    echo "Last modified: $(stat -c '%y' "$FILES_DIR/status.json" 2>/dev/null)"
else
    echo "status.json not found"
fi

# 3. Recent EA logs
echo ""
echo "--- Recent EA Logs (last 50 lines) ---"
LATEST=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo "Log file: $LATEST"
    tail -50 "$LATEST" 2>&1
else
    echo "No EA log files found"
fi

# 4. Terminal logs
echo ""
echo "--- Terminal Logs (last 20 lines) ---"
TERM_LATEST=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LATEST" ]; then
    echo "Terminal log: $TERM_LATEST"
    tail -20 "$TERM_LATEST" 2>&1
else
    echo "No terminal log files found"
fi

# 5. Wine/Xvfb status
echo ""
echo "--- Wine/Display ---"
echo "Wine processes: $(pgrep -c -f wine 2>/dev/null || echo 0)"
echo "Xvfb: $(pgrep -f Xvfb > /dev/null 2>&1 && echo 'RUNNING' || echo 'NOT RUNNING')"
echo "DISPLAY=$DISPLAY"

# 6. Disk space
echo ""
echo "--- Disk Space ---"
df -h / | tail -1

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
