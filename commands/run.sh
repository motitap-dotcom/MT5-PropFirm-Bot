#!/bin/bash
# Trigger: v113 - Check how Tradovate-Bot authenticates
cd /root/MT5-PropFirm-Bot

echo "=== Tradovate-Bot Auth Analysis v113 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"

echo ""
echo "=== Token files ==="
ls -la /root/tradovate-bot/.tradovate_token* 2>&1
ls -la /root/tradovate-bot/configs/.tradovate_token* 2>&1

echo ""
echo "=== .env of Tradovate-Bot ==="
cat /root/tradovate-bot/.env 2>/dev/null | grep -v "PASSWORD\|PASS\|SECRET\|TOKEN" | head -20
echo ""
echo "Token-related env vars (redacted):"
grep -c "ACCESS_TOKEN" /root/tradovate-bot/.env 2>/dev/null && echo "  ACCESS_TOKEN line exists" || echo "  No ACCESS_TOKEN line"
grep "ACCESS_TOKEN" /root/tradovate-bot/.env 2>/dev/null | sed 's/=.*/=<REDACTED>/'

echo ""
echo "=== Tradovate-Bot service status ==="
systemctl is-active tradovate-bot 2>&1
echo ""

echo "=== Tradovate-Bot recent auth logs ==="
journalctl -u tradovate-bot --no-pager -n 50 2>/dev/null | grep -i "auth\|token\|connect\|login\|captcha\|success" | tail -15

echo ""
echo "=== Tradovate-Bot config.py auth section ==="
grep -A 5 -i "auth\|cid\|app_id\|appid\|secret\|captcha\|browser\|playwright" /root/tradovate-bot/config.py 2>/dev/null | head -30

echo ""
echo "=== tradovate_api.py auth method order ==="
grep -n "def.*auth\|try_.*auth\|browser\|playwright\|captcha\|p-ticket\|encrypt\|hmac" /root/tradovate-bot/tradovate_api.py 2>/dev/null | head -20
