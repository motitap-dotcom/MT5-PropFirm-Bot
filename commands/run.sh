#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC') quick killer search ==="
echo ""
echo "--- scripts that mention futures-bot ---"
grep -l "futures-bot" /opt/hyrotrader-bot/scripts/*.sh /root/PropFirmBot/scripts/*.sh /root/*.sh /etc/cron.d/* 2>/dev/null
echo ""
echo "--- /etc/cron.d contents ---"
for f in /etc/cron.d/*; do echo "=== $f ==="; cat "$f" 2>/dev/null | head -5; done
echo ""
echo "--- service state ---"
systemctl is-active futures-bot
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
systemctl show futures-bot --property=ActiveEnterTimestamp
echo ""
echo "--- last 15 journalctl ---"
journalctl -u futures-bot --no-pager -n 15 2>&1 | tail -15
echo ""
echo "--- bot log last 15 ---"
tail -15 logs/bot.log
