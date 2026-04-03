#!/bin/bash
echo "=== Installing TradeDay Futures Bot ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

# Create virtual environment (like the working bot)
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Install Python dependencies
echo "Installing dependencies..."
venv/bin/pip install --upgrade pip
venv/bin/pip install -r requirements.txt

# Install Playwright + Chromium for CAPTCHA bypass
echo "Installing Playwright browser..."
venv/bin/playwright install chromium
venv/bin/playwright install-deps chromium 2>/dev/null || true

# Create directories
mkdir -p logs status configs

# Create systemd service
cat > /etc/systemd/system/futures-bot.service << 'SERVICEEOF'
[Unit]
Description=TradeDay Futures Trading Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=/root/MT5-PropFirm-Bot/venv/bin/python -m futures_bot.bot
Restart=always
RestartSec=30
MemoryMax=2G
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Create .env template if missing
if [ ! -f /root/MT5-PropFirm-Bot/.env ]; then
    cat > /root/MT5-PropFirm-Bot/.env << 'ENVEOF'
TRADOVATE_USER=
TRADOVATE_PASS=
TRADOVATE_ACCESS_TOKEN=
TELEGRAM_TOKEN=
TELEGRAM_CHAT_ID=
ENVEOF
    echo "Created .env template - FILL IN SECRETS!"
fi

# Enable and start
systemctl daemon-reload
systemctl enable futures-bot
systemctl restart futures-bot

sleep 5
echo ""
echo "=== Service Status ==="
systemctl status futures-bot --no-pager | head -15
echo ""
echo "=== Last 20 log lines ==="
journalctl -u futures-bot --no-pager -n 20
echo ""
echo "=== Installation Complete ==="
