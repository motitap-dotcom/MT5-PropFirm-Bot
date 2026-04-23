#!/bin/bash
# v162 - loosen RSI + add diag logging + restart
echo "=== Fix & Restart v162 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- Verify new config ---"
grep -E "rsi_oversold|rsi_overbought" /root/MT5-PropFirm-Bot/configs/bot_config.json
echo ""

echo "--- Sync code + config to /opt ---"
rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/
echo "Sync done"
echo ""

echo "--- Restart bot ---"
systemctl restart futures-bot
sleep 10

echo ""
echo "--- AFTER ---"
echo "Active: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value)
echo "PID: $PID"
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "CWD: $CWD"
echo ""

echo "--- Log tail with diagnostics (look for Price=/VWAP=) ---"
tail -40 "$CWD/logs/bot.log" 2>/dev/null | grep -iE "Price=|VWAP=|ATR filter|Signal|Trading symbols"

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
