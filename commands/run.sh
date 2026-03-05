#!/bin/bash
# =============================================================
# VPS Full Status Check - Verify EA Parameters & Trading Status
# =============================================================

echo "=== VPS Full Status Check - $(date) ==="
echo ""

# 1. MT5 Process
echo "--- MT5 Process ---"
pgrep -a terminal64 || echo "MT5 NOT running!"
pgrep -a metatrader || echo ""
echo ""

# 2. VNC Status
echo "--- VNC Status ---"
pgrep -a x11vnc || echo "x11vnc NOT running!"
pgrep -a Xvfb || echo "Xvfb NOT running!"
echo ""

# 3. EA Files - check compiled .ex5 exists
echo "--- EA Files (Compiled) ---"
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    ls -la "$EA_DIR"/*.ex5 2>/dev/null || echo "No compiled .ex5 files found!"
    echo ""
    echo "All EA files:"
    ls -la "$EA_DIR"/ 2>/dev/null
else
    echo "EA directory not found!"
fi
echo ""

# 4. Config files
echo "--- Config Files ---"
CONFIG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"
if [ -d "$CONFIG_DIR" ]; then
    ls -la "$CONFIG_DIR"/ 2>/dev/null
    echo ""
    echo "--- Account Config Content ---"
    cat "$CONFIG_DIR/account_config.json" 2>/dev/null || echo "No account_config.json"
    echo ""
    echo "--- Risk Config Content ---"
    cat "$CONFIG_DIR/risk_config.json" 2>/dev/null || echo "No risk_config.json"
else
    echo "Config directory not found!"
fi
echo ""

# 5. MT5 Logs - last entries to see EA activity
echo "--- MT5 Terminal Logs (last 30 lines) ---"
MT5_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
if [ -d "$MT5_LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -f "$LATEST_LOG" ]; then
        echo "Log file: $LATEST_LOG"
        tail -30 "$LATEST_LOG"
    else
        echo "No log files found"
    fi
else
    echo "MQL5 Log directory not found"
fi
echo ""

# 6. MT5 main logs
echo "--- MT5 Main Logs (last 30 lines) ---"
MT5_MAIN_LOG="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
if [ -d "$MT5_MAIN_LOG" ]; then
    LATEST_MAIN=$(ls -t "$MT5_MAIN_LOG"/*.log 2>/dev/null | head -1)
    if [ -f "$LATEST_MAIN" ]; then
        echo "Log file: $LATEST_MAIN"
        tail -30 "$LATEST_MAIN"
    else
        echo "No main log files found"
    fi
else
    echo "Main log directory not found"
fi
echo ""

# 7. Check for XAUUSD chart
echo "--- Looking for XAUUSD references in logs ---"
if [ -f "$LATEST_LOG" ]; then
    grep -i "xauusd\|gold\|xau" "$LATEST_LOG" | tail -10 || echo "No XAUUSD references in EA logs"
fi
if [ -f "$LATEST_MAIN" ]; then
    grep -i "xauusd\|gold\|xau" "$LATEST_MAIN" | tail -10 || echo "No XAUUSD references in main logs"
fi
echo ""

# 8. Check EA initialization/parameters in logs
echo "--- EA Initialization & Parameters in Logs ---"
if [ -f "$LATEST_LOG" ]; then
    grep -i "init\|param\|input\|risk\|trail\|spread\|propfirmbot\|loaded\|start" "$LATEST_LOG" | tail -20 || echo "No init references found"
fi
echo ""

# 9. System resources
echo "--- System ---"
echo "Uptime: $(uptime)"
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo ""

# 10. Network / MT5 connection
echo "--- Network Connections (MT5) ---"
ss -tnp | grep -i "terminal\|wine\|metatrader" | head -10 || echo "No MT5 network connections found"
echo ""

echo "=== Done ==="
