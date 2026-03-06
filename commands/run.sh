#!/bin/bash
# Quick check: is bot now trading with AutoTrading ON?
echo "=== STATUS CHECK $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)

echo "[1] AutoTrading state:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[2] Last 20 EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -20

echo "[3] Any successful trades?"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "filled\|done\|position opened\|order placed\|successfully" | tail -5

echo "[4] Any errors?"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "error\|failed\|10027" | tail -5

echo "[5] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -15

echo "=== DONE $(date -u) ==="
