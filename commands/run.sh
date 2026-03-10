#!/bin/bash
# Quick verification: Is the NEW compiled EA loaded?
echo "=== Quick EA Verify $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA="${MT5}/MQL5/Experts/PropFirmBot"

echo ""
echo "=== .ex5 file ==="
ls -la "$EA/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "=== MT5 process ==="
pgrep -a terminal64 2>/dev/null || echo "NOT RUNNING"

echo ""
echo "=== Latest EA log entries ==="
EA_LOG_DIR="${MT5}/MQL5/Logs"
LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    # Convert from UTF-16 and show last 20 lines
    iconv -f UTF-16LE -t UTF-8 "$LATEST_LOG" 2>/dev/null | tail -20 || tail -20 "$LATEST_LOG" 2>/dev/null
else
    echo "No logs found in $EA_LOG_DIR"
    # Try terminal logs
    TERM_LOG_DIR="${MT5}/logs"
    LATEST_TERM=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_TERM" ]; then
        echo "Terminal log: $LATEST_TERM"
        tail -20 "$LATEST_TERM" 2>/dev/null
    fi
fi

echo ""
echo "=== DONE ==="
