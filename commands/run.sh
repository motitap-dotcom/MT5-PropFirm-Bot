#!/bin/bash
# Quick verify after compile - 2026-03-04
echo "=== Quick Verify - $(date) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
echo "--- .ex5 files ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/"*.ex5* 2>/dev/null
echo "--- MT5 running? ---"
ps aux | grep "[t]erminal64" | head -3
echo "--- EA log (last 10 lines) ---"
LATEST=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
[ -n "$LATEST" ] && cat "$LATEST" | tr -d '\0' | tail -10
echo "=== Done ==="
