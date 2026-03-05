#!/bin/bash
# =============================================================
# Fix #3: Read logs + Setup Telegram relay + Restart
# =============================================================

echo "=== FIX #3 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# ============================================
# STEP 1: Read current EA logs properly (UTF-16)
# ============================================
echo "--- STEP 1: Current EA Logs (pre-restart) ---"
MT5_LOG_DIR="${MT5_BASE}/MQL5/Logs"
LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    echo "Log: $LATEST_LOG"
    # MT5 logs are UTF-16LE, convert to UTF-8
    iconv -f UTF-16LE -t UTF-8 "$LATEST_LOG" 2>/dev/null | grep -i "RiskMgr\|AccountState\|INIT\|MaxPos\|Risk\|Notify\|BLOCKED\|WARNING\|ERROR\|signal\|HEARTBEAT" | tail -40
fi
echo ""

# ============================================
# STEP 2: Kill MT5
# ============================================
echo "--- STEP 2: Kill MT5 ---"
pkill -9 -f "terminal64\|metatrader\|MetaTrader" 2>/dev/null || true
# Kill wine server processes related to MT5 (but keep wineserver for other things)
sleep 3
echo "MT5 stopped"
echo ""

# ============================================
# STEP 3: Delete state file again (in case it was recreated)
# ============================================
echo "--- STEP 3: Delete state files ---"
find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null
echo "State files deleted"
echo ""

# ============================================
# STEP 4: Recompile with updated Notifications.mqh
# ============================================
echo "--- STEP 4: Recompile ---"
cd "$EA_DIR"
WINEPREFIX=/root/.wine wine "$MT5_BASE/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>/dev/null || true
sleep 5

if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo "OK: $(stat -c%s "$EA_DIR/PropFirmBot.ex5") bytes"
else
    echo "FAILED!"
fi

# Check for compile errors
if [ -f "$EA_DIR/PropFirmBot.log" ]; then
    iconv -f UTF-16LE -t UTF-8 "$EA_DIR/PropFirmBot.log" 2>/dev/null | grep -i "error\|warning\|Result" | tail -5
fi
echo ""

# ============================================
# STEP 5: Setup Telegram relay daemon
# ============================================
echo "--- STEP 5: Setup Telegram relay ---"

# Kill old relay if running
pkill -f "telegram_relay" 2>/dev/null || true
sleep 1

# Create queue directory
mkdir -p "$FILES_DIR"

# Copy relay script
RELAY_SCRIPT="/root/MT5-PropFirm-Bot/scripts/telegram_relay.sh"
chmod +x "$RELAY_SCRIPT"

# Start relay daemon
nohup bash "$RELAY_SCRIPT" > /var/log/telegram_relay.log 2>&1 &
RELAY_PID=$!
echo "Telegram relay started with PID: $RELAY_PID"

# Verify it's running
sleep 2
if kill -0 $RELAY_PID 2>/dev/null; then
    echo "Relay daemon RUNNING"
else
    echo "Relay daemon FAILED to start"
    cat /var/log/telegram_relay.log 2>/dev/null | tail -5
fi

# Add to cron for persistence
(crontab -l 2>/dev/null | grep -v "telegram_relay"; echo "@reboot bash $RELAY_SCRIPT > /var/log/telegram_relay.log 2>&1 &") | crontab -
echo "Added to crontab for auto-start"
echo ""

# ============================================
# STEP 6: Restart MT5
# ============================================
echo "--- STEP 6: Restart MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
echo "MT5 starting..."
sleep 30

# ============================================
# STEP 7: Read new EA logs + verify
# ============================================
echo "--- STEP 7: Verification ---"

echo "MT5 processes:"
ps aux | grep -i "[w]ine\|[t]erminal64" | head -5
echo ""

echo "Network:"
ss -tnp | grep -i "main\|wineserver" | head -5
echo ""

echo "Relay daemon:"
pgrep -a -f "telegram_relay" || echo "NOT running"
echo ""

echo "Telegram relay log:"
cat /var/log/telegram_relay.log 2>/dev/null | tail -5
echo ""

echo "--- NEW EA Logs ---"
LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    echo "Log: $LATEST_LOG"
    iconv -f UTF-16LE -t UTF-8 "$LATEST_LOG" 2>/dev/null | grep -i "RiskMgr\|AccountState\|INIT\|MaxPos\|Risk\|Notify\|relay\|HEARTBEAT\|WebRequest\|BLOCKED\|ALL SYSTEMS" | tail -30
fi
echo ""

echo "--- Status JSON ---"
cat "$FILES_DIR/status.json" 2>/dev/null
echo ""

echo "--- Telegram queue file ---"
cat "$FILES_DIR/telegram_queue.txt" 2>/dev/null | tail -5
echo ""

echo "=== DONE - $(date) ==="
