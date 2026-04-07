#!/bin/bash
# Trigger: v150-diagnose-crash
cd /root/MT5-PropFirm-Bot
echo "=== v150 DIAGNOSE $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service Status ---"
systemctl status futures-bot --no-pager -l 2>&1 | tail -30
echo ""
echo "--- Journal Logs (last 30 lines) ---"
journalctl -u futures-bot --no-pager -n 30 2>&1
echo ""
echo "--- Git Status ---"
git log -3 --oneline
echo ""
echo "--- Python Check ---"
python3 -c "import futures_bot.bot; print('Import OK')" 2>&1
echo ""
echo "--- Check dirs ---"
ls -la status/ 2>&1
ls -la logs/ 2>&1
ls -la configs/bot_config.json 2>&1
echo ""
echo "--- Service File ---"
cat /etc/systemd/system/futures-bot.service 2>&1
echo ""
echo "=== END ==="
