#!/bin/bash
# v173 - relax to 0.5SD triggers
echo "=== Fix & Restart v173 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/ 2>/dev/null
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/ 2>/dev/null
systemctl restart futures-bot
sleep 20
PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)  PID: $PID  CWD: $CWD"
echo ""
echo "--- Log tail ---"
tail -30 "$CWD/logs/bot.log" 2>/dev/null
echo ""
echo "=== Done ==="
