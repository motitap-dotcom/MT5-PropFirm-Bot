#!/bin/bash
# =============================================================
# Restart MT5 Status Daemon after code update
# =============================================================

echo "============================================"
echo "  Restart mt5-status-daemon"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# Pull latest code
echo "=== [1] Pull latest code ==="
cd /root/MT5-PropFirm-Bot
git pull origin "$(git rev-parse --abbrev-ref HEAD)" 2>&1
echo ""

# Reinstall / restart daemon
echo "=== [2] Restart daemon ==="
bash /root/MT5-PropFirm-Bot/scripts/install_status_daemon.sh 2>&1
echo ""

# Show output
echo "=== [3] Current /var/bots/mt5_status.json ==="
python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || echo "(file not found or invalid)"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
