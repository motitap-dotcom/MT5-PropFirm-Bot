#!/bin/bash
echo "=== Verify Settings - $(date) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- EA log (last 25 lines) ---"
LATEST=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
[ -n "$LATEST" ] && cat "$LATEST" | tr -d '\0' | tail -25

echo ""
echo "--- Status JSON ---"
cat "$MT5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null | tr -d '\0'

echo ""
echo "--- AccountState.dat ---"
ls -la "$MT5/MQL5/Files/PropFirmBot/PropFirmBot_AccountState.dat" 2>/dev/null || echo "No state file"
echo "=== Done ==="
