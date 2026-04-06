#!/bin/bash
# Trigger: v89 - Status check only (no restart)
cd /root/MT5-PropFirm-Bot

mkdir -p logs status

# Collect status without restarting
STATUS=$(systemctl is-active futures-bot)
UPTIME=$(systemctl show futures-bot --property=ActiveEnterTimestamp --value 2>/dev/null)
LOGS=$(journalctl -u futures-bot --no-pager -n 30 2>&1)
BOTLOG=$(tail -30 logs/bot.log 2>/dev/null)
STATUSJSON=$(cat status/status.json 2>/dev/null)

echo "=== Bot Status Report v87 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Service: ${STATUS}"
echo "Running since: ${UPTIME}"
echo ""
echo "=== Journal Logs (last 30 lines) ==="
echo "${LOGS}"
echo ""
echo "=== Bot Log (last 30 lines) ==="
echo "${BOTLOG}"
echo ""
echo "=== status.json ==="
echo "${STATUSJSON}"
