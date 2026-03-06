#!/bin/bash
# Check if EA was recompiled and reloaded after deploy
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "=== TIME: $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

# Pull latest code
cd /root/MT5-PropFirm-Bot
git pull origin claude/debug-bot-trading-HN2Tc 2>&1

echo ""
echo "=== Recompile EA ==="
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
MQL_DIR="$EA_DIR/MQL5/Experts/PropFirmBot"

# Copy updated EA files
cp -v /root/MT5-PropFirm-Bot/EA/*.mq5 "$MQL_DIR/" 2>&1
cp -v /root/MT5-PropFirm-Bot/EA/*.mqh "$MQL_DIR/" 2>&1

echo ""
echo "=== Compile ==="
cd "$EA_DIR"
wine metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>&1
sleep 5

echo ""
echo "=== Compile log ==="
cat "$MQL_DIR/PropFirmBot.log" 2>/dev/null || echo "No compile log found"

echo ""
echo "=== Check .ex5 file ==="
ls -la "$MQL_DIR/PropFirmBot.ex5" 2>&1

echo ""
echo "=== Restart MT5 to load new EA ==="
# Kill MT5
pkill -f terminal64.exe 2>/dev/null
sleep 3

# Start MT5
cd "$EA_DIR"
wine terminal64.exe /autotrading &
sleep 10

echo ""
echo "=== MT5 Process check ==="
ps aux | grep terminal64 | grep -v grep

echo ""
echo "=== Latest EA log (after restart) ==="
sleep 5
LOG_FILE="$EA_DIR/MQL5/Logs/$(date -u +%Y%m%d).log"
tail -20 "$LOG_FILE" 2>/dev/null || echo "No log yet"

echo ""
echo "DONE $(date)"
