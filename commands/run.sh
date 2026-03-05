#!/bin/bash
# =============================================================
# Fix #4: git pull on VPS + proper MT5 restart + telegram relay
# =============================================================

echo "=== FIX #4 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

# ============================================
# STEP 1: Git pull on VPS to get latest scripts
# ============================================
echo "--- STEP 1: Git pull on VPS ---"
cd "$REPO_DIR"
git fetch origin 2>&1 | tail -3
# Find current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
echo "Current branch: $CURRENT_BRANCH"
git pull origin "$CURRENT_BRANCH" 2>&1 | tail -5
echo ""

# ============================================
# STEP 2: FULLY kill MT5 + wineserver
# ============================================
echo "--- STEP 2: Kill MT5 completely ---"
# Kill the actual MT5 terminal process
pkill -9 -f "terminal64" 2>/dev/null || true
# Kill the 'main' process (MT5 runs as this under wine)
pkill -9 -f "start.exe.*terminal" 2>/dev/null || true
# Kill ALL wine-related MT5 processes
for pid in $(pgrep -f "wineserver"); do
    # Only kill newer wineserver (not the system ones from Feb)
    START_DATE=$(ps -p $pid -o lstart= 2>/dev/null | awk '{print $2,$3}')
    echo "Wineserver PID $pid started: $START_DATE"
done
# Kill all wine processes to get a clean slate
pkill -9 wineserver 2>/dev/null || true
pkill -9 -f "wine" 2>/dev/null || true
sleep 5

echo "All wine processes killed"
echo "Remaining wine processes:"
pgrep -a -f "wine" 2>/dev/null || echo "None (clean)"
echo ""

# ============================================
# STEP 3: Delete saved state file
# ============================================
echo "--- STEP 3: Delete state ---"
find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null
echo "Done"
echo ""

# ============================================
# STEP 4: Copy latest EA files and recompile
# ============================================
echo "--- STEP 4: Copy EA + recompile ---"
# Copy EA files from repo to MT5
cp "$REPO_DIR"/EA/*.mq5 "$EA_DIR/" 2>/dev/null
cp "$REPO_DIR"/EA/*.mqh "$EA_DIR/" 2>/dev/null
echo "EA files copied"

# Copy configs
cp "$REPO_DIR"/configs/*.json "$FILES_DIR/" 2>/dev/null
echo "Config files copied"

# Need wineserver for compilation
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Compile
cd "$EA_DIR"
wine "$MT5_BASE/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 8

if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    NEW_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5")
    NEW_DATE=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5")
    echo "Compiled OK: $NEW_SIZE bytes, modified $(date -d @$NEW_DATE '+%H:%M:%S')"
else
    echo "COMPILATION FAILED"
fi

# Check compile log
if [ -f "$EA_DIR/PropFirmBot.log" ]; then
    iconv -f UTF-16LE -t UTF-8 "$EA_DIR/PropFirmBot.log" 2>/dev/null | grep -i "error\|warning\|Result" | tail -5
fi
echo ""

# ============================================
# STEP 5: Start Telegram relay daemon
# ============================================
echo "--- STEP 5: Start Telegram relay ---"
pkill -f "telegram_relay" 2>/dev/null || true
mkdir -p "$FILES_DIR"

RELAY_SCRIPT="$REPO_DIR/scripts/telegram_relay.sh"
if [ -f "$RELAY_SCRIPT" ]; then
    chmod +x "$RELAY_SCRIPT"
    nohup bash "$RELAY_SCRIPT" > /var/log/telegram_relay.log 2>&1 &
    sleep 2
    if pgrep -f "telegram_relay" > /dev/null; then
        echo "Relay RUNNING (PID: $(pgrep -f telegram_relay | head -1))"
    else
        echo "Relay FAILED"
        cat /var/log/telegram_relay.log 2>/dev/null | tail -3
    fi
else
    echo "ERROR: $RELAY_SCRIPT not found!"
    ls -la "$REPO_DIR/scripts/" | head -10
fi

# Add to crontab
(crontab -l 2>/dev/null | grep -v "telegram_relay"; echo "@reboot bash $RELAY_SCRIPT > /var/log/telegram_relay.log 2>&1 &") | crontab -
echo ""

# ============================================
# STEP 6: Start MT5 fresh
# ============================================
echo "--- STEP 6: Start MT5 ---"
# Kill any stale wineserver first
pkill -9 wineserver 2>/dev/null || true
sleep 2

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
echo "MT5 starting (fresh wineserver)..."
sleep 35

# ============================================
# STEP 7: Full verification
# ============================================
echo "--- STEP 7: Verification ---"

echo "Wine processes:"
pgrep -a -f "wineserver\|start.exe\|terminal" 2>/dev/null | head -5
echo ""

echo "Network (MT5 connected?):"
ss -tnp | grep -i "main\|wineserver" | head -5
echo ""

echo "Relay daemon:"
pgrep -a -f "telegram_relay" || echo "NOT running"
echo ""

echo "--- EA Logs (new session) ---"
LATEST_LOG=$(ls -t "${MT5_BASE}/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    echo "Log: $LATEST_LOG ($(stat -c%s "$LATEST_LOG") bytes)"
    iconv -f UTF-16LE -t UTF-8 "$LATEST_LOG" 2>/dev/null | grep -i "RiskMgr\|AccountState\|INIT\|MaxPos\|Risk\|Notify\|BLOCKED\|relay\|HEARTBEAT\|ALL SYSTEMS\|SWITCHED\|multiplier\|Symbols" | tail -30
fi
echo ""

echo "--- Status JSON ---"
cat "$FILES_DIR/status.json" 2>/dev/null
echo ""

echo "--- Telegram queue ---"
ls -la "$FILES_DIR/telegram_queue.txt" 2>/dev/null || echo "No queue file yet"
cat "$FILES_DIR/telegram_queue.txt" 2>/dev/null | tail -5
echo ""

echo "--- Relay log ---"
cat /var/log/telegram_relay.log 2>/dev/null | tail -5
echo ""

echo "=== DONE - $(date) ==="
