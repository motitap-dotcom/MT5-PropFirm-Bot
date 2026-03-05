#!/bin/bash
# =============================================================
# Full Status Check - MT5 + EA + Account
# =============================================================

echo "============================================"
echo "  FULL STATUS CHECK"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1) MT5 process
echo "=== [1] MT5 Process ==="
ps aux | grep -i "terminal64\|metatrader" | grep -v grep
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "✅ MT5 is RUNNING"
else
    echo "❌ MT5 is NOT running"
fi
echo ""

# 2) VNC
echo "=== [2] VNC Status ==="
ps aux | grep x11vnc | grep -v grep && echo "✅ VNC running" || echo "❌ VNC not running"
echo ""

# 3) Account status from mt5_status.json
echo "=== [3] Account Status ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
else
    echo "⚠️ mt5_status.json not found"
fi
echo ""

# 4) EA logs (last 30 lines)
echo "=== [4] EA Logs (last 30 lines) ==="
EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
if [ -d "$EA_LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "File: $LATEST_LOG"
        tail -30 "$LATEST_LOG"
    else
        echo "No log files found"
    fi
else
    echo "EA log dir not found"
fi
echo ""

# 5) MT5 terminal logs (last 20 lines)
echo "=== [5] MT5 Terminal Logs (last 20 lines) ==="
MT5_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
if [ -d "$MT5_LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "File: $LATEST_LOG"
        tail -20 "$LATEST_LOG"
    else
        echo "No log files found"
    fi
else
    echo "MT5 log dir not found"
fi
echo ""

# 6) Disk & memory
echo "=== [6] System Resources ==="
echo "--- Disk ---"
df -h / | tail -1
echo "--- Memory ---"
free -h | head -2
echo "--- Uptime ---"
uptime
echo ""

# 7) Status daemon
echo "=== [7] Status Daemon ==="
systemctl is-active mt5-status-daemon 2>/dev/null || echo "daemon not found as systemd service"
ps aux | grep mt5_status | grep -v grep || echo "no mt5_status process"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
