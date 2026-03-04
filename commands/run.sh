#!/bin/bash
# =============================================================
# Full trade history analysis (fixed paths) - 2026-03-04
# =============================================================

echo "=== Trade History Analysis - $(date) ==="

EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
FILES_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"

# 1. Current account state
echo ""
echo "========== ACCOUNT STATUS =========="
cat "$FILES_DIR/status.json" 2>/dev/null | strings

# 2. Config files
echo ""
echo "========== RISK PARAMS =========="
cat "$FILES_DIR/risk_params.json" 2>/dev/null | strings

echo ""
echo "========== ACCOUNT STATE =========="
cat "$FILES_DIR/account_state.json" 2>/dev/null | strings

# 3. All TRADE/ORDER entries from EA logs (quoting paths properly)
echo ""
echo "========== ALL TRADE ACTIONS (from EA logs) =========="
find "$EA_LOG_DIR" -name "*.log" -type f | sort -r | while read logfile; do
    TRADES=$(strings "$logfile" | grep -i "TRADE\|ORDER\|CLOSE\|OPEN.*BUY\|OPEN.*SELL\|TP.*HIT\|SL.*HIT\|JOURNAL")
    if [ -n "$TRADES" ]; then
        echo ""
        echo "--- $(basename "$logfile") ---"
        echo "$TRADES" | head -100
    fi
done

# 4. BLOCKED entries
echo ""
echo "========== BLOCKED TRADES =========="
find "$EA_LOG_DIR" -name "*.log" -type f | sort -r | head -3 | while read logfile; do
    BLOCKED=$(strings "$logfile" | grep -i "BLOCKED" | sort | uniq -c | sort -rn)
    if [ -n "$BLOCKED" ]; then
        echo ""
        echo "--- $(basename "$logfile") ---"
        echo "$BLOCKED"
    fi
done

# 5. HEARTBEAT entries (account snapshots)
echo ""
echo "========== HEARTBEAT SNAPSHOTS =========="
find "$EA_LOG_DIR" -name "*.log" -type f | sort -r | head -3 | while read logfile; do
    HB=$(strings "$logfile" | grep "HEARTBEAT")
    if [ -n "$HB" ]; then
        echo ""
        echo "--- $(basename "$logfile") ---"
        echo "$HB"
    fi
done

# 6. Terminal log - trade operations
echo ""
echo "========== TERMINAL DEALS =========="
find "$TERM_LOG_DIR" -name "*.log" -type f | sort -r | head -3 | while read logfile; do
    DEALS=$(strings "$logfile" | grep -i "deal\|order.*#\|position\|buy.*#\|sell.*#\|profit\|close.*#\|instant\|market")
    if [ -n "$DEALS" ]; then
        echo ""
        echo "--- $(basename "$logfile") ---"
        echo "$DEALS" | head -60
    fi
done

echo ""
echo "=== Done ==="
