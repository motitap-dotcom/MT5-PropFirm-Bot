#!/bin/bash
# Trigger: v117 - Fix wrapper in permanent location + restart
cd /root/MT5-PropFirm-Bot
mkdir -p status logs configs

# Create wrapper in /usr/local/bin (survives git reset)
cat > /usr/local/bin/start-futures-bot.sh << 'WRAPPER'
#!/bin/bash
cd /root/MT5-PropFirm-Bot
export PYTHONPATH=/root/MT5-PropFirm-Bot
exec /usr/bin/python3 -m futures_bot.bot
WRAPPER
chmod +x /usr/local/bin/start-futures-bot.sh
echo "Wrapper saved to /usr/local/bin/"

# Update service to use permanent wrapper
cat > /etc/systemd/system/futures-bot.service << 'EOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/start-futures-bot.sh
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl reset-failed futures-bot 2>/dev/null
systemctl restart futures-bot
echo "Bot restarted"

sleep 15
echo "Service: $(systemctl is-active futures-bot)"
echo ""
tail -20 logs/bot.log 2>/dev/null || echo "No log yet"
journalctl -u futures-bot --no-pager -n 8 2>&1
echo "=== END ==="
