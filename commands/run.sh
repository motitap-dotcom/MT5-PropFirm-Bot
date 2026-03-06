#!/bin/bash
# =============================================================
# Full Bot Status Check - 2026-03-06
# =============================================================

echo "============================================"
echo "  Full Bot Status Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. MT5 process
echo "=== [1] MT5 Process ==="
ps aux | grep -i "terminal64\|metatrader\|mt5" | grep -v grep || echo "MT5 NOT RUNNING!"
echo ""

# 2. Wine processes
echo "=== [2] Wine Processes ==="
ps aux | grep -i wine | grep -v grep | head -10 || echo "No wine processes"
echo ""

# 3. VNC / Display
echo "=== [3] Display & VNC ==="
ps aux | grep -E "Xvfb|x11vnc|vnc" | grep -v grep || echo "No VNC/display"
echo ""

# 4. Account status from JSON
echo "=== [4] MT5 Status JSON ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
    echo ""
    echo "File age: $(( ($(date +%s) - $(stat -c %Y /var/bots/mt5_status.json)) )) seconds old"
else
    echo "STATUS FILE NOT FOUND!"
fi
echo ""

# 5. EA log (last 30 lines)
echo "=== [5] EA Log (last 30 lines) ==="
EA_LOG=$(find /root/.wine/drive_c/ -path "*/Logs/*" -name "*.log" -newer /root/.wine/drive_c/Program\ Files 2>/dev/null | head -1)
if [ -z "$EA_LOG" ]; then
    EA_LOG=$(find /root/.wine/drive_c/ -path "*/MQL5/Logs/*" -name "*.log" 2>/dev/null | sort -r | head -1)
fi
if [ -n "$EA_LOG" ]; then
    echo "Log file: $EA_LOG"
    tail -30 "$EA_LOG"
else
    echo "No EA log found, checking all MT5 logs..."
    find /root/.wine/drive_c/ -path "*MetaTrader*" -name "*.log" 2>/dev/null | head -10
    LATEST=$(find /root/.wine/drive_c/ -path "*MetaTrader*" -name "*.log" 2>/dev/null | sort -r | head -1)
    if [ -n "$LATEST" ]; then
        echo "--- Latest log: $LATEST ---"
        tail -30 "$LATEST"
    fi
fi
echo ""

# 6. Expert logs (MT5 Experts tab)
echo "=== [6] Expert Advisor Logs ==="
EXPERT_LOG=$(find /root/.wine/drive_c/ -path "*/MQL5/Logs/*" -name "$(date +%Y%m%d).log" 2>/dev/null | head -1)
if [ -z "$EXPERT_LOG" ]; then
    EXPERT_LOG=$(find /root/.wine/drive_c/ -path "*/MQL5/Logs/*" -name "*.log" 2>/dev/null | sort -r | head -1)
fi
if [ -n "$EXPERT_LOG" ]; then
    echo "Expert log: $EXPERT_LOG"
    tail -30 "$EXPERT_LOG"
else
    echo "No expert log found"
fi
echo ""

# 7. Disk & memory
echo "=== [7] System Resources ==="
echo "Disk:"
df -h / | tail -1
echo "Memory:"
free -m | head -2
echo "Uptime:"
uptime
echo ""

# 8. Recent trades from journal
echo "=== [8] Trade Journal ==="
JOURNAL=$(find /root/.wine/drive_c/ -path "*/tester/logs/*" -o -path "*/Logs/*" -name "*.log" 2>/dev/null | sort -r | head -3)
for f in $JOURNAL; do
    if grep -qi "order\|deal\|trade\|buy\|sell" "$f" 2>/dev/null; then
        echo "--- $f ---"
        grep -i "order\|deal\|trade\|buy\|sell" "$f" | tail -10
    fi
done
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
