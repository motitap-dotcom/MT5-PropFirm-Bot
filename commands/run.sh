#!/bin/bash
# Quick check: is bot trading after 14:45 bar?
echo "=== TRADE CHECK $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)

echo "[1] AutoTrading:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] NEW entries (after 14:39):"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -E "^..\t.\t14:(39|4[0-9]|5)" | tail -20

echo "[3] All last 15 lines:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -15

echo "[4] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -15

echo "=== DONE $(date -u) ==="
