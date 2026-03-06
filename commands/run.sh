#!/bin/bash
# Check chart expertmode and fix Allow Live Trading
echo "=== CHART FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] Find all chart files with expert settings:"
find "$MT5" -name "*.chr" 2>/dev/null | while read f; do
    HAS_EXPERT=$(cat "$f" 2>/dev/null | tr -d '\0' | grep -c "expert")
    if [ "$HAS_EXPERT" -gt 0 ]; then
        echo "  --- $f ---"
        cat "$f" 2>/dev/null | tr -d '\0' | grep -i "expert" | head -10
    fi
done

echo ""
echo "[2] Find the active chart profile:"
cat "$MT5/config/common.ini" 2>/dev/null | tr -d '\0' | grep -i "profile\|chart\|expert" | head -10
find "$MT5/MQL5/Profiles" -name "*.chr" 2>/dev/null | head -10

echo ""
echo "[3] Default profile charts:"
for f in "$MT5/MQL5/Profiles/Charts/Default/"*.chr "$MT5/profiles/charts/default/"*.chr; do
    if [ -f "$f" ]; then
        echo "  --- $(basename "$f") ---"
        cat "$f" 2>/dev/null | tr -d '\0' | grep -i "expert\|symbol\|period" | head -15
    fi
done

echo ""
echo "[4] All profiles:"
find "$MT5/MQL5/Profiles" -type d 2>/dev/null | head -10
find "$MT5/profiles" -type d 2>/dev/null | head -10

echo ""
echo "[5] Terminal log for chart/profile info:"
TERMLOG=$(ls -t "$MT5/Logs/"*.log 2>/dev/null | head -1)
echo "  Terminal log: $TERMLOG"
cat "$TERMLOG" 2>/dev/null | tr -d '\0' | grep -i "chart\|profile\|expert\|autotrading\|algo" | tail -10

echo "=== DONE $(date -u) ==="
