#!/bin/bash
# v166 - FORCE fresh Playwright auth to get full MD permissions
echo "=== Fix & Restart v166 - Fresh Playwright Auth ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- BEFORE ---"
echo "Active: $(systemctl is-active futures-bot)"

echo ""
echo "--- Delete saved token so bot must do full auth via Playwright ---"
rm -f /root/MT5-PropFirm-Bot/configs/.tradovate_token.json
rm -f /opt/futures_bot_stable/configs/.tradovate_token.json
echo "Token files removed"

echo ""
echo "--- Clear env TRADOVATE_ACCESS_TOKEN so saved/env paths fail ---"
if [ -f /root/MT5-PropFirm-Bot/.env ]; then
  sed -i 's/^TRADOVATE_ACCESS_TOKEN=.*/TRADOVATE_ACCESS_TOKEN=/' /root/MT5-PropFirm-Bot/.env
  echo ".env cleared env token"
fi

echo ""
echo "--- Sync code ---"
rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/ 2>/dev/null
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/ 2>/dev/null

echo ""
echo "--- Restart bot (will do full Playwright auth) ---"
systemctl restart futures-bot
sleep 30  # Playwright needs time

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $PID  CWD: $CWD"
echo ""

echo "--- Log tail after restart ---"
tail -35 "$CWD/logs/bot.log" 2>/dev/null

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
