#!/bin/bash
# Quick status check - verify EA params and Telegram
echo "=== QUICK STATUS CHECK - $(date) ==="
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- MT5 Processes ---"
pgrep -a -f "terminal64\|wine.*exe\|metatrader" 2>/dev/null | head -10
ps aux | grep -i "[w]ine\|[m]t5\|[t]erminal" | head -10
echo ""

echo "--- Network Connections ---"
ss -tnp | grep -i "wine\|terminal\|main\|wineserver" | head -10
echo ""

echo "--- EA Log (last 80 lines via strings) ---"
MT5_LOG_DIR="${MT5_BASE}/MQL5/Logs"
LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    echo "Log: $LATEST_LOG (size: $(stat -c%s "$LATEST_LOG") bytes)"
    strings "$LATEST_LOG" | tail -80
fi
echo ""

echo "--- Status JSON ---"
cat "${MT5_BASE}/MQL5/Files/PropFirmBot/status.json" 2>/dev/null
echo ""

echo "--- Check if state file was recreated ---"
find /root/.wine -name "PropFirmBot_AccountState.dat" 2>/dev/null
echo ""

echo "--- common.ini WebRequest section ---"
grep -A5 "\[Experts\]" "${MT5_BASE}/config/common.ini" 2>/dev/null
echo ""

echo "=== DONE ==="
