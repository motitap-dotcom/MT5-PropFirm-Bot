#!/bin/bash
# =============================================================
# Check today's trades from MT5 trade history
# =============================================================

echo "============================================"
echo "  Bot Trades Today - $(date '+%Y-%m-%d')"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
MQL5_FILES="$MT5_DIR/MQL5/Files/PropFirmBot"

# Check trade journal files
echo "=== [1] Trade Journal Logs ==="
JOURNAL_FILE="$MQL5_FILES/trade_journal.json"
if [ -f "$JOURNAL_FILE" ]; then
    echo "Journal file found:"
    cat "$JOURNAL_FILE" 2>/dev/null | python3 -m json.tool 2>/dev/null || cat "$JOURNAL_FILE" 2>/dev/null
else
    echo "No trade_journal.json found"
fi
echo ""

# Check trade journal CSV
echo "=== [2] Trade Journal CSV ==="
JOURNAL_CSV="$MQL5_FILES/trade_journal.csv"
if [ -f "$JOURNAL_CSV" ]; then
    echo "Journal CSV found:"
    cat "$JOURNAL_CSV" 2>/dev/null
else
    echo "No trade_journal.csv found"
fi
echo ""

# Check all log files for today's trades
echo "=== [3] Today's EA Logs ==="
TODAY=$(date '+%Y%m%d')
TODAY_DOT=$(date '+%Y.%m.%d')
LOG_DIR="$MT5_DIR/MQL5/Logs"
if [ -d "$LOG_DIR" ]; then
    echo "Looking for logs with date: $TODAY"
    ls -la "$LOG_DIR/" 2>/dev/null
    echo ""
    for f in "$LOG_DIR/"*${TODAY}*; do
        if [ -f "$f" ]; then
            echo "--- $(basename "$f") ---"
            cat "$f" 2>/dev/null
            echo ""
        fi
    done
    # Also check latest log file
    LATEST_LOG=$(ls -t "$LOG_DIR/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "--- Latest log: $(basename "$LATEST_LOG") ---"
        grep -i -E "order|trade|buy|sell|deal|open|close|profit" "$LATEST_LOG" 2>/dev/null | tail -50
    fi
else
    echo "No MQL5/Logs directory"
fi
echo ""

# Check MT5 terminal logs
echo "=== [4] MT5 Terminal Logs (today) ==="
TERM_LOG_DIR="$MT5_DIR/Logs"
if [ -d "$TERM_LOG_DIR" ]; then
    ls -la "$TERM_LOG_DIR/" 2>/dev/null
    echo ""
    for f in "$TERM_LOG_DIR/"*${TODAY}*; do
        if [ -f "$f" ]; then
            echo "--- $(basename "$f") ---"
            grep -i -E "order|trade|buy|sell|deal|open|close|profit" "$f" 2>/dev/null | tail -50
            echo ""
        fi
    done
    LATEST_TERM=$(ls -t "$TERM_LOG_DIR/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_TERM" ]; then
        echo "--- Latest terminal log: $(basename "$LATEST_TERM") ---"
        grep -i -E "order|trade|buy|sell|deal|open|close|profit" "$LATEST_TERM" 2>/dev/null | tail -50
    fi
else
    echo "No terminal Logs directory"
fi
echo ""

# Check PropFirmBot specific files
echo "=== [5] PropFirmBot Data Files ==="
if [ -d "$MQL5_FILES" ]; then
    echo "Files in PropFirmBot directory:"
    ls -la "$MQL5_FILES/" 2>/dev/null
    echo ""
    # Show account state
    for f in "$MQL5_FILES/"*.json; do
        if [ -f "$f" ]; then
            echo "--- $(basename "$f") ---"
            cat "$f" 2>/dev/null | python3 -m json.tool 2>/dev/null || cat "$f" 2>/dev/null
            echo ""
        fi
    done
else
    echo "No PropFirmBot data directory"
fi

# Check MT5 status daemon
echo "=== [6] MT5 Status ==="
if [ -f "/var/bots/mt5_status.json" ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
else
    echo "No status file"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
