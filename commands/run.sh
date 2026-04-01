#!/bin/bash
# Trigger: v112 - Create wrapper script + fix service
cd /root/MT5-PropFirm-Bot
echo "=== FIX v112 ==="
date -u

systemctl stop futures-bot 2>/dev/null
systemctl reset-failed futures-bot 2>/dev/null

# Create a wrapper script that can't fail
cat > /root/MT5-PropFirm-Bot/start_bot.sh << 'WRAPPER'
#!/bin/bash
cd /root/MT5-PropFirm-Bot
export PYTHONPATH=/root/MT5-PropFirm-Bot
exec /usr/bin/python3 -m futures_bot.bot
WRAPPER
chmod +x /root/MT5-PropFirm-Bot/start_bot.sh
echo "Wrapper created"

# Test wrapper
echo "=== Test wrapper ==="
cd /root/MT5-PropFirm-Bot
export PYTHONPATH=/root/MT5-PropFirm-Bot
/usr/bin/python3 -c "import futures_bot.bot; print('Import OK')" 2>&1
echo ""

# Debug: check what files exist
echo "=== Files check ==="
ls futures_bot/__init__.py futures_bot/bot.py 2>&1
head -1 futures_bot/__init__.py
head -1 futures_bot/bot.py
echo ""

# Write service using wrapper
cat > /etc/systemd/system/futures-bot.service << 'SVCEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
ExecStart=/root/MT5-PropFirm-Bot/start_bot.sh
Restart=on-failure
RestartSec=60
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SVCEOF
echo "Service updated"

# Save token
mkdir -p configs
echo '{"access_token":"placeholder","expiry":0}' > configs/.tradovate_token.json

systemctl daemon-reload
systemctl start futures-bot
echo "Bot started"

sleep 12
echo ""
echo "Service: $(systemctl is-active futures-bot)"
tail -15 logs/bot.log 2>/dev/null
journalctl -u futures-bot --no-pager -n 8 2>&1
echo "=== END ==="
