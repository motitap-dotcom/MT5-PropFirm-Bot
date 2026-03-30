#!/bin/bash
# Trigger: v59 - Quick check only, no auth test
cd /root/MT5-PropFirm-Bot
date -u
echo "---SERVICE---"
cat /etc/systemd/system/futures-bot.service 2>/dev/null || echo "NO SERVICE FILE"
echo "---ENV-KEYS---"
if [ -f .env ]; then grep -o '^[^=]*' .env; else echo "NO .ENV"; fi
echo "---IMPORT-TEST---"
cd /root/MT5-PropFirm-Bot && python3 -c "import sys; sys.path.insert(0,'.'); from futures_bot.bot import FuturesBot; print('OK')" 2>&1
echo "---DONE---"
