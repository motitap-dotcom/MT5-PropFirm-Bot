#!/bin/bash
# v159 - fast restart: TimeoutStopSec=3s so kills don't stall
echo "=== Fix & Restart v159 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- BEFORE ---"
echo "Active: $(systemctl is-active futures-bot)"

cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/futures-bot-wrapper.sh
ExecStopPost=/bin/bash -c 'logger -t futures-bot "Stopped: result=$SERVICE_RESULT code=$EXIT_CODE status=$EXIT_STATUS"; echo "$(date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ) stopped: result=$SERVICE_RESULT code=$EXIT_CODE status=$EXIT_STATUS" >> /var/log/futures-bot-stops.log'
Restart=always
RestartSec=2
TimeoutStopSec=5
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null

echo ""
echo "--- New service config ---"
systemctl cat futures-bot | grep -E "ExecStart|Restart|Timeout"

echo ""
echo "--- Stop log (who killed in last hour) ---"
tail -20 /var/log/futures-bot-stops.log 2>/dev/null || echo "no log"

echo ""
echo "--- Current state (NOT restarting - let it keep running) ---"
echo "Active: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value)
echo "PID: $PID"
[ -n "$PID" ] && [ "$PID" != "0" ] && {
  echo "CWD: $(readlink /proc/$PID/cwd 2>/dev/null)"
  echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
}

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
