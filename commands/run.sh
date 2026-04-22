#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC') inspect 2-min crons ==="
echo ""
echo "--- /opt/hyrotrader-bot/scripts/auto_deploy.sh ---"
cat /opt/hyrotrader-bot/scripts/auto_deploy.sh 2>&1 | head -60
echo ""
echo "--- /root/PropFirmBot/scripts/watchdog.sh ---"
cat /root/PropFirmBot/scripts/watchdog.sh 2>&1 | head -60
echo ""
echo "--- /root/mt5_watchdog.sh ---"
cat /root/mt5_watchdog.sh 2>&1 | head -60
echo ""
echo "--- any script doing systemctl on *bot* ---"
grep -rln "systemctl.*bot\|systemctl.*futures" /opt/ /root/*.sh /root/PropFirmBot/ 2>/dev/null | grep -v "/MT5-PropFirm-Bot/"
echo ""
echo "--- /var/log/auth.log last systemctl by who (last 30 min) ---"
grep -E "sudo|systemctl" /var/log/auth.log 2>/dev/null | tail -15
