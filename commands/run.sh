#!/bin/bash
# v152 - minimal: find kill source + path check
cd /root/MT5-PropFirm-Bot
echo "=== v152 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service file ---"
cat /etc/systemd/system/futures-bot.service 2>/dev/null | head -30
echo ""
echo "--- ExecStart target ---"
systemctl cat futures-bot 2>/dev/null | grep -E "ExecStart|WorkingDir" | head -5
echo ""
echo "--- Is /opt/futures_bot_stable the same as /root/MT5-PropFirm-Bot? ---"
ls -la /opt/futures_bot_stable/futures_bot/bot.py 2>/dev/null
ls -la /root/MT5-PropFirm-Bot/futures_bot/bot.py 2>/dev/null
echo ""
echo "--- Scripts referencing futures-bot systemctl (top 10) ---"
timeout 20 grep -rls "systemctl.*futures-bot" /root /opt /usr/local 2>/dev/null | grep -v "\.git/" | head -10
echo ""
echo "--- Service status and last restart ---"
systemctl is-active futures-bot
systemctl show futures-bot --property=ActiveEnterTimestamp --value
systemctl show futures-bot --property=MainPID --value
echo ""
echo "--- Last 15 kill/stop events for futures-bot ---"
journalctl -u futures-bot --no-pager --since "30 min ago" 2>/dev/null | grep -iE "kill|stopped|deactivated" | tail -15
echo ""
echo "--- Time ---"
date -u
