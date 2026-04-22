#!/bin/bash
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
systemctl is-active futures-bot
systemctl show futures-bot --property=MainPID --property=NRestarts --property=ActiveEnterTimestamp
echo ""
echo "--- where is wrapper reading bot.py from ---"
journalctl -u futures-bot --no-pager -n 80 2>&1 | grep -E "BOT_DIR|wrapper|SIGTERM|Stopping|Signal|TRADE|SIGNAL|bar|Got.*bars|No module|can't open" | tail -25
echo ""
echo "--- bot log last 40 (whichever location it uses) ---"
tail -40 /opt/futures_bot_stable/logs/bot.log 2>/dev/null || tail -40 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null
echo ""
echo "--- recent logs from /opt ---"
ls -la /opt/futures_bot_stable/logs/ 2>&1
echo "--- recent logs from /root ---"
ls -la /root/MT5-PropFirm-Bot/logs/ 2>&1
