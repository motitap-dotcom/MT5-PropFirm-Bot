#!/bin/bash
# Check if the new EA loaded with AUTOFIX code
echo "=== CHECK NEW EA $(date -u) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] MT5 running:"
pgrep -f terminal64 | wc -l
echo ""

echo "[2] EA .ex5 file:"
ls -la "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>&1
echo ".mq5 file:"
ls -la "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.mq5" 2>&1
echo ""

echo "[3] Full EA log from latest session:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "AUTOFIX\|auto.fix\|OnInit\|DLL\|import\|INIT\|ALL SYSTEMS\|enabled\|disabled\|error\|failed to load\|compilation"
echo ""

echo "[4] Last 20 lines:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -20
echo ""

echo "[5] Terminal log (errors):"
TLOG=$(ls -t "$MT5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$TLOG" ]; then
    cat "$TLOG" 2>/dev/null | tr -d '\0' | grep -i "error\|fail\|compil\|cannot\|DLL\|AUTOFIX" | tail -10
fi

echo "=== DONE $(date -u) ==="
