#!/bin/bash
# v153 - check service file + path + kill source (after sessions closed)
cd /root/MT5-PropFirm-Bot
echo "=== v153 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service: ExecStart path ---"
systemctl cat futures-bot 2>/dev/null | grep -E "ExecStart|WorkingDir"
echo ""
echo "--- Full service file ---"
cat /etc/systemd/system/futures-bot.service 2>/dev/null
echo ""
echo "--- Bot currently running ---"
ps -ef | grep -E "futures_bot|bot\.py" | grep -v grep | head -5
echo ""
echo "--- Last 20 start/stop/kill events ---"
journalctl -u futures-bot --no-pager --since "20 min ago" 2>/dev/null | grep -iE "started|stopped|kill|deactivated" | tail -20
echo ""
echo "--- Reflog (who is pushing to VPS) ---"
git reflog --date=iso | head -10
echo ""
echo "--- Status now ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
date -u
