#!/bin/bash
# Check if MT5 restarted with new params
echo "=== CHECK NEW PARAMS $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Is MT5 running?
echo "=== MT5 PROCESS ==="
pgrep -fa terminal64

# 2. Check EA logs from TODAY (only recent entries)
echo ""
echo "=== EA LOGS (last 40 lines) ==="
EALOGDIR="$MT5/MQL5/Logs"
LATEST=$(ls -t "$EALOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo "Log file: $LATEST"
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -40
fi

# 3. Check MT5 main log
echo ""
echo "=== MT5 MAIN LOG (last 30 lines) ==="
LOGDIR="$MT5/Logs"
LATEST=$(ls -t "$LOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo "Log file: $LATEST"
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -30
fi

# 4. Check what chart files exist now
echo ""
echo "=== CURRENT CHART FILES ==="
ls -la "$MT5/MQL5/Profiles/Charts/Default/" 2>/dev/null

echo ""
echo "=== DONE ==="
