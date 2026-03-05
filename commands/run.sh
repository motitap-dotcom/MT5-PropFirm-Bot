#!/bin/bash
# =============================================================
# Check if status daemon is running + install if needed
# =============================================================

echo "============================================"
echo "  Check & Install MT5 Status Daemon"
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

# Step 2: Check if daemon exists, install if not
echo "=== [2] Daemon status ==="
if systemctl is-active mt5-status-daemon >/dev/null 2>&1; then
    echo "Daemon is ALREADY RUNNING"
    systemctl status mt5-status-daemon --no-pager -l
else
    echo "Daemon not running - installing now..."
    chmod +x scripts/install_status_daemon.sh
    bash scripts/install_status_daemon.sh
fi
echo ""

# Step 3: Show output
echo "=== [3] /var/bots/mt5_status.json ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
else
    echo "(file not found - daemon may need a few seconds)"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
