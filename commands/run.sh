#!/bin/bash
# Trigger: v98 - Install protection stack + fix token renewal
cd /root/MT5-PropFirm-Bot

echo "=== FULL INSTALL v98 - $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="

PYTHON_BIN="/root/MT5-PropFirm-Bot/venv/bin/python3"
[ ! -f "$PYTHON_BIN" ] && PYTHON_BIN="/usr/bin/python3"

# ── Write .env ──
if [ -n "$TRADOVATE_USER" ]; then
    echo "TRADOVATE_USER=$TRADOVATE_USER" > .env
    echo "TRADOVATE_PASS=$TRADOVATE_PASS" >> .env
    echo "TRADOVATE_ACCESS_TOKEN=$TRADOVATE_ACCESS_TOKEN" >> .env
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" >> .env
    echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> .env
    echo ".env written"
fi

# ── Systemd service with crash + memory protection ──
echo "--- Installing service ---"
cat > /etc/systemd/system/futures-bot.service << SERVICEEOF
[Unit]
Description=TradeDay Futures Trading Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=${PYTHON_BIN} -m futures_bot.bot
EnvironmentFile=/root/MT5-PropFirm-Bot/.env
Environment=PYTHONUNBUFFERED=1
Restart=on-failure
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=5
MemoryMax=500M

[Install]
WantedBy=multi-user.target
SERVICEEOF

# ── Watchdog timer (checks every 5 min) ──
echo "--- Installing watchdog ---"
cat > /etc/systemd/system/futures-bot-watchdog.service << 'WDEOF'
[Unit]
Description=Futures Bot Watchdog

[Service]
Type=oneshot
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash -c 'if systemctl is-active futures-bot >/dev/null 2>&1; then AGE=$(( $(date +%%s) - $(stat -c %%Y logs/bot.log 2>/dev/null || echo 0) )); if [ "$AGE" -gt 900 ]; then systemctl restart futures-bot; fi; else systemctl start futures-bot; fi'
WDEOF

cat > /etc/systemd/system/futures-bot-watchdog.timer << 'WTEOF'
[Unit]
Description=Futures Bot Watchdog Timer

[Timer]
OnBootSec=60
OnUnitActiveSec=300

[Install]
WantedBy=timers.target
WTEOF

# ── Log rotation ──
echo "--- Installing logrotate ---"
cat > /etc/logrotate.d/futures-bot << 'LOGEOF'
/root/MT5-PropFirm-Bot/logs/bot.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    copytruncate
    size 10M
}
LOGEOF

# ── Token backup cron ──
echo "--- Installing token backup ---"
cat > /etc/cron.d/futures-bot-token-backup << 'CRONEOF'
0 * * * * root cp -f /root/MT5-PropFirm-Bot/configs/.tradovate_token.json /root/.tradovate_token_safe.json 2>/dev/null
CRONEOF

# ── Enable everything ──
mkdir -p logs status configs
systemctl daemon-reload
systemctl enable futures-bot
systemctl enable futures-bot-watchdog.timer
systemctl start futures-bot-watchdog.timer

# ── Restart bot ──
echo "--- Restarting bot ---"
systemctl restart futures-bot
sleep 10

echo ""
echo "Service: $(systemctl is-active futures-bot)"
echo "Watchdog: $(systemctl is-active futures-bot-watchdog.timer)"
echo ""
tail -15 logs/bot.log 2>/dev/null || echo "No log yet"
echo ""
echo "Disk: $(df -h / | tail -1)"
echo ""
echo "=== DONE ==="
