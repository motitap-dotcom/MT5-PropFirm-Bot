#!/bin/bash
# v158 - make service auto-restart on ANY stop (not just failure)
# + log what caused the stop so we can find the killer later
echo "=== Fix & Restart v158 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- BEFORE ---"
echo "Active: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $PID"
[ -n "$PID" ] && [ "$PID" != "0" ] && echo "CWD: $(readlink /proc/$PID/cwd 2>/dev/null)"

echo ""
echo "--- Write new service: Restart=always, fast restart, log stops ---"
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/futures-bot-wrapper.sh
ExecStopPost=/bin/bash -c 'logger -t futures-bot "Service stopped: SERVICE_RESULT=$SERVICE_RESULT EXIT_CODE=$EXIT_CODE EXIT_STATUS=$EXIT_STATUS"; echo "$(date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ) stopped: result=$SERVICE_RESULT code=$EXIT_CODE status=$EXIT_STATUS" >> /var/log/futures-bot-stops.log'
Restart=always
RestartSec=2
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl enable futures-bot 2>/dev/null
systemctl restart futures-bot
sleep 6

echo ""
echo "--- AFTER ---"
echo "Active: $(systemctl is-active futures-bot)"
NEWPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $NEWPID"
[ -n "$NEWPID" ] && [ "$NEWPID" != "0" ] && echo "CWD: $(readlink /proc/$NEWPID/cwd 2>/dev/null)"
echo "Service file:"
systemctl cat futures-bot 2>/dev/null | grep -E "ExecStart|Restart|ExecStopPost"

echo ""
echo "--- Recent stops log ---"
tail -10 /var/log/futures-bot-stops.log 2>/dev/null || echo "log not yet created"

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
