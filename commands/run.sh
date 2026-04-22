#!/bin/bash
echo "=== $(date -u '+%H:%M UTC') status ==="
systemctl is-active futures-bot
systemctl show futures-bot --property=MainPID --property=NRestarts --property=ActiveEnterTimestamp 2>&1
echo ""
echo "--- bot.py locations ---"
ls -la /opt/futures_bot_stable/futures_bot/bot.py /root/MT5-PropFirm-Bot/futures_bot/bot.py 2>&1
echo ""
echo "--- wrapper ---"
ls -la /usr/local/sbin/futures-bot-wrapper.sh 2>&1
echo ""
echo "--- journalctl last 20 ---"
journalctl -u futures-bot --no-pager -n 20 2>&1 | tail -20
