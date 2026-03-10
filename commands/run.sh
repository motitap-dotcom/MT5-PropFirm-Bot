#!/bin/bash
# =============================================================
# FULL STATUS CHECK - March 10, 2026
# Comprehensive check: MT5, EA, compilation, trading status
# =============================================================

echo "============================================"
echo "  FULL VPS STATUS CHECK"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. Is MT5 running?
echo "=== [1] MT5 Process ==="
MT5_PROCS=$(pgrep -af -i "terminal64\|metatrader\|mt5" 2>/dev/null)
if [ -n "$MT5_PROCS" ]; then
    echo "MT5 IS RUNNING:"
    echo "$MT5_PROCS"
else
    echo "WARNING: MT5 IS NOT RUNNING!"
fi
echo ""

# 2. Wine processes
echo "=== [2] Wine/Display ==="
pgrep -af wine 2>/dev/null | head -5
echo "DISPLAY=$DISPLAY"
xdpyinfo -display :99 2>/dev/null | head -3 || echo "Display :99 not available"
echo ""

# 3. EA files on VPS - check dates and sizes
echo "=== [3] EA Files on VPS ==="
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    ls -la "$EA_DIR/" 2>/dev/null
else
    echo "EA directory NOT FOUND at: $EA_DIR"
    find /root/.wine -name "PropFirmBot*" -type d 2>/dev/null | head -5
fi
echo ""

# 4. Compiled EA (.ex5)
echo "=== [4] Compiled EA (.ex5) ==="
find /root/.wine -name "PropFirmBot.ex5" 2>/dev/null -exec ls -la {} \;
if [ $? -ne 0 ] || [ -z "$(find /root/.wine -name 'PropFirmBot.ex5' 2>/dev/null)" ]; then
    echo "WARNING: No compiled .ex5 file found!"
fi
echo ""

# 5. Config files
echo "=== [5] Config Files ==="
CONFIG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"
if [ -d "$CONFIG_DIR" ]; then
    ls -la "$CONFIG_DIR/" 2>/dev/null
else
    echo "Config directory NOT FOUND"
fi
echo ""

# 6. MT5 logs (last 20 lines)
echo "=== [6] MT5 Recent Logs ==="
LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Latest log: $LATEST_LOG"
    tail -20 "$LATEST_LOG"
else
    echo "No logs found in $LOG_DIR"
    # Try alternative log location
    ALT_LOG="/root/.wine/drive_c/Program Files/MetaTrader 5/logs"
    LATEST_ALT=$(ls -t "$ALT_LOG"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_ALT" ]; then
        echo "Found log at: $LATEST_ALT"
        tail -20 "$LATEST_ALT"
    fi
fi
echo ""

# 7. Account status from json
echo "=== [7] Bot Status JSON ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null
else
    echo "Status JSON not found at /var/bots/mt5_status.json"
fi
echo ""

# 8. Repo state on VPS
echo "=== [8] Repo on VPS ==="
cd /root/MT5-PropFirm-Bot 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "Last commit: $(git log --oneline -1 2>/dev/null)"
    echo "Last pull: $(stat -c '%y' .git/FETCH_HEAD 2>/dev/null || echo 'unknown')"
else
    echo "Repo not found at /root/MT5-PropFirm-Bot"
fi
echo ""

# 9. System resources
echo "=== [9] System Resources ==="
echo "Uptime: $(uptime)"
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo ""

# 10. Network - can MT5 reach broker?
echo "=== [10] Network Check ==="
ping -c 1 -W 3 google.com > /dev/null 2>&1 && echo "Internet: OK" || echo "Internet: FAILED"
echo ""

echo "============================================"
echo "  CHECK COMPLETE: $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
