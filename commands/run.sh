#!/bin/bash
# =============================================================
# Restart MT5 on VPS
# =============================================================

echo "=== Restarting MT5 - $(date) ==="

# Kill any stuck MT5 processes
echo "--- Stopping old MT5 processes ---"
pkill -f terminal64 2>/dev/null || echo "No MT5 process to kill"
pkill -f metatrader 2>/dev/null || true
sleep 2

# Make sure Xvfb is running
echo "--- Checking display server ---"
if ! pgrep -x Xvfb > /dev/null; then
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
else
    echo "Xvfb already running"
fi
export DISPLAY=:99

# Make sure VNC is running
echo "--- Checking VNC ---"
if ! pgrep -x x11vnc > /dev/null; then
    echo "Starting x11vnc..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
else
    echo "x11vnc already running"
fi

# Start MT5
echo "--- Starting MT5 ---"
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
WINEPREFIX=/root/.wine DISPLAY=:99 wine terminal64.exe /portable &
MT5_PID=$!
echo "MT5 started with PID: $MT5_PID"

# Wait for MT5 to initialize
sleep 10

# Verify
echo ""
echo "--- Verification ---"
if pgrep -a terminal64; then
    echo "MT5 is RUNNING!"
else
    echo "WARNING: MT5 may not have started properly"
fi

echo ""
echo "--- System Status ---"
echo "Uptime: $(uptime)"
echo "Memory: $(free -h | grep Mem)"

echo ""
echo "=== Done ==="
