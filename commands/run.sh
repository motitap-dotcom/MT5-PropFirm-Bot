#!/bin/bash
# Fixed diagnostic with proper UTF-16 handling
echo "=== FIXED DIAGNOSTIC $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"

EA_LATEST=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
echo "Log: $EA_LATEST"
echo "Size: $(wc -c < "$EA_LATEST") bytes"

# Convert UTF-16 to UTF-8 for proper reading
TMPLOG="/tmp/ea_log_utf8.txt"
iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
  sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"

echo "Converted lines: $(wc -l < "$TMPLOG")"

# 1. ALL NEWBAR entries - check if M15 or H1
echo ""
echo "--- ALL NEWBAR entries (check M15 vs H1) ---"
grep "NEWBAR" "$TMPLOG" | head -40

# 2. INIT entries
echo ""
echo "--- INIT entries ---"
grep -i "INIT\|Init:\|ALL SYSTEMS\|Risk\|Symbols\|Phase\|Balance\|Entry TF\|Initialized\|PropFirmBot v" "$TMPLOG" | head -20

# 3. ALL signal scan results
echo ""
echo "--- SIGNAL SCAN results ---"
grep -i "SCAN\|SMC\|EMA\|signal\|bias\|OB\|FVG\|CrossUp\|MomBuy\|no H4" "$TMPLOG" | head -40

# 4. Blocked reasons
echo ""
echo "--- BLOCKED reasons ---"
grep -i "BLOCKED\|Outside\|Spread\|news.*block" "$TMPLOG" | sort | uniq -c | sort -rn

# 5. Any trades?
echo ""
echo "--- TRADE entries ---"
grep -i "TRADE\|BUY\|SELL\|CLOSED\|ticket\|order" "$TMPLOG" | head -20

# 6. Previous day log - same analysis
PREV_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -2 | tail -1)
if [ -n "$PREV_LOG" ] && [ "$PREV_LOG" != "$EA_LATEST" ]; then
    TMPLOG2="/tmp/ea_log_prev_utf8.txt"
    iconv -f UTF-16LE -t UTF-8 "$PREV_LOG" 2>/dev/null > "$TMPLOG2" || \
      sed 's/\x00//g' "$PREV_LOG" > "$TMPLOG2"

    echo ""
    echo "--- PREVIOUS DAY: $(basename "$PREV_LOG") ---"
    echo "Lines: $(wc -l < "$TMPLOG2")"
    echo ""
    echo "Previous NEWBARs (sample):"
    grep "NEWBAR" "$TMPLOG2" | head -5
    grep "NEWBAR" "$TMPLOG2" | tail -5
    echo ""
    echo "Previous SCAN/SIGNAL:"
    grep -i "SCAN\|signal\|BUY\|SELL\|TRADE\|CLOSED" "$TMPLOG2" | head -20
    echo ""
    echo "Previous BLOCKED summary:"
    grep -i "BLOCKED" "$TMPLOG2" | sort | uniq -c | sort -rn
fi

# 7. Check March 9 log (largest file - 439KB, might have had trades)
MAR9_LOG="$EA_LOG_DIR/20260309.log"
if [ -f "$MAR9_LOG" ]; then
    TMPLOG9="/tmp/ea_log_mar9_utf8.txt"
    iconv -f UTF-16LE -t UTF-8 "$MAR9_LOG" 2>/dev/null > "$TMPLOG9" || \
      sed 's/\x00//g' "$MAR9_LOG" > "$TMPLOG9"

    echo ""
    echo "--- MARCH 9 LOG (largest - had trades?) ---"
    echo "Lines: $(wc -l < "$TMPLOG9")"
    echo "NEWBARs: $(grep -c "NEWBAR" "$TMPLOG9")"
    echo "NEWBAR sample:"
    grep "NEWBAR" "$TMPLOG9" | head -5
    echo ""
    echo "March 9 TRADES:"
    grep -i "\[TRADE\]\|CLOSED\|ticket\|order\|BUY signal\|SELL signal\|GOT SIGNAL" "$TMPLOG9" | head -20
    echo ""
    echo "March 9 SIGNALS:"
    grep -i "SCAN.*SIGNAL\|SCAN.*BUY\|SCAN.*SELL\|SMC.*signal\|EMA.*signal" "$TMPLOG9" | head -20
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
