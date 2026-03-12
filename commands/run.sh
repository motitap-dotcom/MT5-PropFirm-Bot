#!/bin/bash
# Verify EA compilation and check for fix markers in logs
echo "=== VERIFY FIXES $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

# 1. Check if .ex5 exists and its timestamp
echo "--- .ex5 status ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "NO .ex5 FILE EXISTS"
ls -la "$EA_DIR/PropFirmBot.mq5" 2>/dev/null

# 2. Check MT5 process
echo ""
echo "--- MT5 process ---"
pgrep -fa "terminal64" 2>/dev/null || echo "MT5 NOT RUNNING"

# 3. Check today's EA log for fix markers
echo ""
echo "--- Today's EA log (last 60 lines) ---"
EA_LATEST=$(ls -t "$MT5_BASE/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    TMPLOG="/tmp/ea_verify.txt"
    iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
      sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"
    echo "Log: $EA_LATEST ($(wc -l < "$TMPLOG") lines)"
    echo ""
    echo "--- Last 60 lines ---"
    tail -60 "$TMPLOG"

    echo ""
    echo "--- Fix markers search ---"
    echo "NEWBAR with TF= (new code):"
    grep -c "TF=PERIOD" "$TMPLOG" 2>/dev/null || echo "0 matches"
    grep "TF=PERIOD" "$TMPLOG" 2>/dev/null | tail -5

    echo ""
    echo "Session check entries:"
    grep -c "Session check" "$TMPLOG" 2>/dev/null || echo "0 matches"
    grep "Session check" "$TMPLOG" 2>/dev/null | tail -5

    echo ""
    echo "SCAN entries:"
    grep -c "\[SCAN\]" "$TMPLOG" 2>/dev/null || echo "0 matches"
    grep "\[SCAN\]" "$TMPLOG" 2>/dev/null | tail -10

    echo ""
    echo "NEWBAR entries with :15 :30 :45 (M15 detection):"
    grep "NEWBAR" "$TMPLOG" 2>/dev/null | grep -E ":(15|30|45)" | tail -5

    echo ""
    echo "All NEWBAR entries:"
    grep "NEWBAR" "$TMPLOG" 2>/dev/null | tail -10

    echo ""
    echo "Spread blocked entries:"
    grep -c "Spread too wide" "$TMPLOG" 2>/dev/null || echo "0 matches"

    echo ""
    echo "Any errors or warnings:"
    grep -iE "(error|warning|fail|cannot)" "$TMPLOG" 2>/dev/null | tail -10
fi

# 4. Check terminal log for compilation messages
echo ""
echo "--- Terminal log (compilation info) ---"
TERM_LATEST=$(ls -t "$MT5_BASE/logs"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LATEST" ]; then
    TMPTERM="/tmp/term_verify.txt"
    iconv -f UTF-16LE -t UTF-8 "$TERM_LATEST" 2>/dev/null > "$TMPTERM" || \
      sed 's/\x00//g' "$TERM_LATEST" > "$TMPTERM"
    echo "Log: $TERM_LATEST"
    grep -iE "(compil|expert|propfirm|error|warn)" "$TMPTERM" 2>/dev/null | tail -20
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
