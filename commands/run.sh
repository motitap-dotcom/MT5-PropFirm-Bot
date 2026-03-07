#!/bin/bash
# Deploy fixed watchdog + verify
echo "=== DEPLOY FIXED WATCHDOG $(date -u) ==="

REPO="/root/MT5-PropFirm-Bot"
cd "$REPO"
git reset --hard origin/claude/check-bot-update-status-KDu5H 2>/dev/null
git pull origin claude/check-bot-update-status-KDu5H 2>&1

# Update watchdog
cp "$REPO/scripts/mt5_watchdog.sh" /usr/local/bin/mt5_watchdog.sh
chmod +x /usr/local/bin/mt5_watchdog.sh
echo "[1] Watchdog updated"

# Run watchdog once
echo "[2] Running watchdog..."
/usr/local/bin/mt5_watchdog.sh

echo "[3] Watchdog log:"
tail -10 /var/log/mt5_watchdog.log

echo "[4] Cron active:"
crontab -l 2>/dev/null | grep mt5

echo "=== DONE $(date -u) ==="
