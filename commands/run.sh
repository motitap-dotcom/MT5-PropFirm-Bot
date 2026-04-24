#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== Deep check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "PID: $PID  CWD: $CWD"
echo ""

echo "--- Does /root have latest code? ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/bot.py 2>/dev/null
grep -c "WebSocket md/getChart" /root/MT5-PropFirm-Bot/futures_bot/core/tradovate_client.py 2>/dev/null
grep -c "_ws_closed" /root/MT5-PropFirm-Bot/futures_bot/core/tradovate_client.py 2>/dev/null
echo ""

echo "--- Why is wrapper falling back to /opt? ---"
cat /usr/local/sbin/futures-bot-wrapper.sh 2>/dev/null | head -20
echo ""

echo "--- Full bot log from last 10 min ---"
tail -100 "$CWD/logs/bot.log" 2>/dev/null
echo ""

echo "--- Stop log ---"
tail -10 /var/log/futures-bot-stops.log 2>/dev/null
echo ""

echo "--- Git state ---"
cd /root/MT5-PropFirm-Bot
echo "Branch: $(git branch --show-current)"
echo "HEAD: $(git log -1 --oneline)"
echo "Main: $(git log -1 origin/main --oneline 2>/dev/null)"

echo ""
echo "=== Done ==="
