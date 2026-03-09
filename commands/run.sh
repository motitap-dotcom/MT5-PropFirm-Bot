#!/bin/bash
# =============================================================
# Full Bot Status Check - Is the bot active and trading?
# =============================================================

echo "============================================"
echo "  Bot Status Check - Active & Trading?"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. Check if MT5 process is running
echo "=== [1] MT5 Process ==="
if pgrep -f "terminal64.exe" > /dev/null 2>&1; then
    echo "✅ MT5 is RUNNING"
    ps aux | grep -i terminal64 | grep -v grep
else
    echo "❌ MT5 is NOT running!"
fi
echo ""

# 2. Check MT5 logs for recent activity
echo "=== [2] MT5 Recent Logs (last 30 lines) ==="
MT5_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    tail -30 "$LATEST_LOG"
else
    echo "No log files found"
fi
echo ""

# 3. Check EA Experts logs
echo "=== [3] EA Expert Logs (last 30 lines) ==="
EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
EXPERT_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$EXPERT_LOG" ]; then
    tail -30 "$EXPERT_LOG"
fi
# Also check terminal logs
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
LATEST_TERM_LOG=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM_LOG" ]; then
    echo ""
    echo "--- Terminal Log (last 20 lines): ---"
    echo "Log file: $LATEST_TERM_LOG"
    tail -20 "$LATEST_TERM_LOG"
fi
echo ""

# 4. Check trade history / journal
echo "=== [4] Trade Journal ==="
JOURNAL_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"
if [ -d "$JOURNAL_DIR" ]; then
    echo "Files in PropFirmBot directory:"
    ls -la "$JOURNAL_DIR/" 2>/dev/null
    echo ""
    # Show trade journal if exists
    for f in "$JOURNAL_DIR"/*trade* "$JOURNAL_DIR"/*journal* "$JOURNAL_DIR"/*log*; do
        if [ -f "$f" ]; then
            echo "--- $(basename "$f") (last 20 lines) ---"
            tail -20 "$f"
            echo ""
        fi
    done
fi
echo ""

# 5. Check account status file
echo "=== [5] Account/Status Files ==="
for f in "$JOURNAL_DIR"/*.json "$JOURNAL_DIR"/*.txt "$JOURNAL_DIR"/*.csv; do
    if [ -f "$f" ]; then
        echo "--- $(basename "$f") ---"
        cat "$f" 2>/dev/null | head -50
        echo ""
    fi
done
echo ""

# 6. Status daemon
echo "=== [6] Status Daemon ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
else
    echo "No status daemon file found"
fi
echo ""

# 7. VNC and Wine status
echo "=== [7] VNC & Wine ==="
pgrep -a Xvfb 2>/dev/null && echo "✅ Xvfb running" || echo "❌ Xvfb not running"
pgrep -a x11vnc 2>/dev/null && echo "✅ VNC running" || echo "❌ VNC not running"
echo ""

echo "=== CHECK COMPLETE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
