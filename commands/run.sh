#!/bin/bash
# Start MT5 as a persistent service that survives SSH disconnect
echo "=== Start MT5 Persistent $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Check if already running
if pgrep -f terminal64.exe >/dev/null 2>&1; then
    echo "MT5 already running: PID $(pgrep -f terminal64.exe)"
    exit 0
fi

# Ensure display is running
export DISPLAY=:99
export WINEPREFIX=/root/.wine

if ! pgrep Xvfb >/dev/null 2>&1; then
    echo "Starting Xvfb..."
    nohup Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 &
    sleep 2
fi

if ! pgrep x11vnc >/dev/null 2>&1; then
    echo "Starting VNC..."
    nohup x11vnc -display :99 -forever -shared -rfbport 5900 -nopw >/dev/null 2>&1 &
    sleep 1
fi

# Create a startup script that runs via screen (survives SSH disconnect)
cat > /root/start_mt5.sh << 'SCRIPT'
#!/bin/bash
export DISPLAY=:99
export WINEPREFIX=/root/.wine
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
while true; do
    echo "[$(date -u)] Starting MT5..."
    wine "${MT5}/terminal64.exe" 2>/dev/null
    echo "[$(date -u)] MT5 exited, restarting in 10 seconds..."
    sleep 10
done
SCRIPT
chmod +x /root/start_mt5.sh

# Kill any existing screen session
screen -S mt5 -X quit 2>/dev/null

# Start MT5 in a screen session (fully detached, survives SSH disconnect)
screen -dmS mt5 bash /root/start_mt5.sh
sleep 8

# Verify
echo ""
echo "=== Verification ==="
echo "Screen sessions:"
screen -ls 2>/dev/null

echo ""
echo "MT5 process:"
pgrep -a terminal64.exe && echo "MT5 RUNNING OK" || echo "MT5 NOT RUNNING!"

echo ""
echo ".ex5 file:"
ls -la "${MT5}/MQL5/Experts/PropFirmBot/PropFirmBot.ex5"

echo ""
echo "Latest EA log:"
LOG_DIR="${MT5}/MQL5/Logs"
LATEST=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -10
fi

echo ""
echo "=== DONE $(date -u) ==="
