#!/bin/bash
# v155 - RESTORE wrapper-based service (undo v154 mistake)
echo "=== Fix & Restart v155 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- BEFORE: service config ---"
systemctl cat futures-bot 2>/dev/null | grep -E "ExecStart|WorkingDir"

echo ""
echo "--- Wrapper present? ---"
ls -la /usr/local/sbin/futures-bot-wrapper.sh 2>/dev/null || echo "MISSING - aborting"
[ -f /usr/local/sbin/futures-bot-wrapper.sh ] || exit 1

echo ""
echo "--- Wrapper full content ---"
cat /usr/local/sbin/futures-bot-wrapper.sh

# Stop failing loop
systemctl stop futures-bot 2>/dev/null || true
sleep 2
systemctl reset-failed futures-bot 2>/dev/null || true

# Restore wrapper-based service file
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/futures-bot-wrapper.sh
Restart=on-failure
RestartSec=60
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable futures-bot 2>/dev/null
systemctl start futures-bot
sleep 8

echo ""
echo "--- AFTER: service config ---"
systemctl cat futures-bot 2>/dev/null | grep -E "ExecStart|WorkingDir"

echo ""
echo "--- AFTER: status ---"
echo "Active: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"

echo ""
echo "--- AFTER: process ---"
ps -ef | grep -E "futures_bot|bot\.py|futures-bot-wrapper" | grep -v grep | head -5

echo ""
echo "--- Recent bot log (last 20 lines) ---"
LOG=""
for p in /root/MT5-PropFirm-Bot/logs/bot.log /opt/futures_bot_stable/logs/bot.log; do
  if [ -f "$p" ]; then
    LOG="$p"
    echo "Log: $p"
    tail -20 "$p"
    break
  fi
done
[ -z "$LOG" ] && echo "No log file found"

echo ""
echo "--- Recent systemd events ---"
journalctl -u futures-bot --no-pager --since "3 min ago" 2>/dev/null | tail -15

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
