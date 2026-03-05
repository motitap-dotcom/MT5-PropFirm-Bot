#!/bin/bash
# =============================================================
# Deep Trade Analysis - Pull ALL trading data
# =============================================================

echo "=============================================="
echo "  DEEP TRADE ANALYSIS - $(date)"
echo "=============================================="

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
FILES_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
LOG_DIR="$MT5_DIR/MQL5/Logs"

# 1. ALL EA Logs - full content from all dates
echo ""
echo "=== 1. ALL EA LOG FILES ==="
if [ -d "$LOG_DIR" ]; then
    for logfile in "$LOG_DIR"/*.log; do
        if [ -f "$logfile" ]; then
            echo "--- FILE: $(basename "$logfile") ($(wc -l < "$logfile") lines) ---"
            # Show all trade-related lines (TRADE, ORDER, SIGNAL, PROFIT, LOSS, CLOSE, OPEN, POSITION, DEAL)
            grep -i "TRADE\|ORDER\|SIGNAL\|PROFIT\|LOSS\|CLOSE\|OPEN\|POSITION\|DEAL\|BUY\|SELL\|SL\|TP\|STOP\|TAKE\|EXECUTE\|FILLED\|ENTRY\|EXIT" "$logfile" 2>/dev/null | head -200
            echo ""
        fi
    done
else
    echo "Log directory not found"
fi

# 2. ALL Heartbeat lines (account status over time)
echo ""
echo "=== 2. HEARTBEAT HISTORY (Balance/Equity over time) ==="
for logfile in "$LOG_DIR"/*.log; do
    if [ -f "$logfile" ]; then
        echo "--- $(basename "$logfile") ---"
        grep -i "HEARTBEAT" "$logfile" 2>/dev/null | head -50
        echo ""
    fi
done

# 3. ALL BLOCKED/REJECTED trades
echo ""
echo "=== 3. BLOCKED & REJECTED TRADES ==="
for logfile in "$LOG_DIR"/*.log; do
    if [ -f "$logfile" ]; then
        BLOCKED=$(grep -ic "BLOCK\|REJECT\|SKIP\|FILTER\|OUTSIDE\|SPREAD\|RISK\|GUARDIAN\|PREVENT\|DENY\|LIMIT\|RESTRICT" "$logfile" 2>/dev/null)
        if [ "$BLOCKED" -gt 0 ]; then
            echo "--- $(basename "$logfile") ($BLOCKED blocked entries) ---"
            grep -i "BLOCK\|REJECT\|SKIP\|FILTER\|OUTSIDE\|SPREAD\|RISK.*block\|PREVENT\|DENY" "$logfile" 2>/dev/null | head -100
            echo ""
        fi
    fi
done

# 4. Signal Analysis - what signals were generated
echo ""
echo "=== 4. SIGNAL GENERATION HISTORY ==="
for logfile in "$LOG_DIR"/*.log; do
    if [ -f "$logfile" ]; then
        grep -i "SIGNAL\|signal_score\|SCORE\|TREND\|MOMENTUM\|BREAKOUT\|REVERSAL\|RANGE" "$logfile" 2>/dev/null | head -100
        echo ""
    fi
done

# 5. Guardian actions
echo ""
echo "=== 5. GUARDIAN ACTIONS ==="
for logfile in "$LOG_DIR"/*.log; do
    if [ -f "$logfile" ]; then
        grep -i "GUARDIAN\|DRAWDOWN\|DD_CHECK\|EQUITY.*HIGH\|WATER.*MARK\|TRAIL\|SAFETY\|EMERGENCY\|CRITICAL\|SOFT\|HARD" "$logfile" 2>/dev/null | head -50
        echo ""
    fi
done

# 6. Config files - FULL content
echo ""
echo "=== 6. CONFIGURATION FILES ==="
for cfg in "$FILES_DIR"/*.json; do
    if [ -f "$cfg" ]; then
        echo "--- $(basename "$cfg") ---"
        cat "$cfg"
        echo ""
        echo ""
    fi
done

# 7. PropFirmBot.log (EA's own log)
echo ""
echo "=== 7. PROPFIRMBOT.LOG (EA Internal Log) ==="
if [ -f "$EA_DIR/PropFirmBot.log" ]; then
    echo "Size: $(wc -l < "$EA_DIR/PropFirmBot.log") lines"
    cat "$EA_DIR/PropFirmBot.log"
else
    echo "No PropFirmBot.log found"
fi

# 8. MT5 Terminal journal
echo ""
echo "=== 8. MT5 TERMINAL JOURNAL ==="
JOURNAL_DIR="$MT5_DIR/Logs"
if [ -d "$JOURNAL_DIR" ]; then
    for jfile in "$JOURNAL_DIR"/*.log; do
        if [ -f "$jfile" ]; then
            echo "--- $(basename "$jfile") ---"
            grep -i "order\|deal\|trade\|profit\|loss\|buy\|sell\|position\|close\|open\|modify\|delete\|error\|fail" "$jfile" 2>/dev/null | head -100
            echo ""
        fi
    done
else
    echo "No terminal journal directory"
    # Try alternative locations
    find "$MT5_DIR" -name "*.log" -not -path "*/MQL5/*" 2>/dev/null | while read f; do
        echo "Found log: $f"
        tail -20 "$f" 2>/dev/null
        echo ""
    done
fi

# 9. Trade history from MT5 account (history files)
echo ""
echo "=== 9. TRADE HISTORY FILES ==="
find "$MT5_DIR" -name "*history*" -o -name "*deal*" -o -name "*trade*" -o -name "*order*" -o -name "*journal*" 2>/dev/null | while read f; do
    if [ -f "$f" ]; then
        echo "Found: $f ($(stat -c '%s' "$f") bytes, modified: $(stat -c '%y' "$f"))"
        head -30 "$f" 2>/dev/null
        echo ""
    fi
done

# 10. CSV/report files
echo ""
echo "=== 10. REPORT/CSV FILES ==="
find "$FILES_DIR" -name "*.csv" -o -name "*report*" -o -name "*journal*" -o -name "*history*" 2>/dev/null | while read f; do
    if [ -f "$f" ]; then
        echo "Found: $f"
        cat "$f" 2>/dev/null | head -50
        echo ""
    fi
done

# 11. Full log for LAST 3 days (raw, for complete analysis)
echo ""
echo "=== 11. RAW LOGS LAST 3 DAYS (first 300 lines each) ==="
for logfile in "$LOG_DIR"/202603{03,04,05}.log; do
    if [ -f "$logfile" ]; then
        echo "--- $(basename "$logfile") ($(wc -l < "$logfile") total lines) ---"
        head -300 "$logfile"
        echo "..."
        echo ""
    fi
done

# 12. EA Input parameters (from the .mq5 source)
echo ""
echo "=== 12. EA INPUT PARAMETERS ==="
grep -A2 "input " "$EA_DIR/PropFirmBot.mq5" 2>/dev/null | head -80

echo ""
echo "=============================================="
echo "  END OF ANALYSIS - $(date)"
echo "=============================================="
