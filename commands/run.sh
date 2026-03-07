#!/bin/bash
# Deploy and install MT5 watchdog system
echo "=== DEPLOY WATCHDOG $(date -u) ==="

REPO="/root/MT5-PropFirm-Bot"

# Pull latest code
cd "$REPO"
git pull origin claude/check-bot-update-status-KDu5H 2>&1

# Make scripts executable
chmod +x "$REPO/scripts/mt5_watchdog.sh"
chmod +x "$REPO/scripts/install_watchdog.sh"

# Run installer
bash "$REPO/scripts/install_watchdog.sh"

echo ""
echo "=== Waiting 30s for watchdog first run ==="
sleep 30

echo "[FINAL] Watchdog log:"
tail -15 /var/log/mt5_watchdog.log

echo "[FINAL] MT5 processes:"
ps aux | grep -i "terminal64\|wine" | grep -v grep | head -3

echo "[FINAL] AutoTrading:"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[FINAL] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "=== DONE $(date -u) ==="
