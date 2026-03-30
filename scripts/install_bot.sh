#!/bin/bash
echo "=== Installing TradeDay Futures Bot ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot
PYTHON_BIN="/root/MT5-PropFirm-Bot/venv/bin/python3"
[ ! -f "$PYTHON_BIN" ] && PYTHON_BIN="/usr/bin/python3"

# ── 1. Bot service with crash protection ──
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

# Crash protection: restart with increasing delays, give up after 5 failures in 10 min
Restart=on-failure
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=5

# Memory protection: kill if using more than 500MB
MemoryMax=500M
MemoryHigh=400M

[Install]
WantedBy=multi-user.target
SERVICEEOF

# ── 2. Log rotation - prevents disk filling up ──
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

# ── 3. Watchdog timer - restarts bot if stuck (separate from monitor workflow) ──
cat > /etc/systemd/system/futures-bot-watchdog.service << WDEOF
[Unit]
Description=Futures Bot Watchdog
After=futures-bot.service

[Service]
Type=oneshot
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/bin/bash -c '\
  if systemctl is-active futures-bot >/dev/null 2>&1; then \
    AGE=\$(( \$(date +%%s) - \$(stat -c %%Y logs/bot.log 2>/dev/null || echo 0) )); \
    if [ "\$AGE" -gt 900 ]; then \
      echo "Watchdog: bot.log stale (\${AGE}s), restarting..."; \
      systemctl restart futures-bot; \
    fi; \
  else \
    echo "Watchdog: bot not running, starting..."; \
    systemctl start futures-bot; \
  fi'
WDEOF

cat > /etc/systemd/system/futures-bot-watchdog.timer << 'WTEOF'
[Unit]
Description=Run Futures Bot Watchdog every 5 minutes

[Timer]
OnBootSec=60
OnUnitActiveSec=300

[Install]
WantedBy=timers.target
WTEOF

# ── 4. Token backup cron - copies token every hour ──
cat > /etc/cron.d/futures-bot-token-backup << 'CRONEOF'
0 * * * * root cp -f /root/MT5-PropFirm-Bot/configs/.tradovate_token.json /root/MT5-PropFirm-Bot/configs/.tradovate_token_backup.json 2>/dev/null; cp -f /root/MT5-PropFirm-Bot/configs/.tradovate_token.json /root/.tradovate_token_safe.json 2>/dev/null
CRONEOF

# ── 5. Disk cleanup cron - weekly ──
cat > /etc/cron.d/futures-bot-cleanup << 'CLEANEOF'
0 4 * * 0 root find /root/MT5-PropFirm-Bot/logs -name "*.log.*.gz" -mtime +14 -delete 2>/dev/null; journalctl --vacuum-time=7d 2>/dev/null
CLEANEOF

# ── Enable everything ──
mkdir -p logs status configs
systemctl daemon-reload
systemctl enable futures-bot
systemctl enable futures-bot-watchdog.timer
systemctl start futures-bot-watchdog.timer

echo ""
echo "Installed:"
echo "  - futures-bot.service (auto-start on boot, crash protection)"
echo "  - futures-bot-watchdog.timer (checks every 5 min)"
echo "  - logrotate (daily, max 10MB, 7 days)"
echo "  - token backup cron (hourly)"
echo "  - disk cleanup cron (weekly)"
echo ""
echo "=== Installation Complete ==="
