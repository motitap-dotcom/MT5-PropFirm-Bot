#!/bin/bash
# =============================================================
# VPS Command Runner
# Edit this file and push to run commands on VPS
# Output will appear in commands/output.txt after ~60 seconds
# =============================================================

echo "=== VPS Status Check - $(date) ==="
echo ""

# MT5 Process
echo "--- MT5 Process ---"
pgrep -a terminal64 || echo "MT5 NOT running!"
echo ""

# Account connection
echo "--- MT5 Logs (last 20 lines) ---"
MT5_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
if [ -d "$MT5_LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -f "$LATEST_LOG" ]; then
        tail -20 "$LATEST_LOG"
    else
        echo "No log files found"
    fi
else
    echo "Log directory not found"
fi
echo ""

# EA Status
echo "--- EA Files ---"
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/" 2>/dev/null || echo "EA directory not found"
echo ""

# System resources
echo "--- System ---"
echo "Uptime: $(uptime)"
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo ""

echo "=== Done ==="
