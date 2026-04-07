#!/bin/bash
# Trigger: v114 - Read exact auth functions from Tradovate-Bot
cd /root/MT5-PropFirm-Bot

echo "=== Auth Functions v114 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

echo ""
echo "=== _encrypt_password ==="
sed -n '/^def _encrypt_password/,/^def \|^class /p' /root/tradovate-bot/tradovate_api.py 2>/dev/null | head -20

echo ""
echo "=== _compute_hmac_sec ==="
sed -n '/^def _compute_hmac_sec/,/^def \|^class /p' /root/tradovate-bot/tradovate_api.py 2>/dev/null | head -20

echo ""
echo "=== _try_web_auth ==="
sed -n '/def _try_web_auth/,/^    def /p' /root/tradovate-bot/tradovate_api.py 2>/dev/null | head -60

echo ""
echo "=== Auth constants (top of file) ==="
head -70 /root/tradovate-bot/tradovate_api.py 2>/dev/null | grep -E "WEB_|CID|APP_ID|HMAC|SEC|encrypt|hmac|_KEY"
