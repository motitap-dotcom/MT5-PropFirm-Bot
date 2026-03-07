#!/bin/bash
# Check if bot traded on Friday March 6 2026
echo "=== TRADE HISTORY CHECK $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] EA Logs - all log files:"
ls -la "$MT5/MQL5/Logs/"*.log 2>/dev/null

echo ""
echo "[2] Today's log - any successful trades:"
for LOG in "$MT5/MQL5/Logs/"*.log; do
    [ -f "$LOG" ] || continue
    echo "--- $(basename "$LOG") ---"
    cat "$LOG" 2>/dev/null | tr -d '\0' | grep -i "filled\|done\|position opened\|order placed\|successfully\|deal\|BUY.*ok\|SELL.*ok" | tail -10
done

echo ""
echo "[3] Today's log - ALL trade attempts:"
for LOG in "$MT5/MQL5/Logs/"*.log; do
    [ -f "$LOG" ] || continue
    cat "$LOG" 2>/dev/null | tr -d '\0' | grep -i "OrderSend\|TradeMgr" | tail -20
done

echo ""
echo "[4] Terminal logs - trade history:"
for LOG in "$MT5/Logs/"*.log; do
    [ -f "$LOG" ] || continue
    echo "--- $(basename "$LOG") ---"
    cat "$LOG" 2>/dev/null | tr -d '\0' | grep -i "order\|deal\|trade\|position\|buy\|sell" | grep -v "grep" | tail -10
done

echo ""
echo "[5] Trade journal file:"
find "$MT5/MQL5/Files" -name "*journal*" -o -name "*trade*" -o -name "*history*" 2>/dev/null | while read f; do
    echo "--- $f ---"
    cat "$f" 2>/dev/null | tr -d '\0' | tail -10
done

echo ""
echo "[6] Account status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null

echo ""
echo "[7] HEARTBEAT entries (was EA active?):"
for LOG in "$MT5/MQL5/Logs/"*.log; do
    [ -f "$LOG" ] || continue
    cat "$LOG" 2>/dev/null | tr -d '\0' | grep "HEARTBEAT" | head -3
    echo "..."
    cat "$LOG" 2>/dev/null | tr -d '\0' | grep "HEARTBEAT" | tail -3
done

echo "=== DONE $(date -u) ==="
