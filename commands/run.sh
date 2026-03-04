#!/bin/bash
# =============================================================
# Full trade history analysis - 2026-03-04
# =============================================================

echo "=== Trade History Analysis - $(date) ==="

EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
FILES_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"

# 1. Current account state
echo ""
echo "========== ACCOUNT STATUS =========="
if [ -f "$FILES_DIR/status.json" ]; then
    cat "$FILES_DIR/status.json" | strings
fi

# 2. Trade journal (if exists)
echo ""
echo "========== TRADE JOURNAL =========="
if [ -f "$FILES_DIR/trade_journal.csv" ]; then
    echo "--- Trade Journal CSV ---"
    cat "$FILES_DIR/trade_journal.csv" | strings
elif [ -f "$FILES_DIR/trade_journal.json" ]; then
    echo "--- Trade Journal JSON ---"
    cat "$FILES_DIR/trade_journal.json" | strings
else
    echo "No trade journal file found"
    echo "Files in PropFirmBot directory:"
    ls -la "$FILES_DIR/" 2>/dev/null
fi

# 3. All TRADE/ORDER/CLOSE entries from EA logs
echo ""
echo "========== ALL TRADE ACTIONS (from EA logs) =========="
for logfile in $(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null); do
    TRADES=$(strings "$logfile" | grep -i "TRADE\|ORDER\|CLOSE\|OPEN.*BUY\|OPEN.*SELL\|TP.*HIT\|SL.*HIT\|JOURNAL" | head -100)
    if [ -n "$TRADES" ]; then
        echo ""
        echo "--- $(basename $logfile) ---"
        echo "$TRADES"
    fi
done

# 4. All BLOCKED entries to understand missed opportunities
echo ""
echo "========== BLOCKED TRADES (missed opportunities) =========="
for logfile in $(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -3); do
    BLOCKED=$(strings "$logfile" | grep -i "BLOCKED" | sort | uniq -c | sort -rn | head -20)
    if [ -n "$BLOCKED" ]; then
        echo ""
        echo "--- $(basename $logfile) ---"
        echo "$BLOCKED"
    fi
done

# 5. Guardian/drawdown history
echo ""
echo "========== GUARDIAN & DRAWDOWN =========="
for logfile in $(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -3); do
    DD=$(strings "$logfile" | grep -i "HEARTBEAT\|Guardian\|drawdown\|DD=" | tail -20)
    if [ -n "$DD" ]; then
        echo ""
        echo "--- $(basename $logfile) ---"
        echo "$DD"
    fi
done

# 6. Signal analysis - what signals were generated
echo ""
echo "========== SIGNALS GENERATED =========="
for logfile in $(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -3); do
    SIGS=$(strings "$logfile" | grep -i "SIGNAL\|SMC.*scan\|EMA.*Cross\|FVG\|OB=" | head -30)
    if [ -n "$SIGS" ]; then
        echo ""
        echo "--- $(basename $logfile) ---"
        echo "$SIGS"
    fi
done

# 7. Terminal trade history
echo ""
echo "========== TERMINAL TRADE LOG =========="
for logfile in $(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -3); do
    DEALS=$(strings "$logfile" | grep -i "deal\|order\|position\|trade.*#\|buy\|sell\|profit\|close" | head -50)
    if [ -n "$DEALS" ]; then
        echo ""
        echo "--- $(basename $logfile) ---"
        echo "$DEALS"
    fi
done

echo ""
echo "=== Done ==="
