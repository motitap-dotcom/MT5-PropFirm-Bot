#!/bin/bash
# Verify compile + check new settings - 2026-03-04
echo "=== Verify Compile - $(date) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA="$MT5/MQL5/Experts/PropFirmBot"

echo "--- .ex5 file ---"
ls -la "$EA/PropFirmBot.ex5" 2>/dev/null
md5sum "$EA/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "--- MT5 running? ---"
ps aux | grep "[t]erminal64" | head -2

echo ""
echo "--- EA log (last 20 lines) ---"
LATEST=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
[ -n "$LATEST" ] && cat "$LATEST" | tr -d '\0' | tail -20

echo ""
echo "--- Status ---"
cat "$MT5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null | tr -d '\0'

echo "=== Done ==="
