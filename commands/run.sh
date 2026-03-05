#!/bin/bash
# =============================================================
# STATUS CHECK ONLY - No changes made!
# =============================================================

echo "============================================"
echo "  VPS STATUS CHECK (READ ONLY)"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# ============ 1: PROCESSES ============
echo "=== [1] RUNNING PROCESSES ==="

echo "--- MT5 ---"
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "MT5: RUNNING"
    ps aux | grep terminal64 | grep -v grep
else
    echo "MT5: NOT RUNNING!"
fi
echo ""

echo "--- Xvfb ---"
if pgrep -x Xvfb > /dev/null 2>&1; then
    echo "Xvfb: RUNNING"
    ps aux | grep Xvfb | grep -v grep
else
    echo "Xvfb: NOT RUNNING!"
fi
echo ""

echo "--- x11vnc ---"
if pgrep -f x11vnc > /dev/null 2>&1; then
    echo "VNC: RUNNING"
else
    echo "VNC: NOT RUNNING!"
fi
echo ""

echo "--- Wine ---"
wine --version 2>/dev/null || echo "Wine: NOT FOUND!"
echo ""

# ============ 2: SYSTEMD SERVICES ============
echo "=== [2] SYSTEMD SERVICES ==="

for svc in xvfb mt5 x11vnc; do
    echo "--- ${svc}.service ---"
    if [ -f /etc/systemd/system/${svc}.service ]; then
        echo "  File: EXISTS"
        echo "  Enabled: $(systemctl is-enabled ${svc}.service 2>/dev/null || echo 'NO')"
        echo "  Active: $(systemctl is-active ${svc}.service 2>/dev/null || echo 'NO')"
    else
        echo "  File: MISSING!"
    fi
done
echo ""

echo "--- mt5.service content ---"
if [ -f /etc/systemd/system/mt5.service ]; then
    cat /etc/systemd/system/mt5.service
else
    echo "(does not exist)"
fi
echo ""

echo "--- xvfb.service content ---"
if [ -f /etc/systemd/system/xvfb.service ]; then
    cat /etc/systemd/system/xvfb.service
else
    echo "(does not exist)"
fi
echo ""

# ============ 3: CRON & WATCHDOG ============
echo "=== [3] CRON & WATCHDOG ==="

echo "--- Crontab ---"
crontab -l 2>/dev/null || echo "No crontab"
echo ""

echo "--- Watchdog script ---"
for dir in /root/PropFirmBot/scripts /home/ubuntu/PropFirmBot/scripts; do
    if [ -f "$dir/watchdog.sh" ]; then
        echo "EXISTS at $dir/watchdog.sh"
    fi
done
echo ""

echo "--- Watchdog log (last 15 lines) ---"
for dir in /root/PropFirmBot/logs /home/ubuntu/PropFirmBot/logs; do
    if [ -f "$dir/watchdog.log" ]; then
        echo "From $dir/watchdog.log:"
        tail -15 "$dir/watchdog.log"
    fi
done
echo ""

# ============ 4: MT5 LOGS ============
echo "=== [4] MT5 LOGS ==="

echo "--- EA Logs ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $(basename "$LATEST_LOG") ($(stat -c%s "$LATEST_LOG" 2>/dev/null) bytes)"
    echo "Last 30 lines:"
    cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | tail -30
else
    echo "No EA logs found"
fi
echo ""

echo "--- Terminal Logs ---"
TERM_LOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "File: $(basename "$TERM_LOG") ($(stat -c%s "$TERM_LOG" 2>/dev/null) bytes)"
    echo "Last 20 lines:"
    cat "$TERM_LOG" 2>/dev/null | tr -d '\0' | tail -20
else
    echo "No terminal logs found"
fi
echo ""

# ============ 5: EA FILES ============
echo "=== [5] EA FILES ==="
echo "--- Experts dir ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/" 2>/dev/null || echo "EA directory not found!"
echo ""
echo "--- Config files ---"
ls -la "$MT5/MQL5/Files/PropFirmBot/" 2>/dev/null || echo "Config directory not found!"
echo ""

# ============ 6: NETWORK ============
echo "=== [6] NETWORK ==="
echo "--- Outbound connections ---"
ss -tn state established 2>/dev/null | head -10 || netstat -tn 2>/dev/null | head -10
echo ""

# ============ 7: SYSTEM ============
echo "=== [7] SYSTEM ==="
echo "Uptime: $(uptime -p 2>/dev/null)"
echo "Memory: $(free -h | grep Mem)"
echo "Disk:   $(df -h / | tail -1)"
echo "Kernel: $(uname -r)"
echo ""

echo "=== CHECK DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
