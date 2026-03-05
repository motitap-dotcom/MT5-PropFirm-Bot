#!/bin/bash
# =============================================================
# Telegram Relay Daemon for PropFirmBot
# Watches for messages written by EA and sends via curl
# =============================================================

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5_FILES="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files"
QUEUE_FILE="${MT5_FILES}/PropFirmBot/telegram_queue.txt"
PROCESSED_FILE="${MT5_FILES}/PropFirmBot/telegram_sent.log"
CHECK_INTERVAL=5  # Check every 5 seconds

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML" > /dev/null 2>&1
    return $?
}

echo "[TelegramRelay] Started at $(date)"
echo "[TelegramRelay] Watching: $QUEUE_FILE"

# Send startup message
send_telegram "🤖 PropFirmBot Telegram Relay started!
Bot is live and monitoring trades."

# Track last processed position
LAST_POS=0

# If file exists, start from end (don't resend old messages)
if [ -f "$QUEUE_FILE" ]; then
    LAST_POS=$(wc -c < "$QUEUE_FILE")
fi

while true; do
    if [ -f "$QUEUE_FILE" ]; then
        CURRENT_SIZE=$(wc -c < "$QUEUE_FILE")

        if [ "$CURRENT_SIZE" -gt "$LAST_POS" ]; then
            # New content - read only new lines
            NEW_LINES=$(tail -c +$((LAST_POS + 1)) "$QUEUE_FILE")

            while IFS= read -r line; do
                [ -z "$line" ] && continue

                # Extract message (after timestamp|)
                MESSAGE=$(echo "$line" | sed 's/^[^|]*|//')

                if [ -n "$MESSAGE" ]; then
                    if send_telegram "$MESSAGE"; then
                        echo "[$(date '+%H:%M:%S')] Sent: ${MESSAGE:0:60}..."
                    else
                        echo "[$(date '+%H:%M:%S')] FAILED: ${MESSAGE:0:60}..."
                    fi
                    sleep 1  # Rate limit
                fi
            done <<< "$NEW_LINES"

            LAST_POS=$CURRENT_SIZE
        fi
    fi

    sleep $CHECK_INTERVAL
done
