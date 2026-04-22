#!/bin/bash
# Trigger: post-fix-verify
cd /root/MT5-PropFirm-Bot
echo "=== Post-fix verify $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "=== SERVICE ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Code on disk: $(git log -1 --oneline)"
echo ""
echo "=== CODE CHECK (Playwright fallback in tree?) ==="
grep -n "API auth failed.*trying Playwright" futures_bot/core/tradovate_client.py || echo "NOT FOUND"
echo ""
echo "=== TOKEN FILE ==="
ls -la configs/.tradovate_token.json 2>/dev/null || echo "no token file (expected - new fresh auth)"
echo ""
echo "=== PLAYWRIGHT ==="
python3 -c "import playwright; print('playwright version:', playwright.__version__)" 2>&1
ls /root/.cache/ms-playwright/ 2>/dev/null | head -5 || echo "no chromium cache"
echo ""
echo "=== LAST 80 LOG LINES ==="
tail -80 logs/bot.log 2>/dev/null || echo "no log"
echo ""
echo "=== AUTH / PLAYWRIGHT / TRADE events ==="
grep -iE "auth|playwright|captcha|browser|TRADE:|Signal|Connected" logs/bot.log 2>/dev/null | tail -30
echo ""
echo "=== ERRORS ==="
grep -iE "ERROR|FAILED|Traceback" logs/bot.log 2>/dev/null | tail -20
echo ""
echo "=== POSITIONS / STATUS ==="
cat status/status.json 2>/dev/null | head -40 || echo "no status.json"
