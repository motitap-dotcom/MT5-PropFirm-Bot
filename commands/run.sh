#!/bin/bash
# Check if MT5 is running and EA loaded after fix
echo "=== STATUS CHECK $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Is MT5 running?
echo "[1] MT5 Process:"
pgrep -a terminal64 2>/dev/null || echo "NOT RUNNING"

# Check EA file
echo "[2] EA file:"
ls -la "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

# Check if the EA source has DLL import (should NOT have it)
echo "[3] DLL import check in .mq5:"
grep -c "user32.dll" "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.mq5" 2>/dev/null && echo "BAD: Still has DLL import!" || echo "OK: No DLL import"

# EA log
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "[4] EA Log (last entries):"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "INIT\|ALL SYSTEMS\|automated\|DLL\|error\|AUTOFIX" | tail -8
echo ""
echo "[5] Last 10 lines:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10

# Status JSON
echo "[6] Bot Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -15

# Check xdotool windows
echo "[7] Windows:"
xdotool search --name "" 2>/dev/null | while read w; do echo "$w: $(xdotool getwindowname "$w" 2>/dev/null)"; done | head -10

echo "=== DONE $(date -u) ==="
