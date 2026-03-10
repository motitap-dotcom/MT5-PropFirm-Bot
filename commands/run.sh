#!/bin/bash
# =============================================================
# RESTART MT5 + DEPLOY LATEST + FIX TELEGRAM
# March 10, 2026
# =============================================================

echo "============================================"
echo "  FULL RESTART & FIX"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

export DISPLAY=:99

# 1. Kill any leftover MT5 processes
echo "=== [1] Stopping old MT5 ==="
pkill -f terminal64 2>/dev/null
pkill -f metatrader 2>/dev/null
sleep 2
echo "Old processes killed"
echo ""

# 2. Make sure Xvfb is running
echo "=== [2] Display Setup ==="
if ! pgrep -x Xvfb > /dev/null; then
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
echo "Xvfb status: $(pgrep -x Xvfb > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"

# Make sure x11vnc is running
if ! pgrep -x x11vnc > /dev/null; then
    echo "Starting x11vnc..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
fi
echo "VNC status: $(pgrep -x x11vnc > /dev/null && echo 'RUNNING' || echo 'NOT RUNNING')"
echo ""

# 3. Fix Telegram WebRequest in MT5 config
echo "=== [3] Fixing MT5 Config (Telegram WebRequest) ==="
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
MT5_INI="$MT5_DIR/config/common.ini"
TERMINAL_INI="$MT5_DIR/terminal64.ini"

# Find the actual config file
for CONF_FILE in "$MT5_INI" "$TERMINAL_INI" "$MT5_DIR/MQL5/Profiles/Charts/Default/chart01.chr"; do
    if [ -f "$CONF_FILE" ]; then
        echo "Found config: $CONF_FILE"
    fi
done

# Check and fix common.ini for WebRequest
if [ -f "$MT5_INI" ]; then
    echo "Current common.ini:"
    cat "$MT5_INI"
    if ! grep -q "api.telegram.org" "$MT5_INI" 2>/dev/null; then
        echo ""
        echo "Adding Telegram WebRequest URL..."
        # Add WebRequest section if missing
        if ! grep -q "\[WebRequest\]" "$MT5_INI" 2>/dev/null; then
            echo "" >> "$MT5_INI"
            echo "[WebRequest]" >> "$MT5_INI"
        fi
        echo "https://api.telegram.org=1" >> "$MT5_INI"
        echo "WebRequest URL added"
    else
        echo "Telegram URL already in config"
    fi
else
    echo "common.ini not found, creating..."
    mkdir -p "$MT5_DIR/config"
    cat > "$MT5_INI" << 'INIEOF'
[Common]
Login=11797849
ProxyEnable=0
AutoUpdate=0

[WebRequest]
https://api.telegram.org=1
INIEOF
    echo "Created common.ini with WebRequest"
fi

# Also check terminal64.ini
if [ -f "$TERMINAL_INI" ]; then
    echo ""
    echo "terminal64.ini exists"
    if ! grep -q "api.telegram.org" "$TERMINAL_INI" 2>/dev/null; then
        if ! grep -q "\[WebRequest\]" "$TERMINAL_INI" 2>/dev/null; then
            echo "" >> "$TERMINAL_INI"
            echo "[WebRequest]" >> "$TERMINAL_INI"
        fi
        echo "https://api.telegram.org=1" >> "$TERMINAL_INI"
        echo "Added Telegram URL to terminal64.ini"
    fi
fi
echo ""

# 4. Make sure EA files are latest
echo "=== [4] EA Files Check ==="
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
ls -la "$EA_DIR/PropFirmBot.mq5" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

# 5. Start MT5
echo "=== [5] Starting MT5 ==="
cd "$MT5_DIR"
WINEPREFIX=/root/.wine wine "$MT5_DIR/terminal64.exe" /portable &
MT5_PID=$!
echo "MT5 started with PID: $MT5_PID"

# Wait for MT5 to fully load
echo "Waiting for MT5 to load (30 seconds)..."
sleep 30

# Check if MT5 is running
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5 IS RUNNING!"
else
    echo "WARNING: MT5 may not have started. Trying again..."
    WINEPREFIX=/root/.wine wine "$MT5_DIR/terminal64.exe" /portable &
    sleep 30
fi
echo ""

# 6. Verify MT5 is running
echo "=== [6] Verification ==="
MT5_CHECK=$(pgrep -af terminal64 2>/dev/null)
if [ -n "$MT5_CHECK" ]; then
    echo "MT5 PROCESS: RUNNING"
    echo "$MT5_CHECK"
else
    echo "MT5 PROCESS: NOT FOUND - PROBLEM!"
fi

# Check if log file is being written (means EA is active)
LATEST_LOG="$MT5_DIR/MQL5/Logs/$(date '+%Y%m%d').log"
if [ -f "$LATEST_LOG" ]; then
    LOG_SIZE=$(stat -c %s "$LATEST_LOG" 2>/dev/null)
    echo "Today's log exists, size: $LOG_SIZE bytes"
    echo "Last 10 log lines:"
    tail -10 "$LATEST_LOG"
else
    echo "Today's log not found yet"
fi
echo ""

# 7. Check status JSON
echo "=== [7] Bot Status ==="
sleep 5
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null
else
    # Check the MT5 Files dir for status
    STATUS_FILE="$MT5_DIR/MQL5/Files/PropFirmBot/status.json"
    if [ -f "$STATUS_FILE" ]; then
        python3 -m json.tool "$STATUS_FILE" 2>/dev/null
    else
        echo "No status JSON found"
    fi
fi
echo ""

echo "============================================"
echo "  RESTART COMPLETE: $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
