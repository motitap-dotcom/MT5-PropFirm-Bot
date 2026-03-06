#!/bin/bash
# Check if bot is executing trades
echo "=== TRADE CHECK $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)

echo "[1] AutoTrading state:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] Trade attempts & results (OrderSend, filled, deal):"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "OrderSend\|filled\|deal\|executed\|opened\|position\|trade done\|order.*done" | tail -20

echo "[3] All signal+trade entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "SIGNAL\|TradeMgr\|SELL\|BUY\|HEARTBEAT" | tail -20

echo "[4] Full last 30 lines:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -30

echo "[5] Status JSON:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null

echo "[6] MT5 process alive:"
pgrep -a "start.exe\|terminal64\|wineserver" 2>/dev/null | head -3 || echo "NOT RUNNING"

echo "=== DONE $(date -u) ==="
