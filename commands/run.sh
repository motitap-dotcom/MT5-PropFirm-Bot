#!/bin/bash
# Trigger: v67 - debug module issue
cd /root/MT5-PropFirm-Bot
date -u
echo "---FILES---"
ls -la futures_bot/
ls -la futures_bot/__init__.py 2>/dev/null || echo "NO __init__.py!"
ls -la futures_bot/bot.py 2>/dev/null || echo "NO bot.py!"
echo "---IMPORT-TEST---"
cd /root/MT5-PropFirm-Bot
python3 -c "import sys; sys.path.insert(0,'.'); from futures_bot.bot import FuturesBot; print('IMPORT OK')" 2>&1
echo "---PYTHON-M-TEST---"
cd /root/MT5-PropFirm-Bot
python3 -m futures_bot.bot --help 2>&1 | head -5 || echo "python -m failed"
echo "---CWD-CHECK---"
cat /etc/systemd/system/futures-bot.service | grep -E "WorkingDir|ExecStart"
echo "---DONE---"
