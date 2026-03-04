#!/bin/bash
# Test Telegram notifications from VPS
# Usage: bash /root/MT5-PropFirm-Bot/scripts/test_telegram.sh

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"

echo "=== Telegram Test $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

# Test 1: Basic message
echo "Sending test message..."
RESULT=$(curl -s -4 --connect-timeout 10 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=🧪 Telegram Test from VPS
Time: $(date '+%Y-%m-%d %H:%M UTC')
MT5: $(pgrep -f terminal64 > /dev/null 2>&1 && echo 'RUNNING' || echo 'DOWN')
Server: $(hostname)" \
    -d "parse_mode=HTML")

if echo "$RESULT" | grep -q '"ok":true'; then
    echo "✅ Telegram is working!"
else
    echo "❌ Telegram FAILED!"
    echo "Response: $RESULT"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check internet: curl -s https://api.telegram.org"
    echo "  2. Check DNS: nslookup api.telegram.org"
    echo "  3. Check token: verify bot token is correct"
fi

echo "=== Done ==="
