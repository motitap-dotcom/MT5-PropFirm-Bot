#!/bin/bash
# =============================================================
# Check today's trades from MT5
# =============================================================

echo "============================================"
echo "  Check Today's Trades"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
FILES_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"

# Check trade journal files
echo "=== [1] Trade Journal Files ==="
ls -la "$FILES_DIR/"*trade*  "$FILES_DIR/"*journal* "$FILES_DIR/"*Trade* "$FILES_DIR/"*Journal* 2>/dev/null || echo "No trade journal files found"
echo ""

# Check today's log files
echo "=== [2] Today's MT5 Logs ==="
TODAY=$(date '+%Y%m%d')
find "$MT5_DIR/MQL5/Logs/" -name "*${TODAY}*" -o -name "*.log" -newer /proc/1 2>/dev/null | head -5
echo ""

# Show latest log content (last 100 lines)
echo "=== [3] Latest EA Log Content ==="
LATEST_LOG=$(ls -t "$MT5_DIR/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $LATEST_LOG"
    echo "--- Last 100 lines ---"
    tail -100 "$LATEST_LOG" 2>/dev/null
else
    echo "No log files found"
fi
echo ""

# Check MT5 terminal log
echo "=== [4] MT5 Terminal Log (today) ==="
TERM_LOG=$(ls -t "$MT5_DIR/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "File: $TERM_LOG"
    grep -i "order\|trade\|deal\|position\|buy\|sell" "$TERM_LOG" 2>/dev/null | tail -50
fi
echo ""

# Check account status
echo "=== [5] Account Status ==="
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "No status file"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
