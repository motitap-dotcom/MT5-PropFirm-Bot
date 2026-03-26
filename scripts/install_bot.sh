#!/bin/bash
echo "=== Installing TradeDay Futures Bot as systemd service ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

# Install Python dependencies
pip3 install -r requirements.txt

# Create systemd service
cat > /etc/systemd/system/futures-bot.service << 'SERVICEEOF'
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

# Load secrets from environment file
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Create .env template (secrets should be filled in)
if [ ! -f /root/MT5-PropFirm-Bot/.env ]; then
    cat > /root/MT5-PropFirm-Bot/.env << 'ENVEOF'
TRADOVATE_USER=
TRADOVATE_PASS=
TRADOVATE_APP_ID=
TRADOVATE_CID=
TRADOVATE_SEC=
TELEGRAM_TOKEN=
TELEGRAM_CHAT_ID=
ENVEOF
    echo "Created .env template - FILL IN SECRETS!"
fi

# Create logs directory
mkdir -p /root/MT5-PropFirm-Bot/logs

# Enable and start
systemctl daemon-reload
systemctl enable futures-bot
systemctl start futures-bot

sleep 3
echo ""
echo "Service status:"
systemctl status futures-bot --no-pager | head -15
echo ""
echo "=== Installation Complete ==="
