#!/bin/bash
# Trigger: setup v7 - fix VNC + setup browser for CAPTCHA
echo "=== VNC + Browser Setup ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

# Check if display is running
echo "--- Display Status ---"
if pgrep -x Xvfb > /dev/null; then
    echo "Xvfb: RUNNING"
else
    echo "Xvfb: NOT running, starting..."
    Xvfb :99 -screen 0 1024x768x16 &
    sleep 2
    echo "Xvfb started"
fi
export DISPLAY=:99

# Check VNC
echo ""
echo "--- VNC Status ---"
if pgrep -x x11vnc > /dev/null; then
    echo "x11vnc: RUNNING"
else
    echo "x11vnc: NOT running, starting..."
    apt-get install -y x11vnc xvfb 2>/dev/null | tail -3
    x11vnc -display :99 -forever -nopw -shared -rfbport 5900 &
    sleep 2
    echo "x11vnc started on port 5900"
fi

# Install a lightweight browser if not present
echo ""
echo "--- Browser ---"
if command -v firefox &> /dev/null; then
    echo "Firefox: installed"
elif command -v chromium-browser &> /dev/null; then
    echo "Chromium: installed"
else
    echo "No browser found, installing..."
    apt-get update -qq && apt-get install -y -qq firefox 2>&1 | tail -5
fi

# Install a window manager if not present
if ! pgrep -x fluxbox > /dev/null && ! pgrep -x openbox > /dev/null; then
    echo "No window manager, installing fluxbox..."
    apt-get install -y -qq fluxbox 2>&1 | tail -3
    DISPLAY=:99 fluxbox &
    sleep 1
fi

echo ""
echo "--- Connection Info ---"
echo "VNC: Connect to VPS_IP:5900 with RealVNC"
echo "Then open Firefox and go to trader.tradovate.com"
echo ""
echo "=== Done ==="
