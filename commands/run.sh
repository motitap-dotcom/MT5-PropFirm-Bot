#!/bin/bash
# =============================================================
# Fix #6: Embed relay + check EA logs from new session
# =============================================================

echo "=== FIX #6 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# ============================================
# STEP 1: Create telegram relay inline
# ============================================
echo "--- STEP 1: Create telegram relay ---"
pkill -f "telegram_relay" 2>/dev/null || true

cat > /root/telegram_relay.sh << 'RELAYEOF'
#!/bin/bash
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
QUEUE_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/telegram_queue.txt"
CHECK_INTERVAL=5

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="$1" \
        -d parse_mode="HTML" > /dev/null 2>&1
}

echo "[TelegramRelay] Started at $(date)"
send_telegram "🤖 PropFirmBot Telegram Relay started!"

LAST_POS=0
[ -f "$QUEUE_FILE" ] && LAST_POS=$(wc -c < "$QUEUE_FILE")

while true; do
    if [ -f "$QUEUE_FILE" ]; then
        CURRENT_SIZE=$(wc -c < "$QUEUE_FILE")
        if [ "$CURRENT_SIZE" -gt "$LAST_POS" ]; then
            tail -c +$((LAST_POS + 1)) "$QUEUE_FILE" | while IFS= read -r line; do
                [ -z "$line" ] && continue
                MESSAGE=$(echo "$line" | sed 's/^[^|]*|//')
                [ -n "$MESSAGE" ] && send_telegram "$MESSAGE" && echo "[$(date '+%H:%M:%S')] Sent: ${MESSAGE:0:60}..."
                sleep 1
            done
            LAST_POS=$CURRENT_SIZE
        fi
    fi
    sleep $CHECK_INTERVAL
done
RELAYEOF

chmod +x /root/telegram_relay.sh
nohup bash /root/telegram_relay.sh > /var/log/telegram_relay.log 2>&1 &
sleep 3

if pgrep -f "telegram_relay" > /dev/null; then
    echo "Relay RUNNING"
else
    echo "Relay FAILED"
fi
cat /var/log/telegram_relay.log 2>/dev/null | tail -3
echo ""

# Add to crontab
(crontab -l 2>/dev/null | grep -v "telegram_relay"; echo "@reboot nohup bash /root/telegram_relay.sh > /var/log/telegram_relay.log 2>&1 &") | crontab -

# ============================================
# STEP 2: Check if EA already loaded with new code
# ============================================
echo "--- STEP 2: Check current EA log ---"
LATEST_LOG=$(ls -t "${MT5_BASE}/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -f "$LATEST_LOG" ]; then
    LOG_SIZE=$(stat -c%s "$LATEST_LOG")
    echo "Log file size: $LOG_SIZE bytes"

    # Get ALL init entries from the log
    echo ""
    echo "All INIT entries (looking for new session):"
    iconv -f UTF-16LE -t UTF-8 "$LATEST_LOG" 2>/dev/null | grep -i "AccountState.*SWITCHED\|RiskMgr.*Init\|Risk.*multiplier\|INIT.*ALL SYSTEMS\|HEARTBEAT.*Ticks=1" | tail -10
    echo ""

    echo "Last 20 lines of EA log:"
    iconv -f UTF-16LE -t UTF-8 "$LATEST_LOG" 2>/dev/null | tail -20
fi
echo ""

# ============================================
# STEP 3: Check MT5 is actually running the NEW EA
# ============================================
echo "--- STEP 3: MT5 status ---"
echo "Processes:"
pgrep -a wineserver 2>/dev/null | head -3
echo ""

echo "Network:"
ss -tnp | grep -i "main\|wineserver" | head -5
echo ""

echo "EA .ex5 file info:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

echo "Status JSON:"
cat "$FILES_DIR/status.json" 2>/dev/null
echo ""

echo "Telegram queue file:"
ls -la "$FILES_DIR/telegram_queue.txt" 2>/dev/null || echo "No queue file"
cat "$FILES_DIR/telegram_queue.txt" 2>/dev/null | head -5
echo ""

echo "=== DONE - $(date) ==="
