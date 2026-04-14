#!/bin/bash
# Trigger: v152 — write service file with PYTHONPATH and daemon-reload (no restart)
cd /root/MT5-PropFirm-Bot
echo "=== v152 service-file-fix $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""

# Write corrected service file with PYTHONPATH
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/usr/bin/python3 -m futures_bot.bot
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/root/MT5-PropFirm-Bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF

# Reload systemd + reset failure counter (does NOT restart)
systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null

echo "--- service file content ---"
cat /etc/systemd/system/futures-bot.service
echo ""
echo "--- SERVICE STATE (before natural restart) ---"
systemctl is-active futures-bot
systemctl show futures-bot --property=MainPID --value

echo ""
echo "--- WAITING 75s for systemd auto-restart to pick up new service file ---"
sleep 75

echo ""
echo "--- SERVICE STATE (after wait) ---"
systemctl is-active futures-bot
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- JOURNALCTL LAST 15 LINES ---"
journalctl -u futures-bot --no-pager -n 15 2>&1 | tail -15
echo ""
echo "--- BOT LOG (entries from today 20:30+) ---"
awk '/2026-04-(13 2[0-3]|14)/' logs/bot.log 2>/dev/null | tail -30
echo ""
echo "--- STATUS JSON ---"
if [ -f status/status.json ]; then
  echo "age: $(( $(date +%s) - $(stat -c %Y status/status.json) ))s"
  python3 -c "import json; d=json.load(open('status/status.json')); g=d.get('guardian',{}); print('  state:', g.get('state')); print('  balance:', g.get('balance')); print('  daily_pnl:', g.get('daily_pnl'))" 2>/dev/null
fi
echo ""
echo "--- DASHBOARD ---"
[ -f status/dashboard.txt ] && { echo "age: $(( $(date +%s) - $(stat -c %Y status/dashboard.txt) ))s"; cat status/dashboard.txt; } || echo "not yet"
echo ""
echo "=== END v152 ==="
