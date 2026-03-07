#!/bin/bash
# Find where MT5 stores AutoTrading setting + try xdotool approach
echo "=== FIND AT SETTING $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] All .ini files with Expert/Auto/Trading settings:"
find "$MT5" -name "*.ini" 2>/dev/null | while read f; do
    MATCH=$(cat "$f" 2>/dev/null | tr -d '\0' | grep -ai "expert\|auto.*trad\|algo")
    if [ -n "$MATCH" ]; then
        echo "  --- $f ---"
        echo "$MATCH"
    fi
done

echo ""
echo "[2] common.ini full content:"
cat "$MT5/config/common.ini" 2>/dev/null | tr -d '\0'

echo ""
echo "[3] Try xdotool approach:"
# Find main chart window
CHART_WIN=$(xdotool search --name "EURUSD" 2>/dev/null | head -1)
echo "  Chart window: $CHART_WIN"
if [ -n "$CHART_WIN" ]; then
    TITLE=$(xdotool getwindowname "$CHART_WIN" 2>/dev/null)
    echo "  Title: $TITLE"
    xdotool windowfocus "$CHART_WIN" 2>/dev/null
    sleep 1
    xdotool key ctrl+e 2>/dev/null
    echo "  xdotool Ctrl+E sent to chart window"
    sleep 5
fi

echo ""
echo "[4] AT state after xdotool:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -a "automated trading" | tail -3

echo ""
echo "[5] All MT5 windows:"
xdotool search --name "" 2>/dev/null | while read w; do
    NAME=$(xdotool getwindowname "$w" 2>/dev/null)
    [ -n "$NAME" ] && [ "$NAME" != "Default IME" ] && echo "  $w: $NAME"
done

echo "=== DONE $(date -u) ==="
