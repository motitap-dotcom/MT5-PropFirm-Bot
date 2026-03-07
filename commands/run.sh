#!/bin/bash
# Fix VPS repo, update watchdog, fix AutoTrading
echo "=== FIX ALL $(date -u) ==="
export DISPLAY=:99

REPO="/root/MT5-PropFirm-Bot"
cd "$REPO"

# Fix stuck rebase
git rebase --abort 2>/dev/null
rm -rf .git/rebase-merge 2>/dev/null
git checkout claude/check-bot-update-status-KDu5H 2>/dev/null
git reset --hard origin/claude/check-bot-update-status-KDu5H 2>/dev/null
git pull origin claude/check-bot-update-status-KDu5H 2>&1

echo "[1] Repo status:"
git log --oneline -3

# Update watchdog
cp "$REPO/scripts/mt5_watchdog.sh" /usr/local/bin/mt5_watchdog.sh
chmod +x /usr/local/bin/mt5_watchdog.sh
echo "[2] Watchdog updated"

# Fix AutoTrading NOW (it was toggled OFF by mistake)
echo "[3] Fixing AutoTrading..."
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
LAST_AT=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1)
echo "  Current: $LAST_AT"

if echo "$LAST_AT" | grep -q "disabled"; then
    echo "  Sending Ctrl+E to enable..."
    wine "C:\\at_keybd.exe" 2>/dev/null
    sleep 5
    LAST_AT2=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1)
    echo "  After toggle: $LAST_AT2"
fi

echo "[4] EA log last 5:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "[5] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "=== DONE $(date -u) ==="
