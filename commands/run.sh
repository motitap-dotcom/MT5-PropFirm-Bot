#!/bin/bash
# Just check current state - don't change anything
echo "=== STATE CHECK $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] MT5 running:"
pgrep -fa terminal64 | head -3
echo ""

echo "[2] AutoTrading history (all messages):"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading"
echo ""

echo "[3] Last 15 lines of EA log:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -15
echo ""

echo "[4] Did bot trade today?"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null

echo "=== DONE $(date -u) ==="
