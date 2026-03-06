#!/bin/bash
# =============================================================
# Full diagnostic: Why is the bot NOT trading?
# =============================================================

echo "============================================"
echo "  BOT NOT TRADING - FULL DIAGNOSTIC"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. Is MT5 process running?
echo "=== [1] MT5 Process ==="
ps aux | grep -i "terminal64\|metatrader\|terminal.exe" | grep -v grep
if [ $? -ne 0 ]; then
    echo "*** MT5 IS NOT RUNNING! ***"
fi
echo ""

# 2. MT5 logs - last 100 lines
echo "=== [2] MT5 Terminal Logs (last 100 lines) ==="
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
LOG_DIR="$MT5_DIR/MQL5/Logs"
LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    tail -100 "$LATEST_LOG"
else
    echo "No log files found in $LOG_DIR"
    ls -la "$LOG_DIR" 2>/dev/null
fi
echo ""

# 3. EA Expert logs
echo "=== [3] EA Expert Logs (last 100 lines) ==="
EA_LOG_DIR="$MT5_DIR/MQL5/Logs"
EXPERT_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | grep -i expert | head -1)
if [ -n "$EXPERT_LOG" ]; then
    echo "Expert log: $EXPERT_LOG"
    tail -100 "$EXPERT_LOG"
fi
# Also check Experts subfolder
EXPERT_LOG_DIR2="$MT5_DIR/Logs"
if [ -d "$EXPERT_LOG_DIR2" ]; then
    echo "--- Logs from $EXPERT_LOG_DIR2 ---"
    LATEST_EXPERT=$(ls -t "$EXPERT_LOG_DIR2"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_EXPERT" ]; then
        echo "Log: $LATEST_EXPERT"
        tail -100 "$LATEST_EXPERT"
    fi
fi
echo ""

# 4. Check EA files exist and compiled
echo "=== [4] EA Files Check ==="
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
echo "EA source files:"
ls -la "$EA_DIR"/*.mq5 "$EA_DIR"/*.mqh 2>/dev/null
echo ""
echo "Compiled EA (.ex5):"
ls -la "$EA_DIR"/*.ex5 2>/dev/null
if [ $? -ne 0 ]; then
    echo "*** NO COMPILED .ex5 FILE FOUND! ***"
fi
echo ""

# 5. Config files
echo "=== [5] Config Files ==="
CONFIG_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
ls -la "$CONFIG_DIR"/ 2>/dev/null
echo ""

# 6. Check if AutoTrading is enabled (via Wine registry or ini)
echo "=== [6] MT5 Configuration ==="
INI_FILE="$MT5_DIR/terminal64.ini"
if [ -f "$INI_FILE" ]; then
    echo "--- terminal64.ini ---"
    cat "$INI_FILE" 2>/dev/null
else
    echo "No terminal64.ini found"
    # Try other ini files
    ls -la "$MT5_DIR"/*.ini 2>/dev/null
fi
echo ""

# 7. Check charts config for EA attachment
echo "=== [7] Chart Profiles (checking EA attached) ==="
PROFILE_DIR="$MT5_DIR/MQL5/Profiles"
if [ -d "$PROFILE_DIR" ]; then
    find "$PROFILE_DIR" -name "*.chr" -exec echo "--- {} ---" \; -exec grep -i "Expert\|PropFirm\|AutoTrading" {} \; 2>/dev/null
fi
# Also check default profile
DEFAULT_PROFILE="$MT5_DIR/Profiles"
if [ -d "$DEFAULT_PROFILE" ]; then
    find "$DEFAULT_PROFILE" -name "*.chr" -exec echo "--- {} ---" \; -exec grep -i "Expert\|PropFirm\|AutoTrading" {} \; 2>/dev/null
fi
echo ""

# 8. Network/Connection check
echo "=== [8] Network Check ==="
ping -c 2 -W 3 8.8.8.8 2>&1 | tail -3
echo ""

# 9. Wine errors
echo "=== [9] Wine Errors (last 50 lines from syslog/journal) ==="
journalctl -u mt5* --no-pager -n 50 2>/dev/null || echo "No mt5 service logs"
echo ""
grep -i "wine\|mt5\|metatrader" /var/log/syslog 2>/dev/null | tail -30
echo ""

# 10. Disk & Memory
echo "=== [10] System Resources ==="
echo "Disk:"
df -h / | tail -1
echo "Memory:"
free -h | head -2
echo "Uptime:"
uptime
echo ""

# 11. VNC / Display check
echo "=== [11] Display & VNC ==="
echo "DISPLAY=$DISPLAY"
ps aux | grep -i "xvfb\|x11vnc\|vnc" | grep -v grep
echo ""

# 12. Account journal (last trades)
echo "=== [12] Trade Journal / Account History ==="
JOURNAL_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
if [ -f "$JOURNAL_DIR/trade_journal.json" ]; then
    echo "--- trade_journal.json (last 50 lines) ---"
    tail -50 "$JOURNAL_DIR/trade_journal.json"
elif [ -f "$JOURNAL_DIR/trade_journal.csv" ]; then
    echo "--- trade_journal.csv (last 20 lines) ---"
    tail -20 "$JOURNAL_DIR/trade_journal.csv"
else
    echo "No trade journal found"
    ls -la "$JOURNAL_DIR"/ 2>/dev/null
fi
echo ""

# 13. Check MT5 trade history in terminal logs
echo "=== [13] Recent order/trade mentions in logs ==="
if [ -n "$LATEST_LOG" ]; then
    grep -i "order\|trade\|position\|signal\|error\|failed\|denied\|disabled" "$LATEST_LOG" 2>/dev/null | tail -50
fi
echo ""

echo "============================================"
echo "  DIAGNOSTIC COMPLETE $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
