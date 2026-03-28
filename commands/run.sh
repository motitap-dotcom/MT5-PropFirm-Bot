#!/bin/bash
# Trigger: status-check-v1
echo "=== VPS STATUS CHECK ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "=== SYSTEM ==="
uptime
free -h | head -2
echo ""

echo "=== BOT SERVICE ==="
systemctl is-active futures-bot 2>/dev/null || echo "Service not found"
systemctl status futures-bot --no-pager 2>/dev/null | head -15
echo ""

echo "=== RECENT LOGS (last 50 lines) ==="
cd /root/MT5-PropFirm-Bot
tail -50 logs/bot.log 2>/dev/null || echo "No bot.log found"
echo ""

echo "=== JOURNAL LOGS (last 10 min) ==="
journalctl -u futures-bot --no-pager -n 30 --since "10 min ago" 2>/dev/null || echo "No journal entries"
echo ""

echo "=== ENV FILE CHECK ==="
if [ -f /root/MT5-PropFirm-Bot/.env ]; then
    echo ".env exists"
    echo "Variables defined:"
    grep -c "TRADOVATE_USER" .env && echo "  TRADOVATE_USER: SET" || echo "  TRADOVATE_USER: MISSING"
    grep -c "TRADOVATE_PASS" .env && echo "  TRADOVATE_PASS: SET" || echo "  TRADOVATE_PASS: MISSING"
    grep -c "TRADOVATE_ACCESS_TOKEN" .env && echo "  TRADOVATE_ACCESS_TOKEN: SET" || echo "  TRADOVATE_ACCESS_TOKEN: MISSING"
    grep -c "TELEGRAM_TOKEN" .env && echo "  TELEGRAM_TOKEN: SET" || echo "  TELEGRAM_TOKEN: MISSING"
    grep -c "TELEGRAM_CHAT_ID" .env && echo "  TELEGRAM_CHAT_ID: SET" || echo "  TELEGRAM_CHAT_ID: MISSING"
else
    echo ".env FILE MISSING!"
fi
echo ""

echo "=== TOKEN FILE ==="
if [ -f /root/MT5-PropFirm-Bot/configs/.tradovate_token.json ]; then
    echo "Token file exists:"
    cat configs/.tradovate_token.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Expires: {d.get(\"expirationTime\",\"unknown\")}')" 2>/dev/null || echo "Could not parse token"
else
    echo "No token file found"
fi
echo ""

echo "=== PYTHON VERSION ==="
python3 --version
echo ""

echo "=== INSTALLED PACKAGES ==="
pip3 list 2>/dev/null | grep -E "aiohttp|websockets|requests" || echo "Could not check packages"
echo ""

echo "=== NETWORK CHECK ==="
curl -s -o /dev/null -w "Tradovate API: %{http_code}\n" https://demo.tradovateapi.com/v1 --max-time 5 || echo "Tradovate: UNREACHABLE"
curl -s -o /dev/null -w "Telegram API: %{http_code}\n" https://api.telegram.org --max-time 5 || echo "Telegram: UNREACHABLE"
echo ""

echo "=== STATUS JSON ==="
cat /root/MT5-PropFirm-Bot/status/status.json 2>/dev/null || echo "No status.json"
echo ""
echo "=== CHECK COMPLETE ==="
