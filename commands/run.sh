#!/bin/bash
# Quick status check - is MT5 running and what version?
echo "=== Quick Status Check $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
echo ""
echo "MT5 Process:"
pgrep -a terminal64 2>/dev/null || echo "MT5 NOT running"
echo ""
echo "EA .ex5 file:"
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null
echo ""
echo "Latest EA log (last 10 lines):"
LATEST=$(ls -t "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/"*.log 2>/dev/null | head -1)
[ -n "$LATEST" ] && tail -10 "$LATEST" 2>/dev/null || echo "No logs"
echo ""
echo "Status JSON:"
cat "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null || echo "No status file"
echo ""
echo "=== DONE ==="
