#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC') restore cron + find killer ==="
echo ""
# Restore the cron entry I wrongly disabled
crontab -l 2>/dev/null | sed 's|^# DISABLED_BY_CLAUDE \(.*server_cron.sh.*\)$|\1|' | crontab -
echo "--- crontab restored ---"
crontab -l 2>&1
echo ""
echo "--- auto_deploy.sh for hyrotrader ---"
cat /opt/hyrotrader-bot/scripts/auto_deploy.sh 2>&1 | head -40
echo ""
echo "--- PropFirmBot watchdog ---"
cat /root/PropFirmBot/scripts/watchdog.sh 2>&1 | head -40
echo ""
echo "--- mt5_watchdog.sh ---"
cat /root/mt5_watchdog.sh 2>&1 | head -30
echo ""
echo "--- find processes/scripts that mention futures-bot ---"
grep -rln "futures-bot\|futures_bot" /root/ /etc/ /opt/ 2>/dev/null | grep -v "/MT5-PropFirm-Bot/" | head -20
echo ""
echo "--- /etc/cron.d ---"
ls /etc/cron.d/ /etc/cron.hourly/ /etc/cron.daily/ 2>&1 | head -30
echo ""
echo "--- current service status ---"
systemctl is-active futures-bot
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
journalctl -u futures-bot --no-pager -n 6 | tail -6
