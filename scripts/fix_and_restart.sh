#!/bin/bash
# v168 - delete token + restart so Playwright runs + MD token exchange
echo "=== Fix & Restart v168 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- Delete saved token to force fresh auth ---"
rm -f /root/MT5-PropFirm-Bot/configs/.tradovate_token.json
rm -f /opt/futures_bot_stable/configs/.tradovate_token.json
sed -i 's/^TRADOVATE_ACCESS_TOKEN=.*/TRADOVATE_ACCESS_TOKEN=/' /root/MT5-PropFirm-Bot/.env 2>/dev/null

echo ""
echo "--- Sync code ---"
rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/ 2>/dev/null
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/ 2>/dev/null

echo ""
echo "--- Restart bot ---"
systemctl restart futures-bot
sleep 30  # Playwright + token exchange

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)  PID: $PID  CWD: $CWD"
echo ""

echo "--- Log tail (look for 'auth OK' and 'got X bars') ---"
tail -40 "$CWD/logs/bot.log" 2>/dev/null

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
