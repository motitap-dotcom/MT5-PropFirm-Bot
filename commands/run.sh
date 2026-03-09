#!/bin/bash
# =============================================================
# Get today's trades and account analysis
# =============================================================

echo "============================================"
echo "  Trade Analysis - $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
DATA_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"

# 1. Account status
echo "=== [1] Account Status ==="
python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || echo "(status file not found)"
echo ""

# 2. Trade journal (EA writes trades here)
echo "=== [2] Trade Journal ==="
if ls "$DATA_DIR"/trade_journal*.csv 2>/dev/null; then
    for f in "$DATA_DIR"/trade_journal*.csv; do
        echo "--- File: $f ---"
        cat "$f"
        echo ""
    done
elif ls "$DATA_DIR"/TradeJournal*.csv 2>/dev/null; then
    for f in "$DATA_DIR"/TradeJournal*.csv; do
        echo "--- File: $f ---"
        cat "$f"
        echo ""
    done
else
    echo "(No trade journal CSV files found in $DATA_DIR)"
fi
echo ""

# 3. Check all files in PropFirmBot data dir
echo "=== [3] All files in PropFirmBot data directory ==="
ls -la "$DATA_DIR/" 2>/dev/null || echo "(directory not found)"
echo ""

# 4. MT5 trade history from logs
echo "=== [4] MT5 Terminal Logs (last 100 lines) ==="
LATEST_LOG=$(ls -t "$MT5_DIR"/Logs/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    tail -100 "$LATEST_LOG"
else
    echo "(No log files found)"
fi
echo ""

# 5. EA specific logs
echo "=== [5] EA Logs (today) ==="
TODAY=$(date '+%Y%m%d')
for logdir in "$MT5_DIR/MQL5/Logs" "$MT5_DIR/logs"; do
    if [ -d "$logdir" ]; then
        echo "Checking $logdir:"
        ls -la "$logdir/" 2>/dev/null
        LATEST=$(ls -t "$logdir"/*.log 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            echo "--- Latest: $LATEST ---"
            tail -100 "$LATEST"
        fi
        echo ""
    fi
done

# 6. Account history via MetaTrader report files
echo "=== [6] MT5 Report Files ==="
find "$MT5_DIR" -name "*.htm" -o -name "*.html" -o -name "*report*" -o -name "*history*" 2>/dev/null | head -20
echo ""

# 7. Check Wine MT5 process
echo "=== [7] MT5 Process Status ==="
ps aux | grep -i "terminal\|metatrader\|mt5" | grep -v grep
echo ""

# 8. Check account balance from status daemon
echo "=== [8] Status Daemon Logs ==="
journalctl -u mt5-status-daemon --no-pager -n 50 2>/dev/null || echo "(daemon not found)"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
