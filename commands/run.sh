#!/bin/bash
# =============================================================
# Verify bot is running and trading after deploy
# =============================================================

echo "============================================"
echo "  Post-Deploy Verification"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. MT5 process
echo "=== [1] MT5 Running? ==="
if pgrep -f terminal64.exe > /dev/null; then
    echo "YES - MT5 is running"
    ps aux | grep terminal64.exe | grep -v grep | head -1
else
    echo "NO - MT5 is NOT running!"
fi
echo ""

# 2. Bot status
echo "=== [2] Bot Status ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null
else
    echo "Status file not found"
fi
echo ""

# 3. EA log - last 50 lines to see activity after restart
echo "=== [3] EA Log (last 50 lines) ==="
EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $LATEST_LOG"
    tail -50 "$LATEST_LOG" | strings
else
    echo "No EA log found"
fi
echo ""

# 4. Check .ex5 compile date
echo "=== [4] EA Compiled File ==="
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
ls -la "$EA_DIR"/PropFirmBot.ex5 2>/dev/null
echo ""
echo "Source files (for comparison):"
ls -la "$EA_DIR"/PropFirmBot.mq5 2>/dev/null
ls -la "$EA_DIR"/SignalEngine.mqh 2>/dev/null
echo ""

# 5. Trade history today
echo "=== [5] Account Journal (last 30 lines) ==="
JOURNAL_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
LATEST_JLOG=$(ls -t "$JOURNAL_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_JLOG" ]; then
    echo "File: $LATEST_JLOG"
    tail -30 "$LATEST_JLOG" | strings
else
    echo "No journal log found"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
