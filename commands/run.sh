#!/bin/bash
# Quick verify new code is running with hardening
echo "=== VERIFY HARDENING $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Check EA log for NEW init messages (after restart at 12:32)
echo "--- EA Log entries after 12:32 UTC ---"
EA_LATEST=$(ls -t "$MT5_BASE/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    TMPLOG="/tmp/ea_harden.txt"
    iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
      sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"
    echo "Log: $EA_LATEST ($(wc -l < "$TMPLOG") lines)"

    echo ""
    echo "All INIT messages:"
    grep "\[INIT\]" "$TMPLOG" 2>/dev/null

    echo ""
    echo "SignalEngine WARNING (M15 forcing):"
    grep -i "WARNING.*Entry TF\|forcing.*M15\|WARNING.*InpEntryTF" "$TMPLOG" 2>/dev/null || echo "(none found)"

    echo ""
    echo "TimeGMT offset check:"
    grep "TimeGMT offset" "$TMPLOG" 2>/dev/null || echo "(none found)"

    echo ""
    echo "Entry TF and Sessions in init:"
    grep "Entry TF:\|Sessions:" "$TMPLOG" 2>/dev/null || echo "(none found)"

    echo ""
    echo "All NEWBAR entries:"
    grep "NEWBAR" "$TMPLOG" 2>/dev/null | tail -10

    echo ""
    echo "Last 30 lines:"
    tail -30 "$TMPLOG"
fi

# 2. Current status
echo ""
echo "--- status.json ---"
STATUS_FILE="${MT5_BASE}/MQL5/Files/PropFirmBot/status.json"
cat "$STATUS_FILE" 2>/dev/null || echo "NOT FOUND"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
