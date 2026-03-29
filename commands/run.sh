#!/bin/bash
# Trigger: restart-v2
# NOTE: git pull is done by the workflow BEFORE this script runs
cd /root/MT5-PropFirm-Bot
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

systemctl stop futures-bot
echo "Bot stopped"

echo "=== Syntax check ==="
python3 -c "import py_compile; py_compile.compile('futures_bot/core/tradovate_client.py', doraise=True); print('tradovate_client.py OK')"
python3 -c "import py_compile; py_compile.compile('futures_bot/bot.py', doraise=True); print('bot.py OK')"

mkdir -p logs status
systemctl daemon-reload
systemctl restart futures-bot
sleep 5
echo "Bot status: $(systemctl is-active futures-bot)"
journalctl -u futures-bot --no-pager -n 20 --since "10 sec ago"
echo "DONE"
