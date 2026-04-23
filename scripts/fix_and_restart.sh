#!/bin/bash
# v163 - force restart to load diagnostic logging
echo "=== Fix & Restart v163 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- Verify diag log in code ---"
grep -c 'Price=' /root/MT5-PropFirm-Bot/futures_bot/strategies/vwap_mean_reversion.py 2>/dev/null || echo "NOT FOUND"
echo "RSI thresholds:"
grep -E "rsi_oversold|rsi_overbought" /root/MT5-PropFirm-Bot/configs/bot_config.json
echo ""

echo "--- Sync to /opt ---"
rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/ 2>/dev/null
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/ 2>/dev/null
echo "Synced"
echo ""

echo "--- Restart bot ---"
systemctl restart futures-bot
sleep 12

echo ""
echo "--- AFTER ---"
echo "Active: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "PID: $PID  CWD: $CWD"
echo ""

echo "--- Log tail (look for Price=) ---"
tail -25 "$CWD/logs/bot.log" 2>/dev/null
echo ""

echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
