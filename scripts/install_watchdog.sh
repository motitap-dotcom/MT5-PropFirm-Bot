#!/bin/bash
###############################################################################
# Install MT5 Watchdog on VPS
# - Copies watchdog script
# - Sets up cron job (every 2 minutes)
# - Sets up MT5 systemd service (auto-start on boot)
# - Starts everything
###############################################################################

echo "=== INSTALLING MT5 WATCHDOG ==="
REPO="/root/MT5-PropFirm-Bot"

# Step 1: Copy watchdog script
echo "[1] Installing watchdog script..."
cp "$REPO/scripts/mt5_watchdog.sh" /usr/local/bin/mt5_watchdog.sh
chmod +x /usr/local/bin/mt5_watchdog.sh

# Step 2: Create systemd service for MT5 (auto-start on boot)
echo "[2] Creating MT5 systemd service..."
cat > /etc/systemd/system/mt5.service << 'EOF'
[Unit]
Description=MetaTrader 5 Trading Platform
After=network.target

[Service]
Type=forking
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
ExecStartPre=/bin/bash -c 'pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)'
ExecStartPre=/bin/bash -c 'pgrep x11vnc || x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw'
ExecStart=/usr/bin/screen -dmS mt5 /bin/bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && cd "/root/.wine/drive_c/Program Files/MetaTrader 5" && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server'
ExecStop=/usr/bin/pkill -f terminal64.exe
Restart=on-failure
RestartSec=30
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5.service
echo "  MT5 service enabled (auto-start on boot)"

# Step 3: Set up cron job - watchdog every 2 minutes
echo "[3] Setting up watchdog cron job..."
# Remove old entries if any
crontab -l 2>/dev/null | grep -v "mt5_watchdog" > /tmp/cron_clean
# Add new entry
echo "*/2 * * * * /usr/local/bin/mt5_watchdog.sh >> /var/log/mt5_watchdog.log 2>&1" >> /tmp/cron_clean
crontab /tmp/cron_clean
rm -f /tmp/cron_clean
echo "  Cron job installed (every 2 minutes)"

# Step 4: Create log file
touch /var/log/mt5_watchdog.log
echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] Watchdog installed" >> /var/log/mt5_watchdog.log

# Step 5: Run watchdog once now
echo "[4] Running watchdog now..."
/usr/local/bin/mt5_watchdog.sh

# Step 6: Verify
echo ""
echo "[5] Verification:"
echo "  Cron jobs:"
crontab -l 2>/dev/null | grep mt5
echo "  Systemd service:"
systemctl is-enabled mt5.service 2>/dev/null
echo "  Watchdog log:"
tail -5 /var/log/mt5_watchdog.log

echo ""
echo "=== WATCHDOG INSTALLED SUCCESSFULLY ==="
echo "  - MT5 will auto-start on boot (systemd)"
echo "  - Watchdog checks every 2 minutes (cron)"
echo "  - Auto-fixes: MT5 crash, AutoTrading off, EA detached"
echo "  - Log: /var/log/mt5_watchdog.log"
