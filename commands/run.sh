#!/bin/bash
# Check if new EA with AUTOFIX loaded and AutoTrading is enabled
echo "=== VERIFY AUTOFIX $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] EA log (grep AUTOFIX, AutoTrading, INIT, enabled):"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "AUTOFIX\|AutoTrading is\|ALL SYSTEMS\|INIT.*AutoTr\|automated trading\|DLL" | tail -15
echo ""

echo "[2] Last 20 lines:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -20
echo ""

echo "[3] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -15

echo "=== DONE $(date -u) ==="
