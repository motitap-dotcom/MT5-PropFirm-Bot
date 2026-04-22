#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC') ==="
echo ""
echo "--- git state ---"
git log -1 --oneline 2>&1
echo ""
echo "--- scripts/ listing ---"
ls -la /root/MT5-PropFirm-Bot/scripts/ 2>&1
echo ""
echo "--- run_bot.sh exists? ---"
test -e scripts/run_bot.sh && echo YES || echo NO
cat scripts/run_bot.sh 2>&1 | head -3
