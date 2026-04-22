#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC') disable server_cron.sh ==="
echo ""
echo "--- crontab BEFORE ---"
crontab -l 2>&1
echo ""
# Comment out any line that invokes server_cron.sh
crontab -l 2>/dev/null | sed 's|^\([^#].*server_cron.sh.*\)$|# DISABLED_BY_CLAUDE \1|' | crontab -
echo "--- crontab AFTER ---"
crontab -l 2>&1
echo ""
echo "--- service state ---"
systemctl is-active futures-bot
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- run_bot.sh on disk ---"
ls -la scripts/run_bot.sh 2>&1 | head -3
echo ""
echo "--- current git HEAD ---"
git log -1 --oneline
