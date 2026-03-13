#!/bin/bash
# Full status check - fresh data pull
echo "=== FULL STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
TERM_LOG_DIR="${MT5_BASE}/logs"

# 1. MT5 process
echo "--- MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    UPTIME=$(ps -o etime= -p "$MT5_PID" 2>/dev/null)
    echo "MT5: RUNNING (PID=$MT5_PID, uptime=$UPTIME)"
else
    echo "MT5: NOT RUNNING!"
fi

# 2. Status.json
echo ""
echo "--- status.json ---"
if [ -f "$EA_FILES_DIR/status.json" ]; then
    cat "$EA_FILES_DIR/status.json" 2>&1
    echo ""
    echo "File age: $(stat -c '%y' "$EA_FILES_DIR/status.json" 2>/dev/null)"
else
    echo "status.json not found"
fi

# 3. Account state config
echo ""
echo "--- account_state.json ---"
if [ -f "$EA_FILES_DIR/account_state.json" ]; then
    cat "$EA_FILES_DIR/account_state.json" 2>&1
else
    echo "account_state.json not found"
fi

# 4. Open positions (from status.json)
echo ""
echo "--- Open Positions ---"
if [ -f "$EA_FILES_DIR/status.json" ]; then
    python3 -c "
import json
with open('$EA_FILES_DIR/status.json') as f:
    d = json.load(f)
pos = d.get('positions', {})
print(f\"Open positions: {pos.get('count', 0)}\")
for p in pos.get('open', []):
    print(f\"  {p}\")
" 2>/dev/null || echo "Could not parse positions"
fi

# 5. Recent EA log (last 30 lines)
echo ""
echo "--- Latest EA Log (last 30 lines) ---"
LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    tail -30 "$LATEST_LOG"
else
    echo "No EA log files found"
fi

# 6. Wine/Xvfb status
echo ""
echo "--- System Services ---"
echo "Wine processes: $(pgrep -c -f wine 2>/dev/null || echo 0)"
echo "Xvfb: $(pgrep -f Xvfb > /dev/null 2>&1 && echo RUNNING || echo NOT RUNNING)"
echo "x11vnc: $(pgrep -f x11vnc > /dev/null 2>&1 && echo RUNNING || echo NOT RUNNING)"
echo "Disk: $(df -h / | tail -1 | awk '{print $4 " free of " $2}')"
echo "Memory: $(free -h | grep Mem | awk '{print $3 " used of " $2}')"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
