#!/bin/bash
# Deploy updated EA + recompile + restart MT5 + verify
# Triggered: 2026-03-06 v2
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "=== TIME: $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_BASE/MQL5/Experts/PropFirmBot"

# Step 1: Pull latest code
echo ""
echo "=== Step 1: Pull latest code ==="
cd /root/MT5-PropFirm-Bot
git fetch origin claude/debug-bot-trading-HN2Tc 2>&1
git checkout claude/debug-bot-trading-HN2Tc 2>&1
git pull origin claude/debug-bot-trading-HN2Tc 2>&1

# Step 2: Copy EA files
echo ""
echo "=== Step 2: Copy EA files ==="
cp -v /root/MT5-PropFirm-Bot/EA/*.mq5 "$EA_DIR/" 2>&1
cp -v /root/MT5-PropFirm-Bot/EA/*.mqh "$EA_DIR/" 2>&1

# Step 3: Compile
echo ""
echo "=== Step 3: Compile EA ==="
cd "$MT5_BASE"
timeout 30 wine metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>&1 || true
sleep 5

echo ""
echo "=== Compile result ==="
ls -la "$EA_DIR/PropFirmBot.ex5" 2>&1
cat "$EA_DIR/PropFirmBot.log" 2>/dev/null | tail -20

# Step 4: Restart MT5
echo ""
echo "=== Step 4: Restart MT5 ==="
pkill -f terminal64.exe 2>/dev/null || true
sleep 5
echo "MT5 killed, starting fresh..."
cd "$MT5_BASE"
nohup wine terminal64.exe /autotrading > /dev/null 2>&1 &
sleep 15

echo ""
echo "=== MT5 Process ==="
ps aux | grep terminal64 | grep -v grep

# Step 5: Check EA log
echo ""
echo "=== Step 5: New EA log ==="
LOG_FILE="$MT5_BASE/MQL5/Logs/$(date -u +%Y%m%d).log"
tail -30 "$LOG_FILE" 2>/dev/null || echo "No log yet"

echo ""
echo "DONE $(date)"
