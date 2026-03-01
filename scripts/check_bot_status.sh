#!/bin/bash
# Bot Status Check - Full diagnostic report
# This runs on the VPS and collects all bot information

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
LOG_DIR="$MT5_DIR/MQL5/Logs"
TERM_LOG_DIR="$MT5_DIR/logs"
FILES_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"

echo "╔══════════════════════════════════════════════╗"
echo "║     PropFirmBot Status Report                ║"
echo "║     $(date '+%Y-%m-%d %H:%M:%S UTC')              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# 1. MT5 Process
echo "=== MT5 PROCESS ==="
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "STATUS: ✅ MT5 IS RUNNING"
    ps aux | grep terminal64 | grep -v grep | awk '{printf "  PID: %s | CPU: %s%% | MEM: %s%% | Uptime: %s\n", $2, $3, $4, $10}'
else
    echo "STATUS: ❌ MT5 IS NOT RUNNING"
fi
echo ""

# 2. VNC
echo "=== VNC ==="
if pgrep -f x11vnc > /dev/null 2>&1; then
    echo "STATUS: ✅ VNC RUNNING (port 5900)"
else
    echo "STATUS: ❌ VNC NOT RUNNING"
fi
if pgrep -f Xvfb > /dev/null 2>&1; then
    echo "Xvfb: ✅ Running"
else
    echo "Xvfb: ❌ Not running"
fi
echo ""

# 3. EA Files
echo "=== EA FILES ==="
if [ -d "$EA_DIR" ]; then
    echo "EA Directory: ✅ EXISTS"
    echo "Files:"
    ls -la "$EA_DIR/" 2>/dev/null | grep -E "\.(mq5|mqh|ex5)" | awk '{printf "  %s (%s bytes, %s %s)\n", $9, $5, $6, $7}'
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        echo "Compiled EA: ✅ PropFirmBot.ex5 exists"
        stat -c "  Size: %s bytes, Modified: %y" "$EA_DIR/PropFirmBot.ex5"
    else
        echo "Compiled EA: ❌ PropFirmBot.ex5 NOT FOUND"
    fi
else
    echo "EA Directory: ❌ NOT FOUND"
fi
echo ""

# 4. Config Files
echo "=== CONFIG FILES ==="
if [ -d "$FILES_DIR" ]; then
    echo "Config Directory: ✅ EXISTS"
    ls -la "$FILES_DIR/" 2>/dev/null | grep -E "\.json" | awk '{printf "  %s (%s bytes)\n", $9, $5}'
else
    echo "Config Directory: ❌ NOT FOUND"
fi
echo ""

# 5. Network Connections (MT5 to broker)
echo "=== NETWORK CONNECTIONS ==="
echo "Outbound connections (non-SSH/VNC):"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10
if ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | grep -q .; then
    echo "Broker connection: ✅ LIKELY CONNECTED"
else
    echo "Broker connection: ⚠️ NO OUTBOUND CONNECTIONS DETECTED"
fi
echo ""

# 6. Terminal Logs (latest)
echo "=== MT5 TERMINAL LOG (latest) ==="
LATEST_TERM_LOG=$(find "$TERM_LOG_DIR" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
if [ -n "$LATEST_TERM_LOG" ]; then
    echo "File: $LATEST_TERM_LOG"
    echo "Size: $(stat -c%s "$LATEST_TERM_LOG" 2>/dev/null) bytes"
    echo "--- Last 25 lines ---"
    cat "$LATEST_TERM_LOG" 2>/dev/null | tr -d '\0' | tail -25
else
    echo "No terminal logs found"
fi
echo ""

# 7. EA Logs (latest)
echo "=== EA LOG (latest) ==="
LATEST_EA_LOG=$(find "$LOG_DIR" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
if [ -n "$LATEST_EA_LOG" ]; then
    echo "File: $LATEST_EA_LOG"
    echo "Size: $(stat -c%s "$LATEST_EA_LOG" 2>/dev/null) bytes"
    echo "--- Last 30 lines ---"
    cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | tail -30
else
    echo "No EA logs found"
fi
echo ""

# 8. Status JSON (if exists)
echo "=== STATUS JSON ==="
if [ -f "$FILES_DIR/status.json" ]; then
    echo "✅ status.json exists"
    cat "$FILES_DIR/status.json" 2>/dev/null | tr -d '\0'
else
    echo "No status.json found"
fi
echo ""

# 9. System Resources
echo "=== SYSTEM RESOURCES ==="
echo "Disk: $(df -h / | tail -1 | awk '{print $3 " used / " $2 " total (" $5 " used)"}')"
echo "Memory: $(free -h | grep Mem | awk '{print $3 " used / " $2 " total"}')"
echo "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Uptime: $(uptime -p)"
echo ""

# 10. Watchdog/Cron
echo "=== WATCHDOG/CRON ==="
crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" || echo "No crontab entries"
echo ""

echo "╔══════════════════════════════════════════════╗"
echo "║     END OF REPORT                            ║"
echo "╚══════════════════════════════════════════════╝"
