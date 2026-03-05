#!/bin/bash
# Fast deploy - no long waits
echo "=== FAST DEPLOY $(date) ==="

REPO="/root/MT5-PropFirm-Bot"
EA="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
CFG="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"

# Pull latest
cd "$REPO"
git fetch origin claude/bot-server-connection-qmvC0 2>&1 | tail -3
git checkout claude/bot-server-connection-qmvC0 2>/dev/null
git reset --hard origin/claude/bot-server-connection-qmvC0 2>&1
echo "Commit: $(git log --oneline -1)"

# Copy EA files
cp "$REPO/EA/"*.mq5 "$EA/" && echo "OK: MQ5 copied"
cp "$REPO/EA/"*.mqh "$EA/" && echo "OK: MQH copied"
cp "$REPO/configs/"*.json "$CFG/" && echo "OK: Configs copied"

# Verify params
echo ""
echo "=== PARAMS CHECK ==="
grep -E "InpMaxSpreadMajor|InpMinRR|InpTrailingActivation|InpTradeXAUUSD" "$EA/PropFirmBot.mq5" | head -6

# Compile
echo ""
echo "=== COMPILE ==="
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
wine64 metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log:"compile.log" /inc:"MQL5" 2>/dev/null &
CPID=$!
sleep 8
kill $CPID 2>/dev/null
strings compile.log 2>/dev/null | grep -i "result\|error" | tail -2
ls -la "$EA/PropFirmBot.ex5"

echo ""
echo "=== DONE $(date) ==="
