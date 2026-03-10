#!/bin/bash
# =============================================================
# Full status check - Bot & Server - 2026-03-10
# =============================================================

echo "============================================"
echo "  Full Bot & Server Status Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. MT5 Process
echo "=== [1] MT5 Process ==="
ps aux | grep -i "terminal64\|metatrader" | grep -v grep || echo "MT5 NOT RUNNING!"
echo ""

# 2. Account connection
echo "=== [2] Network Connections (MT5) ==="
ss -tnp | grep -i wine || echo "No MT5 network connections found"
echo ""

# 3. Latest terminal log
echo "=== [3] Terminal Log (last 30 lines) ==="
TERM_LOG=$(ls -t /root/.wine/drive_c/Program\ Files/MetaTrader\ 5/Logs/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "File: $TERM_LOG"
    tail -30 "$TERM_LOG"
else
    echo "No terminal logs found"
fi
echo ""

# 4. EA Log (latest)
echo "=== [4] EA Log (last 30 lines) ==="
EA_LOG=$(ls -t /root/.wine/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Logs/*.log 2>/dev/null | head -1)
if [ -n "$EA_LOG" ]; then
    echo "File: $EA_LOG"
    tail -30 "$EA_LOG"
else
    echo "No EA logs found"
fi
echo ""

# 5. Status JSON
echo "=== [5] /var/bots/mt5_status.json ==="
python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || echo "(file not found or invalid)"
echo ""

# 6. EA files on VPS
echo "=== [6] EA Files ==="
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/" 2>/dev/null || echo "EA directory not found"
echo ""

# 7. Last deploy info
echo "=== [7] Git status on VPS ==="
cd /root/MT5-PropFirm-Bot 2>/dev/null && git log --oneline -5 && echo "" && git branch --show-current
echo ""

# 8. Disk & uptime
echo "=== [8] System Info ==="
echo "Uptime: $(uptime)"
echo "Disk: $(df -h / | tail -1)"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
