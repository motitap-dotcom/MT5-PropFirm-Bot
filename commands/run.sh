#!/bin/bash
# =============================================================
# Install MT5 Status Daemon on VPS
# =============================================================

echo "============================================"
echo "  Install MT5 Status Daemon"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

cd /root/MT5-PropFirm-Bot

# Step 1: Get the daemon files from the feature branch
echo "=== [1] Fetching daemon files ==="
git fetch origin claude/add-trade-data-mt5-f2Bja
git checkout origin/claude/add-trade-data-mt5-f2Bja -- scripts/mt5_status_daemon.py scripts/install_status_daemon.sh
ls -la scripts/mt5_status_daemon.py scripts/install_status_daemon.sh
echo ""

# Step 2: Install
echo "=== [2] Installing daemon ==="
chmod +x scripts/install_status_daemon.sh
bash scripts/install_status_daemon.sh
echo ""

# Step 3: Verify
echo "=== [3] Verification ==="
sleep 6
systemctl status mt5-status-daemon --no-pager -l 2>&1 | head -20
echo ""
echo "--- /var/bots/mt5_status.json ---"
cat /var/bots/mt5_status.json 2>/dev/null || echo "(not created yet)"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
