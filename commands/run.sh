#!/bin/bash
# =============================================================
# Deep diagnostic check - March 6, 2026
# Why is the bot not trading?
# =============================================================

echo "============================================"
echo "  DEEP DIAGNOSTIC CHECK"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Is MT5 running?
echo "=== [1] MT5 Process ==="
if pgrep -f terminal64.exe > /dev/null; then
    PID=$(pgrep -f terminal64.exe | head -1)
    echo "MT5 is RUNNING (PID: $PID)"
    echo "Uptime: $(ps -p $PID -o etime= 2>/dev/null)"
else
    echo "MT5 is NOT running!"
fi
echo ""

# 2. Check Wine & display
echo "=== [2] Wine & Display ==="
echo "DISPLAY=$DISPLAY"
ps aux | grep -E "Xvfb|x11vnc" | grep -v grep
echo ""

# 3. Network connectivity - can MT5 reach broker?
echo "=== [3] Network (broker connectivity) ==="
ping -c 2 -W 3 google.com 2>&1 | tail -2
echo ""

# 4. Terminal log - last 30 lines
echo "=== [4] Terminal Log (today + yesterday) ==="
TODAY=$(date '+%Y%m%d')
YESTERDAY=$(date -d '-1 day' '+%Y%m%d')
TERM_LOG="$MT5_BASE/logs/${TODAY}.log"
TERM_LOG_Y="$MT5_BASE/logs/${YESTERDAY}.log"
if [ -f "$TERM_LOG" ]; then
    echo "Today's log ($TERM_LOG):"
    tail -30 "$TERM_LOG" 2>/dev/null | strings | grep -v "^$"
elif [ -f "$TERM_LOG_Y" ]; then
    echo "No today log. Yesterday's log:"
    tail -30 "$TERM_LOG_Y" 2>/dev/null | strings | grep -v "^$"
else
    echo "No recent terminal logs found. Available:"
    ls -lt "$MT5_BASE/logs/"*.log 2>/dev/null | head -5
fi
echo ""

# 5. EA Expert log - ALL of today + last of yesterday
echo "=== [5] EA Logs ==="
EA_LOG="$MT5_BASE/MQL5/Logs/${TODAY}.log"
EA_LOG_Y="$MT5_BASE/MQL5/Logs/${YESTERDAY}.log"
if [ -f "$EA_LOG" ]; then
    LINE_COUNT=$(wc -l < "$EA_LOG")
    echo "Today's EA log ($LINE_COUNT lines):"
    tail -100 "$EA_LOG" 2>/dev/null | strings | grep -v "^$"
else
    echo "No EA log for today."
fi
echo ""
if [ -f "$EA_LOG_Y" ]; then
    echo "Yesterday's EA log (last 50 lines):"
    tail -50 "$EA_LOG_Y" 2>/dev/null | strings | grep -v "^$"
fi
echo ""

# 6. Check if EA is actually loaded (look for EA init messages)
echo "=== [6] EA Init/Load Messages ==="
for LOG in "$MT5_BASE/MQL5/Logs/"*.log; do
    grep -l "PropFirmBot\|Init\|GUARDIAN\|HEARTBEAT" "$LOG" 2>/dev/null
done | tail -5
echo "---"
LATEST_LOG=$(ls -t "$MT5_BASE/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Latest EA log: $LATEST_LOG"
    grep -i "init\|deinit\|error\|fail\|PropFirmBot\|loaded\|attach" "$LATEST_LOG" 2>/dev/null | strings | tail -20
fi
echo ""

# 7. Check for BLOCKED messages (why trades are rejected)
echo "=== [7] BLOCKED / Rejected Trades ==="
if [ -n "$LATEST_LOG" ]; then
    grep -i "BLOCKED\|reject\|not allowed\|invalid\|failed\|error" "$LATEST_LOG" 2>/dev/null | strings | tail -30
fi
echo ""

# 8. Check signal generation
echo "=== [8] Signal Generation ==="
if [ -n "$LATEST_LOG" ]; then
    grep -i "signal\|SCORE\|trend\|entry\|momentum\|RSI\|MACD" "$LATEST_LOG" 2>/dev/null | strings | tail -30
fi
echo ""

# 9. Check HEARTBEAT messages
echo "=== [9] HEARTBEAT Messages ==="
if [ -n "$LATEST_LOG" ]; then
    grep -i "HEARTBEAT\|heartbeat" "$LATEST_LOG" 2>/dev/null | strings | tail -10
fi
echo ""

# 10. EA compiled files check
echo "=== [10] EA Compiled Files ==="
echo "Source files (.mqh/.mq5):"
ls -la "$MT5_BASE/MQL5/Experts/PropFirmBot/"*.mq* 2>/dev/null
echo ""
echo "Compiled file (.ex5):"
ls -la "$MT5_BASE/MQL5/Experts/PropFirmBot/"*.ex5 2>/dev/null
echo ""

# 11. Config files
echo "=== [11] Config Files ==="
ls -la "$MT5_BASE/MQL5/Files/PropFirmBot/" 2>/dev/null
echo ""

# 12. AutoTrading status from terminal.ini
echo "=== [12] AutoTrading Config ==="
TERMINAL_INI="$MT5_BASE/config/terminal.ini"
if [ -f "$TERMINAL_INI" ]; then
    grep -i "auto\|expert\|allow" "$TERMINAL_INI" 2>/dev/null | strings
else
    echo "terminal.ini not found at $TERMINAL_INI"
    find "$MT5_BASE" -name "terminal*.ini" 2>/dev/null | head -5
fi
echo ""

# 13. Account info from logs
echo "=== [13] Account Info from Logs ==="
for LOG in $(ls -t "$MT5_BASE/MQL5/Logs/"*.log 2>/dev/null | head -3); do
    echo "--- $(basename $LOG) ---"
    grep -i "account\|balance\|equity\|margin\|login\|connect\|authorized" "$LOG" 2>/dev/null | strings | tail -10
done
echo ""

# 14. Check disk space & memory
echo "=== [14] System Resources ==="
df -h / | tail -1
free -m | head -2
echo ""

echo "============================================"
echo "  DONE $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
