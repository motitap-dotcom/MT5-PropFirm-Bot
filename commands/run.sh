#!/bin/bash
# Check AutoTrading fix result and current bot status
echo "=== CHECK $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] MT5 process:"
pgrep -a terminal64 2>/dev/null || echo "NOT RUNNING"

echo "[2] AutoTrading fix log:"
cat /tmp/at_log.txt 2>/dev/null || echo "No log yet"

echo "[3] All named X windows:"
xdotool search --name "" 2>/dev/null | while read w; do
    NAME=$(xdotool getwindowname "$w" 2>/dev/null)
    [ -n "$NAME" ] && echo "  $w: $NAME"
done

echo "[4] EA log (recent):"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -15

echo "[5] Bot status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "[6] MT5 service:"
systemctl status mt5 2>/dev/null | head -8

echo "[7] MT5 service file:"
cat /etc/systemd/system/mt5.service 2>/dev/null

echo "=== DONE $(date -u) ==="
