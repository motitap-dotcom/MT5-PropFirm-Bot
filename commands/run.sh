#!/bin/bash
# Update watchdog and force MT5 restart
echo "=== UPDATE WATCHDOG $(date -u) ==="

REPO="/root/MT5-PropFirm-Bot"
cd "$REPO"
git pull --rebase origin claude/check-bot-update-status-KDu5H 2>&1

# Update watchdog script
cp "$REPO/scripts/mt5_watchdog.sh" /usr/local/bin/mt5_watchdog.sh
chmod +x /usr/local/bin/mt5_watchdog.sh

# Kill stale screen session and start fresh
echo "[1] Killing old MT5..."
screen -X -S mt5 quit 2>/dev/null
pkill -9 -f "terminal64\|start.exe" 2>/dev/null
sleep 3

echo "[2] Running watchdog (should detect MT5 down and restart)..."
/usr/local/bin/mt5_watchdog.sh

echo "[3] Watchdog log:"
tail -20 /var/log/mt5_watchdog.log

echo "[4] Waiting 40s..."
sleep 40

echo "[5] MT5 processes:"
ps aux | grep -i "terminal64\|start.exe" | grep -v grep | grep -v "bash -c" | grep -v SCREEN | head -3

echo "[6] Windows:"
export DISPLAY=:99
xdotool search --name "" 2>/dev/null | while read w; do
    NAME=$(xdotool getwindowname "$w" 2>/dev/null)
    [ -n "$NAME" ] && [ "$NAME" != "Default IME" ] && echo "  $w: $NAME"
done

echo "[7] AutoTrading:"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[8] EA status:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "[9] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "=== DONE $(date -u) ==="
