#!/bin/bash
# =============================================================
# Fix #5: Switch VPS to correct branch + full restart
# =============================================================

echo "=== FIX #5 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"
TARGET_BRANCH="claude/update-server-vnc-wsD2d"

# ============================================
# STEP 1: Switch VPS repo to correct branch
# ============================================
echo "--- STEP 1: Switch to correct branch ---"
cd "$REPO_DIR"
echo "Before: $(git rev-parse --abbrev-ref HEAD)"
git fetch origin "$TARGET_BRANCH" 2>&1 | tail -3
git checkout "$TARGET_BRANCH" 2>&1 | tail -3
git pull origin "$TARGET_BRANCH" 2>&1 | tail -3
echo "After: $(git rev-parse --abbrev-ref HEAD)"
echo ""

# ============================================
# STEP 2: Kill ALL wine/MT5
# ============================================
echo "--- STEP 2: Kill all wine ---"
pkill -9 wineserver 2>/dev/null || true
pkill -9 -f "wine" 2>/dev/null || true
pkill -9 -f "start.exe" 2>/dev/null || true
sleep 5
echo "Clean: $(pgrep -c wine 2>/dev/null || echo 0) wine processes"
echo ""

# ============================================
# STEP 3: Delete state + copy EA + compile
# ============================================
echo "--- STEP 3: Setup ---"
find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null
echo "State deleted"

# Copy from repo (now on correct branch)
cp "$REPO_DIR"/EA/*.mq5 "$EA_DIR/" 2>/dev/null
cp "$REPO_DIR"/EA/*.mqh "$EA_DIR/" 2>/dev/null
cp "$REPO_DIR"/configs/*.json "$FILES_DIR/" 2>/dev/null
echo "Files copied from repo"

# Verify key changes are present
grep "m_risk_multiplier.*1.0" "$EA_DIR/AccountStateManager.mqh" && echo "AccountState: risk_multiplier=1.0 OK" || echo "AccountState: WRONG"
grep "m_max_positions.*3" "$EA_DIR/AccountStateManager.mqh" && echo "AccountState: max_positions=3 OK" || echo "AccountState: WRONG"
grep "InpMaxPositions.*= 3" "$EA_DIR/PropFirmBot.mq5" && echo "PropFirmBot: MaxPositions=3 OK" || echo "PropFirmBot: WRONG"
grep "SendTelegramViaFile" "$EA_DIR/Notifications.mqh" && echo "Notifications: File relay OK" || echo "Notifications: WRONG"
echo ""

echo "--- STEP 4: Compile ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$EA_DIR"
wine "$MT5_BASE/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 8

if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo "OK: $(stat -c%s "$EA_DIR/PropFirmBot.ex5") bytes"
else
    echo "FAILED"
fi
iconv -f UTF-16LE -t UTF-8 "$EA_DIR/PropFirmBot.log" 2>/dev/null | grep -i "error\|warning\|Result" | tail -3
echo ""

# ============================================
# STEP 5: Create and start Telegram relay
# ============================================
echo "--- STEP 5: Telegram relay ---"
pkill -f "telegram_relay" 2>/dev/null || true
mkdir -p "$FILES_DIR"

# Start relay from repo script
chmod +x "$REPO_DIR/scripts/telegram_relay.sh" 2>/dev/null
nohup bash "$REPO_DIR/scripts/telegram_relay.sh" > /var/log/telegram_relay.log 2>&1 &
sleep 3
pgrep -f "telegram_relay" > /dev/null && echo "Relay RUNNING" || echo "Relay FAILED"
cat /var/log/telegram_relay.log 2>/dev/null | tail -3
echo ""

# ============================================
# STEP 6: Kill stale wineserver + Start MT5
# ============================================
echo "--- STEP 6: Start MT5 ---"
pkill -9 wineserver 2>/dev/null || true
sleep 2

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
echo "MT5 starting..."
sleep 35

# ============================================
# STEP 7: Verify EVERYTHING
# ============================================
echo ""
echo "========== VERIFICATION =========="

echo "Network:"
ss -tnp | grep -i "main\|wineserver" | head -3
echo ""

echo "Relay:"
pgrep -a -f "telegram_relay" | head -1 || echo "NOT running"
echo ""

# Wait for EA to fully init
sleep 10

echo "--- NEW EA Logs ---"
LATEST_LOG=$(ls -t "${MT5_BASE}/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    echo "Log: $(basename $LATEST_LOG) ($(stat -c%s "$LATEST_LOG") bytes)"
    # Show ALL init lines from the LATEST session only
    iconv -f UTF-16LE -t UTF-8 "$LATEST_LOG" 2>/dev/null | grep "12:0[3-9]\|12:1[0-9]\|14:0[3-9]\|14:1[0-9]" | grep -i "RiskMgr\|AccountState\|INIT\|MaxPos\|Risk\|Notify\|BLOCKED\|relay\|HEARTBEAT\|ALL SYSTEMS\|SWITCHED\|multiplier\|Symbols\|FUNDED\|risk_mul" | tail -30
fi
echo ""

echo "--- Status JSON timestamp ---"
grep "timestamp" "$FILES_DIR/status.json" 2>/dev/null
echo ""

echo "--- Telegram queue ---"
ls -la "$FILES_DIR/telegram_queue.txt" 2>/dev/null && cat "$FILES_DIR/telegram_queue.txt" 2>/dev/null | tail -3
echo ""

echo "--- Relay log ---"
cat /var/log/telegram_relay.log 2>/dev/null | tail -5
echo ""

echo "=== DONE - $(date) ==="
