#!/bin/bash
# =============================================================
# Check Bot Transaction History
# =============================================================

echo "============================================"
echo "  Bot Transaction History"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DATA="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5"

# Check trade journal logs
echo "=== [1] Trade Journal Logs ==="
JOURNAL_DIR="$MT5_DATA/Files/PropFirmBot"
if [ -d "$JOURNAL_DIR" ]; then
    echo "Files in PropFirmBot directory:"
    ls -la "$JOURNAL_DIR/" 2>&1
    echo ""
    # Show any CSV trade logs
    for f in "$JOURNAL_DIR"/*.csv; do
        if [ -f "$f" ]; then
            echo "--- $(basename "$f") ---"
            cat "$f" 2>&1
            echo ""
        fi
    done
    # Show any trade log files
    for f in "$JOURNAL_DIR"/*trade* "$JOURNAL_DIR"/*Trade* "$JOURNAL_DIR"/*journal* "$JOURNAL_DIR"/*Journal*; do
        if [ -f "$f" ]; then
            echo "--- $(basename "$f") ---"
            cat "$f" 2>&1
            echo ""
        fi
    done
else
    echo "PropFirmBot directory not found"
fi
echo ""

# Check MT5 trade history from logs
echo "=== [2] MT5 Terminal Logs (recent) ==="
LOG_DIR="$MT5_DATA/../Logs"
if [ -d "$LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "Latest log: $(basename "$LATEST_LOG")"
        echo "--- Last 100 lines ---"
        tail -100 "$LATEST_LOG" 2>&1
    else
        echo "No log files found"
    fi
else
    echo "Logs directory not found"
fi
echo ""

# Check EA logs
echo "=== [3] EA Expert Logs ==="
EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
if [ -d "$EA_LOG_DIR" ]; then
    LATEST_EA_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_EA_LOG" ]; then
        echo "Latest EA log: $(basename "$LATEST_EA_LOG")"
        # Search for trade-related entries
        grep -i -E "(order|trade|deal|buy|sell|position|open|close|profit|loss)" "$LATEST_EA_LOG" 2>/dev/null | tail -50
    fi
fi
echo ""

# Check account status
echo "=== [4] Account Status JSON ==="
if [ -f "/var/bots/mt5_status.json" ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
else
    echo "Status file not found"
fi
echo ""

# Check if MT5 is running
echo "=== [5] MT5 Process Status ==="
pgrep -a terminal64 2>&1 || echo "MT5 not running"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
