#!/bin/bash
# Trigger: post-restart-check — did vps-fix.yml run?
cd /root/MT5-PropFirm-Bot
echo "=== Post-restart check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- SERVICE ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID:     $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime:  $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- CODE ---"
echo "Branch:  $(git rev-parse --abbrev-ref HEAD)"
echo "Commit:  $(git log -1 --oneline)"
echo ""
echo "--- DST fix present? ---"
grep -c "zoneinfo" futures_bot/core/risk_manager.py && echo "DST fix IN DEPLOYED CODE"
echo ""
echo "--- Which Python process is actually running? ---"
PID=$(systemctl show futures-bot --property=MainPID --value)
if [ -n "$PID" ] && [ "$PID" != "0" ]; then
  echo "Running since: $(ps -o lstart= -p $PID 2>/dev/null | tr -s ' ')"
  echo "Command: $(cat /proc/$PID/cmdline 2>/dev/null | tr '\0' ' ')"
fi
echo ""
echo "--- Last 20 log lines ---"
tail -20 logs/bot.log 2>/dev/null
echo ""
echo "--- vps_fix_report.txt (if exists) ---"
if [ -f vps_fix_report.txt ]; then
  echo "(file age: $(( $(date +%s) - $(stat -c %Y vps_fix_report.txt) ))s)"
  head -40 vps_fix_report.txt
else
  echo "(no report file)"
fi
