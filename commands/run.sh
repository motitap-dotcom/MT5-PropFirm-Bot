#!/bin/bash
# Quick MT5 restart - March 10, 2026
echo "=== QUICK RESTART $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

export DISPLAY=:99

# Kill old MT5
echo "[1] Killing old MT5..."
pkill -9 -f terminal64 2>/dev/null
sleep 2

# Ensure display
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
echo "Xvfb: $(pgrep -x Xvfb > /dev/null && echo OK || echo MISSING)"

# Ensure VNC
if ! pgrep -x x11vnc > /dev/null; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
fi
echo "VNC: $(pgrep -x x11vnc > /dev/null && echo OK || echo MISSING)"

# Fix Telegram WebRequest in MT5 config
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
for CONF in "$MT5_DIR/config/common.ini" "$MT5_DIR/terminal64.ini"; do
    if [ -f "$CONF" ]; then
        if ! grep -q "api.telegram.org" "$CONF" 2>/dev/null; then
            grep -q "\[WebRequest\]" "$CONF" 2>/dev/null || echo -e "\n[WebRequest]" >> "$CONF"
            echo "https://api.telegram.org=1" >> "$CONF"
            echo "Fixed Telegram in: $CONF"
        else
            echo "Telegram already in: $CONF"
        fi
    fi
done

# Start MT5 in background with nohup
echo "[2] Starting MT5..."
cd "$MT5_DIR"
nohup wine "$MT5_DIR/terminal64.exe" /portable > /tmp/mt5_start.log 2>&1 &
echo "MT5 launched (PID: $!)"

# Short wait to check it started
sleep 15

# Verify
echo "[3] Verification:"
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
    pgrep -af terminal64
else
    echo "MT5: NOT YET VISIBLE (may still be loading)"
fi

# Check EA log
LOG_FILE="$MT5_DIR/MQL5/Logs/$(date '+%Y%m%d').log"
if [ -f "$LOG_FILE" ]; then
    echo "Log size: $(stat -c %s "$LOG_FILE") bytes"
    echo "Last 5 lines:"
    tail -5 "$LOG_FILE" | strings
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
