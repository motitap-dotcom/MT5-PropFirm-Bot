#!/bin/bash
# Verify EA loaded after restart
echo "=== POST-DEPLOY CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

export DISPLAY=:99
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. MT5 running?
echo "[1] MT5 Process:"
pgrep -af terminal64 2>/dev/null || echo "NOT RUNNING!"

# 2. EA version in source
echo ""
echo "[2] EA Version (source):"
grep "property version" "$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.mq5" 2>/dev/null

# 3. Compiled file
echo ""
echo "[3] Compiled EA (.ex5):"
ls -la "$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

# 4. EA Logs - check if it loaded
echo ""
echo "[4] EA Log (today):"
LOG_FILE="$MT5_DIR/MQL5/Logs/$(date '+%Y%m%d').log"
if [ -f "$LOG_FILE" ]; then
    echo "Size: $(stat -c %s "$LOG_FILE") bytes"
    tail -30 "$LOG_FILE" | strings | sed 's/\x00//g'
else
    echo "No EA log for today"
fi

# 5. Terminal log
echo ""
echo "[5] Terminal Journal (today):"
TERM_LOG="$MT5_DIR/logs/$(date '+%Y%m%d').log"
if [ -f "$TERM_LOG" ]; then
    tail -20 "$TERM_LOG" | strings | sed 's/\x00//g'
else
    echo "No terminal log"
fi

# 6. Status JSON
echo ""
echo "[6] Bot Status:"
STATUS_FILE="$MT5_DIR/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
else
    echo "No status file yet"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
