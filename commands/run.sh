#!/bin/bash
# Trigger: systemd-env-check
cd /root/MT5-PropFirm-Bot
echo "=== Systemd Env Check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- systemctl cat (what systemd sees) ---"
systemctl cat futures-bot 2>&1
echo ""
echo "--- Effective environment systemd passes to service ---"
systemctl show futures-bot --property=Environment --value
systemctl show futures-bot --property=EnvironmentFiles --value
echo ""
echo "--- .env content (masked) ---"
cat .env 2>&1 | sed 's/\(=.\{1,5\}\).*/\1***/' || echo "No .env"
echo ""
echo "--- Try exact systemd command manually ---"
cd /root/MT5-PropFirm-Bot
set -a
. /root/MT5-PropFirm-Bot/.env 2>/dev/null
set +a
export PYTHONPATH=/root/MT5-PropFirm-Bot
export PYTHONUNBUFFERED=1
timeout 5 /usr/bin/python3 -m futures_bot.bot 2>&1 | head -30 || echo "[exit: $?]"
