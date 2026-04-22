#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC') ==="
echo ""
echo "--- run_bot.sh on disk ---"
ls -la /root/MT5-PropFirm-Bot/scripts/run_bot.sh 2>&1
echo ""
echo "--- first 5 lines ---"
head -5 /root/MT5-PropFirm-Bot/scripts/run_bot.sh 2>&1
echo ""
echo "--- can root execute it? ---"
bash -c "file /root/MT5-PropFirm-Bot/scripts/run_bot.sh"
echo ""
echo "--- try running it (timeout 5s) ---"
timeout 5 /root/MT5-PropFirm-Bot/scripts/run_bot.sh 2>&1 | head -20
echo "exit=$?"
echo ""
echo "--- current service ExecStart ---"
systemctl show futures-bot --property=ExecStart --property=ExecStartPre
echo ""
echo "--- cat service file ---"
cat /etc/systemd/system/futures-bot.service
