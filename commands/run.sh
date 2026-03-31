#!/bin/bash
# Trigger: v89 - Check if new auth works after deploy
cd /root/MT5-PropFirm-Bot

echo "=== POST-DEPLOY STATUS CHECK ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "=== Python version ==="
python3 --version
echo ""

echo "=== Playwright installed? ==="
python3 -c "from playwright.sync_api import sync_playwright; print('Playwright OK')" 2>&1
echo ""

echo "=== Chromium browser installed? ==="
python3 -m playwright install --dry-run chromium 2>&1 | head -5 || echo "Cannot check"
ls -la /root/.cache/ms-playwright/ 2>/dev/null || echo "No playwright cache"
echo ""

echo "=== Bot module importable? ==="
cd /root/MT5-PropFirm-Bot
python3 -c "from futures_bot.core.tradovate_client import TradovateClient, _encrypt_password, _compute_hmac_sec; print('Import OK - new auth functions available')" 2>&1
echo ""

echo "=== Service Status ==="
systemctl is-active futures-bot
echo ""

echo "=== Recent Bot Log (last 30 lines) ==="
tail -30 logs/bot.log 2>/dev/null || echo "No bot.log"
echo ""

echo "=== Journal (last 20 lines) ==="
journalctl -u futures-bot --no-pager -n 20 2>&1
echo ""

echo "=== Current branch on VPS ==="
git branch --show-current
git log --oneline -3
echo ""

echo "=== END CHECK ==="
