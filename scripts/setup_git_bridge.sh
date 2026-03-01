#!/bin/bash
# One-time setup script for Git Bridge on VPS
# Run this ONCE on the VPS to set up everything

REPO_DIR="/root/MT5-PropFirm-Bot"
BRANCH="claude/bot-status-check-g8Wi9"

echo "=== Setting up Git Bridge ==="

# 1. Go to repo
cd "$REPO_DIR" || { echo "❌ Repo not found at $REPO_DIR"; exit 1; }

# 2. Fetch and switch to the bridge branch
echo "Fetching branch $BRANCH..."
git fetch origin "$BRANCH"
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
git pull origin "$BRANCH"

# 3. Make scripts executable
chmod +x scripts/git_bridge.sh
chmod +x scripts/check_bot_status.sh

# 4. Set up git identity (for commits from VPS)
git config user.email "bot@vps.propfirmbot"
git config user.name "PropFirmBot VPS"

# 5. Create directories
mkdir -p bridge/commands bridge/reports

# 6. Create systemd service for git bridge
cat > /etc/systemd/system/git-bridge.service << 'SYSTEMD_EOF'
[Unit]
Description=PropFirmBot Git Bridge
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /root/MT5-PropFirm-Bot/scripts/git_bridge.sh
WorkingDirectory=/root/MT5-PropFirm-Bot
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# 7. Enable and start the service
systemctl daemon-reload
systemctl enable git-bridge.service
systemctl start git-bridge.service

echo ""
echo "=== Setup Complete ==="
echo "Git Bridge is now running as a system service!"
echo ""
echo "Useful commands:"
echo "  Check status:  systemctl status git-bridge"
echo "  View logs:     journalctl -u git-bridge -f"
echo "  Restart:       systemctl restart git-bridge"
echo "  Stop:          systemctl stop git-bridge"
echo ""
echo "The bridge will check for commands every 60 seconds."
echo "Claude can now send commands by pushing .cmd files to bridge/commands/"
