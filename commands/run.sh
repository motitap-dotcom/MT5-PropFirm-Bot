#!/bin/bash
# =============================================================
# FIX: Add /autotrading flag to mt5.service
# =============================================================

echo "============================================"
echo "  FIX: Enable AutoTrading via CLI flag"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# ============ STEP 1: Update mt5.service with /autotrading flag ============
echo "=== [1] Updating mt5.service ==="

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
ExecStart=/usr/bin/wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading
Restart=always
RestartSec=30
StartLimitIntervalSec=600
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
SVCEOF

echo "Added /autotrading flag to ExecStart"
cat /etc/systemd/system/mt5.service
echo ""

# ============ STEP 2: Restart MT5 ============
echo "=== [2] Restarting MT5 ==="

echo "Stopping MT5..."
systemctl stop mt5.service
sleep 3

# Make sure it's dead
pkill -9 -f terminal64.exe 2>/dev/null
pkill -9 -f wineserver 2>/dev/null
sleep 2

echo "Reloading systemd..."
systemctl daemon-reload

echo "Starting MT5 with /autotrading..."
systemctl start mt5.service
sleep 15

echo "--- mt5.service status ---"
systemctl status mt5.service --no-pager 2>&1 | head -15
echo ""

# ============ STEP 3: Verify ============
echo "=== [3] VERIFICATION ==="

echo "--- MT5 Process (checking /autotrading flag) ---"
ps aux | grep terminal64 | grep -v grep
echo ""

echo "--- mt5.service ---"
echo "  Enabled: $(systemctl is-enabled mt5.service 2>/dev/null)"
echo "  Active: $(systemctl is-active mt5.service 2>/dev/null)"
echo ""

echo "Waiting 25 more seconds for EA to process signals..."
sleep 25

echo "--- Latest EA log (last 20 lines) ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | tail -20
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
