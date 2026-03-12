#!/bin/bash
# Fresh status check - why bot not trading?
echo "=== BOT STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
TERM_LOG_DIR="${MT5_BASE}/logs"

# 1. MT5 process
echo "--- MT5 Process ---"
ps aux | grep -i terminal64 | grep -v grep

# 2. Status.json
echo ""
echo "--- status.json ---"
if [ -f "$EA_FILES_DIR/status.json" ]; then
    cat "$EA_FILES_DIR/status.json"
else
    echo "status.json NOT FOUND"
fi

# 3. Account connection
echo ""
echo "--- Connection Check ---"
ss -tnp | grep -i terminal

# 4. Latest terminal log (last 50 lines)
echo ""
echo "--- Terminal Log (last 50 lines) ---"
TERM_LATEST=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LATEST" ]; then
    echo "File: $TERM_LATEST"
    tail -50 "$TERM_LATEST"
fi

# 5. Latest EA log (last 100 lines)
echo ""
echo "--- EA Log (last 100 lines) ---"
EA_LATEST=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    echo "File: $EA_LATEST"
    tail -100 "$EA_LATEST"
fi

# 6. Check for errors in EA log
echo ""
echo "--- Errors/Warnings in EA Log ---"
if [ -n "$EA_LATEST" ]; then
    grep -i -E "error|fail|invalid|block|halt|emergency|shutdown|disabled|cannot" "$EA_LATEST" | tail -30
fi

# 7. Guardian state entries
echo ""
echo "--- Guardian State Entries ---"
if [ -n "$EA_LATEST" ]; then
    grep -i -E "guardian|state|halted|caution|active|can_trade" "$EA_LATEST" | tail -20
fi

# 8. Signal entries
echo ""
echo "--- Signal/Trade Entries ---"
if [ -n "$EA_LATEST" ]; then
    grep -i -E "signal|trade|order|buy|sell|position|session|spread|risk" "$EA_LATEST" | tail -30
fi

# 9. Config files on VPS
echo ""
echo "--- Config Files ---"
for f in "$EA_FILES_DIR"/*.json; do
    if [ -f "$f" ] && [ "$(basename "$f")" != "status.json" ]; then
        echo "=== $(basename "$f") ==="
        cat "$f"
        echo ""
    fi
done

# 10. AutoTrading enabled?
echo ""
echo "--- AutoTrading Check ---"
if [ -n "$TERM_LATEST" ]; then
    grep -i "automated trading" "$TERM_LATEST" | tail -5
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
