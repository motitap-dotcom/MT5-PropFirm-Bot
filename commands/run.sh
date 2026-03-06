#!/bin/bash
# Quick status check - is AutoTrading still enabled and bot trading?
echo "=== STATUS $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)

echo "[1] AutoTrading:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] Recent EA activity:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -15

echo "[3] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null

echo "=== DONE $(date -u) ==="
