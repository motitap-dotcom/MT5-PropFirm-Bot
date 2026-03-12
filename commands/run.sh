#!/bin/bash
# Full status check
echo "=== VPS STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
TERM_LOG_DIR="${MT5_BASE}/logs"

# 1. MT5 Process
echo "--- MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5: RUNNING (PID=$MT5_PID)"
    echo "Uptime: $(ps -o etime= -p $MT5_PID 2>/dev/null)"
else
    echo "MT5: NOT RUNNING!"
fi

# 2. EA compiled file
echo ""
echo "--- EA Compiled File ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "No .ex5 file!"

# 3. Status.json
echo ""
echo "--- status.json ---"
if [ -f "$EA_FILES_DIR/status.json" ]; then
    cat "$EA_FILES_DIR/status.json" 2>&1
else
    echo "status.json not found"
fi

# 4. Recent EA logs
echo ""
echo "--- Latest EA Log (last 30 lines) ---"
LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $LATEST_LOG"
    tail -30 "$LATEST_LOG" 2>&1
else
    echo "No EA log files found"
fi

# 5. Terminal logs (last 20 lines)
echo ""
echo "--- Terminal Log (last 20 lines) ---"
TERM_LOG=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "File: $TERM_LOG"
    tail -20 "$TERM_LOG" 2>&1
else
    echo "No terminal log found"
fi

# 6. Connections
echo ""
echo "--- Network Connections ---"
ss -tnp 2>/dev/null | grep terminal64 | head -5 || echo "No MT5 connections"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
