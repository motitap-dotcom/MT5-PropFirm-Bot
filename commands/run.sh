#!/bin/bash
# Trigger: journalctl-check v1
cd /root/MT5-PropFirm-Bot
echo "=== Journal Check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
echo "--- systemctl status ---"
systemctl status futures-bot --no-pager -l 2>&1 | head -30
echo ""
echo "--- journalctl last 100 lines ---"
journalctl -u futures-bot -n 100 --no-pager 2>&1
echo ""
echo "--- .env exists? ---"
ls -la .env 2>&1
echo ""
echo "--- Token file exists? ---"
ls -la configs/.tradovate_token.json 2>&1
echo ""
echo "--- Python path test ---"
PYTHONPATH=/root/MT5-PropFirm-Bot python3 -c "import futures_bot.bot" 2>&1 || echo "Import failed"
