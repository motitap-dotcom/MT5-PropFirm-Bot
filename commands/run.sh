#!/bin/bash
# Full fresh status check - 2026-03-17
echo "=== FULL STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. MT5 process
echo "--- 1. MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    PID=$(pgrep -f terminal64 | head -1)
    UPTIME=$(ps -o etime= -p $PID 2>/dev/null | xargs)
    echo "MT5: RUNNING (PID=$PID, uptime=$UPTIME)"
else
    echo "MT5: NOT RUNNING!"
fi

# 2. EX5 file timestamp (confirm new code)
echo ""
echo "--- 2. EX5 Version ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

# 3. status.json
echo ""
echo "--- 3. status.json ---"
cat "$MT5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null || echo "NOT FOUND"

# 4. Full RiskMgr init line from latest restart
echo ""
echo "--- 4. RiskMgr Init (latest) ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep "RiskMgr.*Init" | tail -1
fi

# 5. Guardian init
echo ""
echo "--- 5. Guardian Init (latest) ---"
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep "GUARDIAN.*INIT" | tail -1
fi

# 6. AccountState init
echo ""
echo "--- 6. AccountState (latest) ---"
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep -E "AccountState|FUNDED ACCOUNT|Account Phase" | tail -5
fi

# 7. Any errors or warnings
echo ""
echo "--- 7. Errors/Warnings ---"
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep -iE "error|fail|crash|exception|critical" | tail -5
    ERRCOUNT=$(cat "$LATEST_LOG" | tr -d '\0' | grep -ciE "error|fail|crash|exception|critical" 2>/dev/null)
    echo "Total error lines: $ERRCOUNT"
fi

# 8. Connection check
echo ""
echo "--- 8. Broker Connection ---"
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep -iE "connection|disconnect|authorized|login" | tail -5
fi

# 9. Configs on VPS
echo ""
echo "--- 9. Active Configs ---"
echo "risk_params.json:"
cat "$MT5/MQL5/Files/PropFirmBot/risk_params.json" 2>/dev/null || echo "NOT FOUND"
echo ""
echo "account_state.json (phase):"
cat "$MT5/MQL5/Files/PropFirmBot/account_state.json" 2>/dev/null | grep -E "current_phase|trailing|min_equity|account_size" || echo "NOT FOUND"

# 10. System resources
echo ""
echo "--- 10. System ---"
df -h / | tail -1
echo "Wine processes: $(pgrep -c -f wine 2>/dev/null || echo 0)"
free -h | grep Mem

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
