#!/bin/bash
# =============================================================
# FIX: Enable AutoTrading + Fix mt5.service
# =============================================================

echo "============================================"
echo "  FIX: AutoTrading + mt5.service"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
STARTUP_INI="$MT5/config/startup.ini"

# ============ STEP 1: Enable AutoTrading in startup.ini ============
echo "=== [1] FIXING AutoTrading ==="

# Show current startup.ini
echo "--- Current startup.ini ---"
if [ -f "$STARTUP_INI" ]; then
    cat "$STARTUP_INI"
else
    echo "(file does not exist, will create)"
fi
echo ""

# Create/update startup.ini with AutoTrading enabled
mkdir -p "$MT5/config"

# Check if startup.ini exists and has content
if [ -f "$STARTUP_INI" ]; then
    # Remove any existing AutoTrading line
    sed -i '/^AutoTrading=/d' "$STARTUP_INI"
    # Remove any existing EnableAutoTrading line
    sed -i '/^EnableAutoTrading=/d' "$STARTUP_INI"

    # Add AutoTrading=1 to [Common] section if it exists
    if grep -q '^\[Common\]' "$STARTUP_INI"; then
        sed -i '/^\[Common\]/a AutoTrading=1' "$STARTUP_INI"
    else
        # Add [Common] section with AutoTrading
        echo "" >> "$STARTUP_INI"
        echo "[Common]" >> "$STARTUP_INI"
        echo "AutoTrading=1" >> "$STARTUP_INI"
    fi
else
    # Create new startup.ini
    cat > "$STARTUP_INI" << 'INIEOF'
[Common]
AutoTrading=1

[Experts]
AllowLiveTrading=1
AllowDllImport=0
Enabled=1
INIEOF
fi

echo "--- Updated startup.ini ---"
cat "$STARTUP_INI"
echo ""

# Also check terminal64.ini for AutoTrading setting
TERMINAL_INI="$MT5/terminal64.ini"
if [ -f "$TERMINAL_INI" ]; then
    echo "--- Current terminal64.ini (AutoTrading related) ---"
    grep -i "auto\|expert\|trading" "$TERMINAL_INI" 2>/dev/null || echo "(no matching lines)"

    # Enable AutoTrading in terminal64.ini
    if grep -q 'AutoTrading=' "$TERMINAL_INI"; then
        sed -i 's/AutoTrading=0/AutoTrading=1/g' "$TERMINAL_INI"
    fi
    if grep -q 'ExpertsEnable=' "$TERMINAL_INI"; then
        sed -i 's/ExpertsEnable=0/ExpertsEnable=1/g' "$TERMINAL_INI"
    fi

    echo "--- Updated terminal64.ini (AutoTrading related) ---"
    grep -i "auto\|expert\|trading" "$TERMINAL_INI" 2>/dev/null || echo "(no matching lines)"
else
    echo "terminal64.ini not found at $TERMINAL_INI"
fi
echo ""

# ============ STEP 2: Fix mt5.service ============
echo "=== [2] FIXING mt5.service ==="

# Stop any running MT5 first
echo "Stopping current MT5 process..."
pkill -f terminal64.exe 2>/dev/null
sleep 3

# Check if MT5 stopped
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "MT5 still running, force killing..."
    pkill -9 -f terminal64.exe 2>/dev/null
    sleep 2
fi
echo "MT5 stopped."
echo ""

# Update mt5.service with proper parameters (login + autotrading)
echo "Updating mt5.service..."
cat > /etc/systemd/system/mt5.service << 'SVCEOF'
[Unit]
Description=MetaTrader 5 Trading Terminal
After=network.target xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=root
Environment=DISPLAY=:99
Environment=WINEPREFIX=/root/.wine
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server
Restart=always
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
SVCEOF

echo "--- New mt5.service ---"
cat /etc/systemd/system/mt5.service
echo ""

# Reload systemd and start the service
echo "Reloading systemd..."
systemctl daemon-reload

echo "Starting mt5.service..."
systemctl start mt5.service
sleep 10

echo "--- mt5.service status ---"
systemctl status mt5.service --no-pager 2>&1 | head -20
echo ""

# ============ STEP 3: VERIFY ============
echo "=== [3] VERIFICATION ==="

echo "--- MT5 Process ---"
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "MT5: RUNNING"
    ps aux | grep terminal64 | grep -v grep
else
    echo "MT5: NOT RUNNING!"
fi
echo ""

echo "--- mt5.service ---"
echo "  Enabled: $(systemctl is-enabled mt5.service 2>/dev/null)"
echo "  Active: $(systemctl is-active mt5.service 2>/dev/null)"
echo ""

# Wait for MT5 to fully start and check logs
echo "Waiting 20 more seconds for MT5 to initialize..."
sleep 20

echo "--- Latest EA log (last 15 lines) ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | tail -15
else
    echo "No EA logs yet"
fi
echo ""

echo "--- Latest Terminal log (last 10 lines) ---"
TERM_LOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    cat "$TERM_LOG" 2>/dev/null | tr -d '\0' | tail -10
else
    echo "No terminal logs yet"
fi
echo ""

echo "=== FIX DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
