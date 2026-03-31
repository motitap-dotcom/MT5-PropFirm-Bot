#!/bin/bash
echo "=== TradeDay Futures Bot - Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Browser Auth Result ---"
if [ -f /root/MT5-PropFirm-Bot/configs/.browser_auth_result.txt ]; then
    cat /root/MT5-PropFirm-Bot/configs/.browser_auth_result.txt
else
    echo "No browser auth result file"
fi
echo ""

echo "--- Token File ---"
if [ -f /root/MT5-PropFirm-Bot/configs/.tradovate_token.json ]; then
    cat /root/MT5-PropFirm-Bot/configs/.tradovate_token.json
else
    echo "No token file"
fi
echo ""

echo "--- Browser Auth Log ---"
if [ -f /tmp/browser_auth.log ]; then
    cat /tmp/browser_auth.log
else
    echo "No browser auth log"
fi
echo ""

echo "--- Bot Service ---"
systemctl is-active futures-bot
systemctl status futures-bot --no-pager | head -15
echo ""

echo "--- Bot Logs (last 30 lines) ---"
tail -30 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null || echo "No log file"
echo ""

echo "--- Journal (last 15 lines) ---"
journalctl -u futures-bot --no-pager -n 15 2>&1
echo ""

echo "--- Current Branch ---"
cd /root/MT5-PropFirm-Bot
git branch --show-current
git log --oneline -3
echo ""

echo "=== Check Complete ==="
