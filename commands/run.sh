#!/bin/bash
# =============================================================
# Install MT5 Status Daemon on VPS
# Pulls latest code, installs daemon as systemd service
# =============================================================

echo "============================================"
echo "  Install MT5 Status Daemon"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# Step 1: Pull latest code
echo "=== [1] Pulling latest code ==="
cd /root/MT5-PropFirm-Bot
git fetch origin master
git checkout master 2>/dev/null || git checkout -b master origin/master
git pull origin master
echo ""

# Step 2: Install the daemon
echo "=== [2] Installing status daemon ==="
chmod +x scripts/install_status_daemon.sh
bash scripts/install_status_daemon.sh
echo ""

# Step 3: Verify
echo "=== [3] Verification ==="
sleep 3
systemctl status mt5-status-daemon --no-pager -l
echo ""
echo "--- /var/bots/mt5_status.json ---"
cat /var/bots/mt5_status.json 2>/dev/null || echo "(not created yet)"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
