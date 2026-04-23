#!/bin/bash
# v167 - fix authorize format (JSON body)
echo "=== Fix & Restart v167 - authorize JSON fix ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- verify new code ---"
grep -c "json.dumps({'token'" /root/MT5-PropFirm-Bot/futures_bot/core/tradovate_client.py 2>/dev/null && echo "auth JSON fix: YES" || echo "NO"
echo ""

echo "--- sync to /opt ---"
rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/

echo "--- Restart ---"
systemctl restart futures-bot
sleep 15

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)  PID: $PID  CWD: $CWD"
echo ""

echo "--- Log tail - look for 'auth OK' and 'got X bars' ---"
tail -40 "$CWD/logs/bot.log" 2>/dev/null

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
