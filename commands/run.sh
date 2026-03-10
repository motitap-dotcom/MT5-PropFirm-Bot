#!/bin/bash
# =============================================================
# DEEP DIAGNOSTIC - Why no trades?
# =============================================================

echo "============================================"
echo "  TRADE DIAGNOSTIC REPORT"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
MT5_LOG_DIR="${MT5_BASE}/logs"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# 1. FULL EA Logs - ALL of today
echo "=== FULL EA LOGS TODAY ==="
for logfile in "$EA_LOG_DIR"/*.log; do
    if [ -f "$logfile" ]; then
        echo "--- $(basename $logfile) ---"
        cat "$logfile" 2>&1
        echo ""
    fi
done
echo ""

# 2. Check for BLOCKED/REJECT/ERROR messages
echo "=== BLOCKED & ERROR MESSAGES ==="
grep -i -E "BLOCK|REJECT|ERROR|FAIL|STOP|HALT|PAUSE|DISABLED|CANNOT|FORBIDDEN" "$EA_LOG_DIR"/*.log 2>/dev/null || echo "None found"
echo ""

# 3. Check for signal messages
echo "=== SIGNAL MESSAGES ==="
grep -i -E "SIGNAL|BUY|SELL|ENTRY|TRIGGER|SCAN|SCORE" "$EA_LOG_DIR"/*.log 2>/dev/null || echo "None found"
echo ""

# 4. Guardian state messages
echo "=== GUARDIAN MESSAGES ==="
grep -i -E "GUARDIAN|DRAWDOWN|DD|SAFE|RISK|LIMIT" "$EA_LOG_DIR"/*.log 2>/dev/null || echo "None found"
echo ""

# 5. Check trading permissions in MT5
echo "=== MT5 TRADE PERMISSIONS ==="
grep -i -E "trade|algo|expert|autotrading|allow" "$MT5_LOG_DIR"/*.log 2>/dev/null | tail -20
echo ""

# 6. Check config files
echo "=== CONFIG FILES ==="
if [ -d "$FILES_DIR" ]; then
    echo "Config files found:"
    ls -la "$FILES_DIR/" 2>&1
    echo ""
    for f in "$FILES_DIR"/*.json; do
        if [ -f "$f" ]; then
            echo "--- $(basename $f) ---"
            cat "$f" 2>&1
            echo ""
        fi
    done
else
    echo "Config directory NOT FOUND at: $FILES_DIR"
fi
echo ""

# 7. Check trade history in MT5 journal
echo "=== MT5 JOURNAL (last 50 lines) ==="
LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    tail -50 "$LATEST_LOG" 2>&1
fi
echo ""

# 8. Check EA source for minimum conditions
echo "=== SIGNAL ENGINE - ENTRY CONDITIONS ==="
grep -n -i "signal\|entry\|CanTrade\|IsTrading\|AllowTrade\|OpenPosition\|OrderSend" "$EA_DIR/SignalEngine.mqh" 2>/dev/null | head -30
echo ""
grep -n -i "CanTrade\|IsTrading\|AllowTrade\|CheckGuardian" "$EA_DIR/Guardian.mqh" 2>/dev/null | head -20
echo ""
grep -n -i "OnTick\|signal\|OpenBuy\|OpenSell\|CanTrade\|trade_allowed" "$EA_DIR/PropFirmBot.mq5" 2>/dev/null | head -30
echo ""

# 9. Check HEARTBEAT messages for pattern
echo "=== HEARTBEAT PATTERN ==="
grep -i "HEARTBEAT\|NEWBAR\|TICK" "$EA_LOG_DIR"/*.log 2>/dev/null | tail -20
echo ""

# 10. Check if AutoTrading is enabled
echo "=== AUTOTRADING CHECK ==="
grep -i "autotrading\|algo\|expert" "$MT5_LOG_DIR"/*.log 2>/dev/null | tail -10
echo ""

echo "============================================"
echo "  END DIAGNOSTIC"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
