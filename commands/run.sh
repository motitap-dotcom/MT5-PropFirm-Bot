#!/bin/bash
# Compile EA with correct MetaEditor path
echo "=== COMPILE EA $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
METAEDITOR="${MT5_BASE}/MetaEditor64.exe"

export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "--- Before compile ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "--- Compiling ---"
wine64 "$METAEDITOR" /compile:"${EA_DIR}/PropFirmBot.mq5" /log 2>&1
sleep 10

echo ""
echo "--- After compile ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "--- Compile log ---"
cat "$EA_DIR/PropFirmBot.log" 2>/dev/null || echo "No compile log at EA dir"
# Also check MT5 base dir
cat "${MT5_BASE}/MQL5/Experts/PropFirmBot/PropFirmBot.log" 2>/dev/null
# Also check if log is at metaeditor level
find "$MT5_BASE" -name "*.log" -newer "$EA_DIR/PropFirmBot.mq5" -mmin -2 2>/dev/null | while read f; do
    echo "=== Log: $f ==="
    cat "$f" 2>/dev/null
done

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
