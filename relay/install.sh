#!/bin/bash
# One-command installer for the Relay Daemon
# Usage: bash relay/install.sh

echo "=== Installing Relay Daemon ==="

REPO_DIR="/root/MT5-PropFirm-Bot"
DAEMON="$REPO_DIR/relay/daemon.sh"

# Make executable
chmod +x "$DAEMON"

# Create systemd service
cat > /etc/systemd/system/relay-daemon.service << 'EOF'
[Unit]
Description=PropFirmBot Relay Daemon (GitHub-based remote control)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash /root/MT5-PropFirm-Bot/relay/daemon.sh
Restart=always
RestartSec=10
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
Environment=WINEDEBUG=-all
Environment=HOME=/root
WorkingDirectory=/root/MT5-PropFirm-Bot

[Install]
WantedBy=multi-user.target
EOF

# Configure git for push (needed for daemon)
cd "$REPO_DIR"
git config user.name "vps-relay-bot"
git config user.email "relay@propfirmbot.local"

# Enable and start
systemctl daemon-reload
systemctl enable relay-daemon.service
systemctl start relay-daemon.service
sleep 3

echo "=== Status ==="
systemctl status relay-daemon.service --no-pager
echo ""
echo "=== Relay Daemon Installed! ==="
echo "Logs: journalctl -u relay-daemon -f"
echo "Status: systemctl status relay-daemon"
