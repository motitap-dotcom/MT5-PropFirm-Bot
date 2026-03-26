#!/bin/bash
echo "=== TradeDay Futures Bot - Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- System ---"
uptime
free -h | head -3
echo ""

echo "--- Bot Process ---"
if systemctl is-active futures-bot >/dev/null 2>&1; then
    echo "Bot service: RUNNING"
    systemctl status futures-bot --no-pager | head -10
else
    echo "Bot service: NOT RUNNING"
    # Check if running as process
    if pgrep -f "futures_bot/bot.py" >/dev/null; then
        echo "Bot process found (not as service)"
        ps aux | grep "futures_bot/bot.py" | grep -v grep
    else
        echo "No bot process found"
    fi
fi
echo ""

echo "--- Python ---"
python3 --version
pip3 show aiohttp websockets 2>/dev/null | grep -E "^(Name|Version)"
echo ""

echo "--- Bot Logs (last 30 lines) ---"
if [ -f /root/MT5-PropFirm-Bot/logs/bot.log ]; then
    tail -30 /root/MT5-PropFirm-Bot/logs/bot.log
else
    echo "No log file found"
fi
echo ""

echo "--- Status JSON ---"
if [ -f /root/MT5-PropFirm-Bot/status/status.json ]; then
    cat /root/MT5-PropFirm-Bot/status/status.json
else
    echo "No status file found"
fi
echo ""

echo "--- Network Check ---"
curl -s -o /dev/null -w "Tradovate API: %{http_code}\n" https://demo.tradovateapi.com/v1 || echo "Cannot reach Tradovate API"
curl -s -o /dev/null -w "Telegram API: %{http_code}\n" https://api.telegram.org || echo "Cannot reach Telegram"
echo ""

echo "=== Check Complete ==="
