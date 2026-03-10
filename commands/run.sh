#!/bin/bash
# Quick verify: was deploy applied?
echo "=== QUICK VERIFY $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"

# 1. Pull latest and deploy
echo "--- Pull & Deploy ---"
cd /root/MT5-PropFirm-Bot
git fetch origin 2>&1 | tail -3
git checkout claude/bot-status-command-CfoXO 2>&1 | tail -2
git pull origin claude/bot-status-command-CfoXO 2>&1 | tail -3
cp -f /root/MT5-PropFirm-Bot/EA/*.mq5 "$EA_DIR/" 2>&1
cp -f /root/MT5-PropFirm-Bot/EA/*.mqh "$EA_DIR/" 2>&1
echo "Files copied."

# 2. Check key changes
echo ""
echo "--- Verify Changes ---"
echo "Strategy:"
grep "InpStrategy.*=" "$EA_DIR/PropFirmBot.mq5" | head -1
echo "XAU Spread:"
grep "InpMaxSpreadXAU" "$EA_DIR/PropFirmBot.mq5" | head -1
echo "AutoBlock:"
grep "InpAutoBlockSymbol" "$EA_DIR/PropFirmBot.mq5" | head -1

# 3. Compile
echo ""
echo "--- Compile ---"
export DISPLAY=:99
pkill -f terminal64.exe 2>/dev/null
sleep 3
cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak" 2>/dev/null
WINEPREFIX=/root/.wine wine "${MT5_BASE}/metaeditor64.exe" /compile:"${EA_DIR}/PropFirmBot.mq5" /log 2>&1 | tail -5
sleep 6
echo "Compiled:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>&1

# 4. Start MT5
echo ""
echo "--- Start MT5 ---"
WINEPREFIX=/root/.wine wine "${MT5_BASE}/terminal64.exe" /portable &
sleep 12
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5: RUNNING PID=$MT5_PID"
    echo -900 > /proc/$MT5_PID/oom_score_adj 2>/dev/null
else
    echo "MT5: FAILED!"
fi

# 5. Wait for EA and show logs
sleep 15
echo ""
echo "--- EA Log ---"
LATEST=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    tail -25 "$LATEST" 2>&1
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
