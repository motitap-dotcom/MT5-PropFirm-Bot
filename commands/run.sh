#!/bin/bash
# Quick verification - did the deploy work?
echo "=== DEPLOY VERIFICATION - $(date) ==="

EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

echo ""
echo "=== REPO STATUS ==="
cd "$REPO" 2>/dev/null
echo "Branch: $(git branch --show-current 2>/dev/null)"
echo "Last commit: $(git log --oneline -1 2>/dev/null)"

echo ""
echo "=== EA FILE DATES ==="
ls -la "$EA_DIR/PropFirmBot.mq5" "$EA_DIR/SignalEngine.mqh" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "=== KEY PARAMS IN SOURCE ==="
grep "InpMaxSpreadMajor\|InpMinRR\|InpMaxPositions\|InpTrailingActivation\|InpBEActivation\|InpTradeXAUUSD" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null

echo ""
echo "=== MT5 RUNNING? ==="
pgrep -a terminal64 2>/dev/null || echo "terminal64 NOT running"
pgrep -a wine 2>/dev/null | head -3

echo ""
echo "=== LATEST EA LOG (last 5 lines) ==="
LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    echo "File: $(basename "$LATEST_LOG")"
    tail -5 "$LATEST_LOG"
fi

echo ""
echo "=== TRY MANUAL DEPLOY ==="
# Pull latest code
cd "$REPO"
git fetch --all 2>/dev/null
git checkout claude/bot-server-connection-qmvC0 2>/dev/null || git checkout -b claude/bot-server-connection-qmvC0 origin/claude/bot-server-connection-qmvC0 2>/dev/null
git pull origin claude/bot-server-connection-qmvC0 2>/dev/null
echo "Repo updated: $(git log --oneline -1)"

# Copy files
cp "$REPO/EA/"*.mq5 "$EA_DIR/" 2>/dev/null && echo "MQ5 files copied"
cp "$REPO/EA/"*.mqh "$EA_DIR/" 2>/dev/null && echo "MQH files copied"
cp "$REPO/configs/"*.json "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/" 2>/dev/null && echo "Config files copied"

# Compile
echo ""
echo "=== COMPILING ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine
wine64 "/root/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe" /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log:"compile.log" /inc:"/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5" 2>/dev/null
sleep 5
echo "Compile result:"
strings "/root/.wine/drive_c/Program Files/MetaTrader 5/compile.log" 2>/dev/null | grep -i "result\|error\|warning" | tail -3
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

# Restart MT5
echo ""
echo "=== RESTARTING MT5 ==="
pkill -f terminal64 2>/dev/null
sleep 3
wine64 "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable &
sleep 8
pgrep -a terminal64 2>/dev/null && echo "MT5 STARTED!" || echo "MT5 not detected (may be starting...)"
pgrep -a wine 2>/dev/null | head -3

echo ""
echo "=== DONE - $(date) ==="
