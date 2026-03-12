#!/bin/bash
# Fresh status check - verify trades are open and bot is active
echo "=== LIVE STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. MT5 process
echo "--- MT5 Process ---"
pgrep -fa "terminal64" 2>/dev/null || echo "MT5 NOT RUNNING!"

# 2. Fresh status.json
echo ""
echo "--- status.json ---"
STATUS_FILE="${MT5_BASE}/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
    echo ""
    echo "File timestamp: $(stat -c '%Y %y' "$STATUS_FILE")"
else
    echo "NO status.json FOUND"
fi

# 3. Latest EA log - last 40 lines (fresh activity)
echo ""
echo "--- EA Log (last 40 lines) ---"
EA_LATEST=$(ls -t "$MT5_BASE/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    TMPLOG="/tmp/ea_live.txt"
    iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
      sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"
    echo "Log: $EA_LATEST ($(wc -l < "$TMPLOG") lines)"
    tail -40 "$TMPLOG"
fi

# 4. Check open positions via trade journal
echo ""
echo "--- Trade Journal (today) ---"
JOURNAL=$(ls -t "${MT5_BASE}/MQL5/Files/PropFirmBot/"*Journal*2026031* 2>/dev/null | head -1)
if [ -n "$JOURNAL" ]; then
    echo "File: $JOURNAL"
    cat "$JOURNAL" 2>/dev/null
else
    echo "No journal file found for today"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
