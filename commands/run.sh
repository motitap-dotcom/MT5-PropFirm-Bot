#!/bin/bash
# Compile EA - try exact deploy-ea.yml command format
echo "=== COMPILE EA $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "Before:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

# Try exact format from deploy-ea.yml
cd "$EA_DIR"
echo "Compiling with wine (not wine64)..."
WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>&1 || true
sleep 10

echo ""
echo "After:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

# Check if file was updated
echo ""
echo "File modification times:"
stat -c "%n: %y" "$EA_DIR/PropFirmBot.mq5" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

# Check for any compile logs
echo ""
echo "Compile logs:"
find "$EA_DIR" "${MT5_BASE}" -maxdepth 2 -name "*.log" -newer "$EA_DIR/PropFirmBot.mq5" 2>/dev/null | while read f; do
    echo "=== $f ==="
    tail -30 "$f"
done

# Try MetaEditor64.exe (uppercase) with wine if first attempt didn't work
EX5_TIME_BEFORE=$(stat -c "%Y" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "0")
EX5_TIME_AFTER=$(stat -c "%Y" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "0")
if [ "$EX5_TIME_BEFORE" = "$EX5_TIME_AFTER" ]; then
    echo ""
    echo "First attempt failed. Trying MetaEditor64.exe (uppercase)..."
    WINEPREFIX=/root/.wine wine "${MT5_BASE}/MetaEditor64.exe" /compile:PropFirmBot.mq5 /log 2>&1 || true
    sleep 10
    echo "After second attempt:"
    ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
