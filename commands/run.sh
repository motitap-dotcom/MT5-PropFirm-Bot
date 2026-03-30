#!/bin/bash
# Trigger: v68
cd /root/MT5-PropFirm-Bot
date -u
echo "---FILES---"
ls futures_bot/__init__.py futures_bot/bot.py 2>&1
echo "---IMPORT---"
python3 -c "import sys; sys.path.insert(0,'.'); from futures_bot.bot import FuturesBot; print('OK')" 2>&1
echo "---SERVICE---"
cat /etc/systemd/system/futures-bot.service | grep -E "WorkingDir|ExecStart|Env"
echo "---DONE---"
