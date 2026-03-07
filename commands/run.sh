#!/bin/bash
# Fix VPS repo branch, install watchdog, restart MT5
echo "=== FIX & DEPLOY $(date -u) ==="

REPO="/root/MT5-PropFirm-Bot"
cd "$REPO"

# Fix git config and switch to correct branch
git config pull.rebase false
git fetch origin claude/check-bot-update-status-KDu5H
git checkout -f claude/check-bot-update-status-KDu5H 2>&1 || git checkout -b claude/check-bot-update-status-KDu5H origin/claude/check-bot-update-status-KDu5H
git reset --hard origin/claude/check-bot-update-status-KDu5H

echo "[1] Branch:"
git branch --show-current
echo "[2] Files exist?"
ls -la scripts/mt5_watchdog.sh scripts/install_watchdog.sh 2>&1

# Make executable and install
chmod +x scripts/mt5_watchdog.sh scripts/install_watchdog.sh
bash scripts/install_watchdog.sh

echo ""
echo "=== Wait 30s ==="
sleep 30

echo "[FINAL] Watchdog log:"
tail -15 /var/log/mt5_watchdog.log

echo "[FINAL] MT5:"
ps aux | grep -i "terminal64" | grep -v grep | head -2

echo "[FINAL] Cron:"
crontab -l 2>/dev/null | grep mt5

echo "=== DONE $(date -u) ==="
