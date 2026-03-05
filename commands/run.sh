#!/bin/bash
# =============================================================
# Setup mt5_status.json daemon on VPS
# Creates /var/bots/mt5_status.json with live MT5 status
# =============================================================

echo "============================================"
echo "  Setup: mt5_status.json daemon"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# === Step 1: Check if daemon already exists ===
echo "=== [1] Checking existing daemon ==="
if systemctl is-active --quiet mt5-status-json.service 2>/dev/null; then
    echo "Daemon mt5-status-json is ALREADY RUNNING"
    systemctl status mt5-status-json.service --no-pager 2>/dev/null
    echo ""
    echo "Checking output file:"
    cat /var/bots/mt5_status.json 2>/dev/null || echo "(file not found)"
    echo ""
else
    echo "Daemon not running. Will create and start it."
fi
echo ""

# === Step 2: Create directory ===
echo "=== [2] Creating /var/bots/ directory ==="
mkdir -p /var/bots
chmod 755 /var/bots
echo "Done."
echo ""

# === Step 3: Create the status writer script ===
echo "=== [3] Creating status writer script ==="
cat > /root/PropFirmBot/scripts/mt5_status_writer.sh << 'SCRIPT_EOF'
#!/bin/bash
# mt5_status_writer.sh - writes MT5 status to /var/bots/mt5_status.json every 30 seconds

STATUS_FILE="/var/bots/mt5_status.json"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"

while true; do
    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Check MT5 process
    MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null || true)
    if [ -n "$MT5_PID" ]; then
        MT5_RUNNING=true
        MT5_STATUS="running"
    else
        MT5_RUNNING=false
        MT5_STATUS="stopped"
        MT5_PID="null"
    fi

    # Check VNC
    VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null || true)
    if [ -n "$VNC_PID" ]; then
        VNC_RUNNING=true
    else
        VNC_RUNNING=false
    fi

    # System info
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", $2}' 2>/dev/null || echo "0")
    RAM_TOTAL=$(free -m | awk '/Mem/{print $2}' 2>/dev/null || echo "0")
    RAM_USED=$(free -m | awk '/Mem/{print $3}' 2>/dev/null || echo "0")
    RAM_PCT=$(free | awk '/Mem/{printf "%.1f", $3/$2*100}' 2>/dev/null || echo "0")
    DISK=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "0%")
    UPTIME_SEC=$(cat /proc/uptime | awk '{printf "%d", $1}' 2>/dev/null || echo "0")

    # MT5 connections (broker)
    CONN_COUNT=$(ss -tn state established | grep -v ':22 \|:5900 \|:53 \|:8080' | wc -l 2>/dev/null || echo "0")
    CONN_COUNT=$((CONN_COUNT - 1))  # remove header
    [ "$CONN_COUNT" -lt 0 ] && CONN_COUNT=0

    # EA status from log
    EA_STATUS="unknown"
    LATEST_LOG=$(ls -t "$MT5_DIR/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        LOG_CONTENT=$(cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | tail -50)
        if echo "$LOG_CONTENT" | grep -q "ALL SYSTEMS GO\|INIT"; then
            EA_STATUS="initialized"
        fi
        if echo "$LOG_CONTENT" | grep -q "error\|ERROR\|FATAL"; then
            EA_STATUS="error"
        fi
    fi

    # Watchdog restart count
    RESTART_COUNT=0
    [ -f "/root/PropFirmBot/state/restart_count" ] && RESTART_COUNT=$(cat /root/PropFirmBot/state/restart_count 2>/dev/null || echo "0")

    # Write JSON
    cat > "$STATUS_FILE" << JSONEOF
{
  "timestamp": "$TIMESTAMP",
  "mt5": {
    "running": $MT5_RUNNING,
    "status": "$MT5_STATUS",
    "pid": $MT5_PID
  },
  "vnc": {
    "running": $VNC_RUNNING
  },
  "ea": {
    "status": "$EA_STATUS"
  },
  "system": {
    "cpu_percent": $CPU,
    "ram_used_mb": $RAM_USED,
    "ram_total_mb": $RAM_TOTAL,
    "ram_percent": $RAM_PCT,
    "disk_usage": "$DISK",
    "uptime_seconds": $UPTIME_SEC
  },
  "broker": {
    "connections": $CONN_COUNT
  },
  "watchdog": {
    "restarts_today": $RESTART_COUNT
  }
}
JSONEOF

    sleep 30
done
SCRIPT_EOF

chmod +x /root/PropFirmBot/scripts/mt5_status_writer.sh
echo "Script created at /root/PropFirmBot/scripts/mt5_status_writer.sh"
echo ""

# === Step 4: Create systemd service ===
echo "=== [4] Creating systemd service ==="
cat > /etc/systemd/system/mt5-status-json.service << 'SERVICE_EOF'
[Unit]
Description=MT5 Status JSON Writer
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /root/PropFirmBot/scripts/mt5_status_writer.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

echo "Service file created."
echo ""

# === Step 5: Enable and start ===
echo "=== [5] Starting daemon ==="
systemctl daemon-reload
systemctl enable mt5-status-json.service
systemctl restart mt5-status-json.service
sleep 5

echo "--- Service status ---"
systemctl is-active mt5-status-json.service
systemctl status mt5-status-json.service --no-pager 2>/dev/null | head -15
echo ""

# === Step 6: Verify output ===
echo "=== [6] Verifying /var/bots/mt5_status.json ==="
sleep 3
if [ -f /var/bots/mt5_status.json ]; then
    echo "FILE EXISTS!"
    cat /var/bots/mt5_status.json
else
    echo "WARNING: File not created yet. Checking logs..."
    journalctl -u mt5-status-json.service --no-pager -n 20
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
