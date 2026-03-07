#!/bin/bash
# Update watchdog + fix AutoTrading with binary-safe grep
echo "=== FIX AT $(date -u) ==="
export DISPLAY=:99

REPO="/root/MT5-PropFirm-Bot"
cd "$REPO"
git reset --hard origin/claude/check-bot-update-status-KDu5H 2>/dev/null
git pull origin claude/check-bot-update-status-KDu5H 2>&1

# Update watchdog
cp "$REPO/scripts/mt5_watchdog.sh" /usr/local/bin/mt5_watchdog.sh
chmod +x /usr/local/bin/mt5_watchdog.sh
echo "[1] Watchdog updated with grep -a fix"

# Fix AutoTrading
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "[2] Last AT state:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -a "automated trading" | tail -3

LAST_AT=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -a "automated trading" | tail -1)
if echo "$LAST_AT" | grep -aq "disabled"; then
    echo "[3] AutoTrading DISABLED - enabling..."
    wine "C:\\at_keybd.exe" 2>/dev/null
    sleep 5
    echo "[4] After toggle:"
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -a "automated trading" | tail -3
else
    echo "[3] AutoTrading already enabled or unknown"
fi

echo "[5] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "[6] Note: It's weekend - no ticks/heartbeats expected until Sunday 22:00 UTC"

echo "=== DONE $(date -u) ==="
