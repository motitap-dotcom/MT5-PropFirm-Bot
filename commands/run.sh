#!/bin/bash
# =============================================================
# Full VPS & Bot Status Check
# =============================================================

echo "============================================"
echo "  Full VPS Status Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. Is MT5 running?
echo "=== [1] MT5 Process ==="
ps aux | grep -i "terminal64\|metatrader" | grep -v grep || echo "MT5 NOT RUNNING!"
echo ""

# 2. Wine/display
echo "=== [2] Display & VNC ==="
ps aux | grep -i "xvfb\|x11vnc" | grep -v grep || echo "No display/VNC"
echo ""

# 3. Account status from status file
echo "=== [3] Bot Status File ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null
else
    echo "Status file NOT FOUND"
fi
echo ""

# 4. Latest EA log
echo "=== [4] Latest EA Log (last 30 lines) ==="
EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
if [ -d "$EA_LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "File: $LATEST_LOG"
        tail -30 "$LATEST_LOG"
    else
        echo "No EA log files found"
    fi
else
    echo "EA log dir not found"
fi
echo ""

# 5. MT5 terminal log
echo "=== [5] MT5 Terminal Log (last 20 lines) ==="
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
if [ -d "$TERM_LOG_DIR" ]; then
    LATEST_TLOG=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_TLOG" ]; then
        echo "File: $LATEST_TLOG"
        tail -20 "$LATEST_TLOG"
    else
        echo "No terminal log files found"
    fi
else
    echo "Terminal log dir not found"
fi
echo ""

# 6. Current repo state on VPS
echo "=== [6] Repo on VPS ==="
cd /root/MT5-PropFirm-Bot 2>/dev/null && git log --oneline -3 && echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
echo ""

# 7. EA compiled file
echo "=== [7] EA Files ==="
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
ls -la "$EA_DIR"/*.ex5 2>/dev/null || echo "No compiled EA found!"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
