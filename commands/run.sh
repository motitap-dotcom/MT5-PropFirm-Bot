#!/bin/bash
# =============================================================
# Update mt5_status.json daemon - fix JSON format for dashboard
# =============================================================

echo "============================================"
echo "  Update: mt5_status.json format"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# === Step 1: Stop current daemon ===
echo "=== [1] Stopping current daemon ==="
systemctl stop mt5-status-json.service 2>/dev/null || true
echo "Stopped."
echo ""

# === Step 2: Update the writer script with correct format ===
echo "=== [2] Updating writer script ==="
mkdir -p /root/PropFirmBot/scripts /var/bots

cat > /root/PropFirmBot/scripts/mt5_status_writer.sh << 'SCRIPT_EOF'
#!/bin/bash
# mt5_status_writer.sh - writes /var/bots/mt5_status.json every 30 seconds
# Format expected by dashboard:
# { bot_name, active, balance, last_trade, updated_at }

STATUS_FILE="/var/bots/mt5_status.json"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
BALANCE_CACHE="/root/PropFirmBot/state/last_balance"
LAST_TRADE_CACHE="/root/PropFirmBot/state/last_trade"

mkdir -p /root/PropFirmBot/state

while true; do
    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # --- Check if MT5 is running ---
    MT5_PID=$(pgrep -of "terminal64.exe" 2>/dev/null || true)
    if [ -n "$MT5_PID" ]; then
        ACTIVE=true
    else
        ACTIVE=false
    fi

    # --- Get balance from EA logs ---
    BALANCE="null"
    LATEST_LOG=$(ls -t "$MT5_DIR/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        # Look for balance in log lines (EA logs balance as "Balance: XXXX.XX" or "Bal:XXXX.XX")
        BAL_LINE=$(cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | grep -ioE 'balance[: ]+[0-9]+\.[0-9]+' | tail -1)
        if [ -n "$BAL_LINE" ]; then
            BAL_VAL=$(echo "$BAL_LINE" | grep -oE '[0-9]+\.[0-9]+' | tail -1)
            if [ -n "$BAL_VAL" ]; then
                BALANCE="$BAL_VAL"
                echo "$BAL_VAL" > "$BALANCE_CACHE"
            fi
        fi
    fi
    # Fallback to cached balance
    if [ "$BALANCE" = "null" ] && [ -f "$BALANCE_CACHE" ]; then
        CACHED=$(cat "$BALANCE_CACHE" 2>/dev/null)
        [ -n "$CACHED" ] && BALANCE="$CACHED"
    fi

    # --- Get last trade from EA logs ---
    LAST_TRADE="null"
    if [ -n "$LATEST_LOG" ]; then
        TRADE_LINE=$(cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | grep -iE 'BUY|SELL|CLOSE|ORDER' | tail -1)
        if [ -n "$TRADE_LINE" ]; then
            # Extract timestamp from log line (format: HH:MM:SS or YYYY.MM.DD HH:MM:SS)
            TRADE_TIME=$(echo "$TRADE_LINE" | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
            if [ -n "$TRADE_TIME" ]; then
                TRADE_DATE=$(date -u '+%Y-%m-%dT')
                LAST_TRADE="\"${TRADE_DATE}${TRADE_TIME}Z\""
                echo "$LAST_TRADE" > "$LAST_TRADE_CACHE"
            fi
        fi
    fi
    # Fallback to cached last trade
    if [ "$LAST_TRADE" = "null" ] && [ -f "$LAST_TRADE_CACHE" ]; then
        CACHED=$(cat "$LAST_TRADE_CACHE" 2>/dev/null)
        [ -n "$CACHED" ] && LAST_TRADE="$CACHED"
    fi

    # --- Write JSON in dashboard format ---
    cat > "$STATUS_FILE" << JSONEOF
{
  "bot_name": "MT5 Bot",
  "active": $ACTIVE,
  "balance": $BALANCE,
  "last_trade": $LAST_TRADE,
  "updated_at": "$TIMESTAMP"
}
JSONEOF

    sleep 30
done
SCRIPT_EOF

chmod +x /root/PropFirmBot/scripts/mt5_status_writer.sh
echo "Script updated."
echo ""

# === Step 3: Restart daemon ===
echo "=== [3] Restarting daemon ==="
systemctl daemon-reload
systemctl restart mt5-status-json.service
sleep 5

echo "--- Service status ---"
systemctl is-active mt5-status-json.service
echo ""

# === Step 4: Verify output ===
echo "=== [4] Verifying /var/bots/mt5_status.json ==="
sleep 3
cat /var/bots/mt5_status.json 2>/dev/null || echo "ERROR: file not found"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
