#!/bin/bash
# v164 - force restart with bars logging
echo "=== Fix & Restart v164 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- Verify new code is there ---"
grep -c "got .* bars from /md/getChart" /root/MT5-PropFirm-Bot/futures_bot/bot.py 2>/dev/null && echo "bars-log: YES" || echo "bars-log: NO"
echo ""

echo "--- Sync /root to /opt ---"
rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/
echo "Synced"
echo ""

echo "--- Restart ---"
systemctl restart futures-bot
sleep 12

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $PID  CWD: $CWD"
echo ""

echo "--- Log tail after restart (30 lines) ---"
tail -30 "$CWD/logs/bot.log" 2>/dev/null

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
