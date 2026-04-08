#!/bin/bash
# Trigger: v150 - diagnose why bot won't start
cd /root/MT5-PropFirm-Bot
echo "=== Bot Diagnostic v150 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service Status (detailed) ---"
systemctl status futures-bot --no-pager -l 2>&1 | head -30
echo ""
echo "--- Service File ---"
cat /etc/systemd/system/futures-bot.service 2>/dev/null || echo "SERVICE FILE NOT FOUND"
echo ""
echo "--- Journal Logs (last 50 lines) ---"
journalctl -u futures-bot --no-pager -n 50 2>&1
echo ""
echo "--- .env exists? ---"
ls -la /root/MT5-PropFirm-Bot/.env 2>/dev/null || echo ".env NOT FOUND"
echo ""
echo "--- Token file exists? ---"
ls -la /root/MT5-PropFirm-Bot/configs/.tradovate_token.json 2>/dev/null || echo "Token file NOT FOUND"
echo ""
echo "--- Config files ---"
ls -la /root/MT5-PropFirm-Bot/configs/ 2>/dev/null
echo ""
echo "--- Python test import ---"
cd /root/MT5-PropFirm-Bot && PYTHONPATH=/root/MT5-PropFirm-Bot python3 -c "import futures_bot.bot; print('Import OK')" 2>&1
echo ""
echo "--- Disk space ---"
df -h / | tail -1
echo ""
echo "--- Memory ---"
free -m | head -2
