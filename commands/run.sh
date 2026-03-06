#!/bin/bash
# =============================================================
# Deep diagnostic #2 - Read logs properly + status.json
# =============================================================

echo "============================================"
echo "  DIAGNOSTIC #2 - Logs & Status"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Read status.json (EA writes this)
echo "=== [1] status.json (EA live status) ==="
cat "$MT5_BASE/MQL5/Files/PropFirmBot/status.json" 2>/dev/null
echo ""
echo ""

# 2. Read telegram queue (shows EA activity)
echo "=== [2] Telegram Queue (last 30 lines) ==="
tail -30 "$MT5_BASE/MQL5/Files/PropFirmBot/telegram_queue.txt" 2>/dev/null
echo ""

# 3. EA log - read with tr to remove null bytes instead of strings
echo "=== [3] EA Log Today (last 100 lines) ==="
TODAY=$(date '+%Y%m%d')
EA_LOG="$MT5_BASE/MQL5/Logs/${TODAY}.log"
if [ -f "$EA_LOG" ]; then
    echo "File: $EA_LOG ($(wc -l < "$EA_LOG") lines)"
    tail -100 "$EA_LOG" | tr -d '\0'
else
    echo "No EA log for today"
    LATEST=$(ls -t "$MT5_BASE/MQL5/Logs/"*.log 2>/dev/null | head -1)
    echo "Latest: $LATEST"
    tail -100 "$LATEST" 2>/dev/null | tr -d '\0'
fi
echo ""

# 4. Terminal log - same fix
echo "=== [4] Terminal Log Today (last 50 lines) ==="
TERM_LOG="$MT5_BASE/logs/${TODAY}.log"
if [ -f "$TERM_LOG" ]; then
    echo "File: $TERM_LOG ($(wc -l < "$TERM_LOG") lines)"
    tail -50 "$TERM_LOG" | tr -d '\0'
else
    echo "No terminal log for today"
fi
echo ""

# 5. Check .ex5 vs .mq5 timestamps
echo "=== [5] Compiled vs Source Timestamps ==="
echo "Source (.mq5):"
ls -la "$MT5_BASE/MQL5/Experts/PropFirmBot/PropFirmBot.mq5" 2>/dev/null
echo "Compiled (.ex5):"
ls -la "$MT5_BASE/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null
echo ""
echo "⚠️  If .ex5 is OLDER than .mq5, the EA is running OLD code!"
echo ""

# 6. Check if AutoTrading is enabled
echo "=== [6] AutoTrading in common.ini ==="
find "$MT5_BASE" -name "*.ini" -exec grep -l -i "expert\|auto" {} \; 2>/dev/null
echo "---"
for INI in "$MT5_BASE/config/common.ini" "$MT5_BASE/config/terminal.ini" "$MT5_BASE/terminal64.ini"; do
    if [ -f "$INI" ]; then
        echo "Found: $INI"
        cat "$INI" | tr -d '\0' | head -30
        echo "---"
    fi
done
echo ""

# 7. Check what chart the EA is on
echo "=== [7] Chart profiles ==="
find "$MT5_BASE/Profiles" -name "*.chr" 2>/dev/null | head -10
CHART=$(find "$MT5_BASE/Profiles" -name "*.chr" 2>/dev/null | head -1)
if [ -n "$CHART" ]; then
    echo "First chart file content:"
    cat "$CHART" 2>/dev/null | tr -d '\0' | grep -i "expert\|symbol\|period\|autotrading" | head -20
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
