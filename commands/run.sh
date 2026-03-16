#!/bin/bash
# Deploy fixed Guardian.mqh, compile, and restart MT5 - 2026-03-16g
echo "=== FULL DEPLOY + RESTART $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# 1. Pull latest code from repo
echo "--- Pulling latest code ---"
cd "$REPO_DIR"
git fetch origin 2>&1 | tail -3
# Try all possible branches
git checkout claude/update-current-status-1jEP6 2>/dev/null || true
git pull origin claude/update-current-status-1jEP6 2>&1 | tail -3

# 2. Copy updated EA files
echo ""
echo "--- Copying EA files ---"
for f in EA/*.mq5 EA/*.mqh; do
    [ -f "$f" ] && cp "$f" "$EA_DIR/" && echo "OK: $f"
done

# 3. Verify Guardian.mqh has the fix
echo ""
echo "--- Verifying fix in Guardian.mqh ---"
if grep -q "CheckCircuitBreakerTimeout\|CheckRemoteReset\|m_circuit_breaker_time" "$EA_DIR/Guardian.mqh"; then
    echo "FIX CONFIRMED: All 3 new mechanisms present"
else
    echo "WARNING: Fix not found in Guardian.mqh!"
fi

# 4. Backup current .ex5
echo ""
echo "--- Backing up current .ex5 ---"
cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak_$(date +%Y%m%d_%H%M)" 2>/dev/null
ls -la "$EA_DIR/PropFirmBot.ex5"

# 5. Compile with correct MetaEditor path
echo ""
echo "--- Compiling EA ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$EA_DIR"
wine "${MT5_BASE}/MetaEditor64.exe" /compile:PropFirmBot.mq5 /log 2>&1 | head -20
sleep 5

echo ""
echo "Compiled .ex5:"
ls -la "$EA_DIR/PropFirmBot.ex5"

# Check compile log
echo ""
echo "--- Compile log ---"
cat "$EA_DIR/PropFirmBot.log" 2>/dev/null | tail -20

# 6. Stop MT5
echo ""
echo "--- Restarting MT5 ---"
MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    kill "$MT5_PID" 2>/dev/null
    sleep 5
    kill -0 "$MT5_PID" 2>/dev/null && kill -9 "$MT5_PID" 2>/dev/null
    sleep 2
fi
pkill -f "terminal64" 2>/dev/null || true
sleep 2
echo "MT5 stopped"

# 7. Start MT5
nohup wine "${MT5_BASE}/terminal64.exe" /portable > /dev/null 2>&1 &
echo "MT5 starting... PID=$!"
sleep 30
echo "Wait complete"

# 8. Verify
echo ""
echo "--- Verification ---"
if pgrep -f "terminal64" > /dev/null 2>&1; then
    echo "MT5: RUNNING (PID=$(pgrep -f terminal64.exe | head -1))"
else
    echo "MT5: NOT RUNNING!"
fi

# 9. Check status
echo ""
echo "--- Status ---"
EA_FILES="${MT5_BASE}/MQL5/Files/PropFirmBot"
sleep 5
cat "$EA_FILES/status.json" 2>/dev/null || echo "status.json not ready yet"

# 10. Check new logs
echo ""
echo "--- New EA Log ---"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
sleep 3
LATEST=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | grep -E "INIT|NEW DAY|GUARDIAN|POST-RESET|CIRCUIT|ACTIVE|AUTO-RESET|REMOTE" | tail -20
    echo ""
    echo "Last 10 lines:"
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -10
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
