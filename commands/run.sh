#!/bin/bash
# =============================================================
# BOT STATUS CHECK - Full Report
# =============================================================

echo "============================================"
echo "  BOT STATUS REPORT"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. MT5 Process
echo "=== MT5 PROCESS ==="
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "STATUS: RUNNING (PID: $MT5_PID)"
    echo "Uptime: $(ps -o etime= -p $MT5_PID 2>/dev/null || echo 'N/A')"
    echo "Memory: $(ps -o rss= -p $MT5_PID 2>/dev/null | awk '{printf "%.0f MB", $1/1024}' || echo 'N/A')"
    echo "CPU: $(ps -o %cpu= -p $MT5_PID 2>/dev/null || echo 'N/A')%"
else
    echo "STATUS: NOT RUNNING!"
fi
echo ""

# 2. Display / VNC
echo "=== DISPLAY & VNC ==="
if pgrep -f Xvfb > /dev/null 2>&1; then
    echo "Xvfb: RUNNING"
else
    echo "Xvfb: NOT RUNNING"
fi
if pgrep -f x11vnc > /dev/null 2>&1; then
    echo "VNC: RUNNING"
else
    echo "VNC: NOT RUNNING"
fi
echo ""

# 3. Wine processes
echo "=== WINE PROCESSES ==="
ps aux | grep -i wine | grep -v grep || echo "No wine processes"
echo ""

# 4. EA Files
echo "=== EA FILES ==="
MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    echo "EA Directory exists"
    echo "Compiled EA (.ex5):"
    ls -la "$EA_DIR/PropFirmBot.ex5" 2>&1
    echo ""
    echo "Source files count: $(ls "$EA_DIR"/*.mq* 2>/dev/null | wc -l)"
else
    echo "EA Directory NOT FOUND!"
fi
echo ""

# 5. MT5 Logs (last 30 lines)
echo "=== MT5 LOGS (last 30 lines) ==="
MT5_LOG_DIR="${MT5_BASE}/logs"
LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $(basename $LATEST_LOG)"
    tail -30 "$LATEST_LOG" 2>&1
else
    echo "No MT5 logs found"
fi
echo ""

# 6. EA Logs (Expert Advisors logs)
echo "=== EA LOGS (last 20 lines) ==="
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
LATEST_EA_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA_LOG" ]; then
    echo "EA Log file: $(basename $LATEST_EA_LOG)"
    tail -20 "$LATEST_EA_LOG" 2>&1
else
    echo "No EA logs found"
fi
echo ""

# 7. System Resources
echo "=== SYSTEM RESOURCES ==="
echo "Disk: $(df -h / | tail -1 | awk '{print $3 " used / " $2 " total (" $5 " used)"}')"
echo "RAM: $(free -m | awk '/Mem:/ {printf "%sMB used / %sMB total (%.0f%%)", $3, $2, $3/$2*100}')"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Server uptime: $(uptime -p)"
echo ""

# 8. Network connectivity
echo "=== NETWORK ==="
ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1 && echo "Internet: OK" || echo "Internet: DOWN"
echo ""

echo "============================================"
echo "  END OF STATUS REPORT"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
