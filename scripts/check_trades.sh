#!/bin/bash
# PropFirmBot - Account & Trade History Check
# Runs on VPS via GitHub Actions

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
NOW=$(date '+%Y-%m-%d %H:%M:%S UTC')

echo "============================================"
echo "  PropFirmBot - Account & Trade Report"
echo "  $NOW"
echo "============================================"

# 1. Status JSON (current account state from EA)
echo ""
echo ">>> ACCOUNT STATUS (status.json) <<<"
STATUS_FILE="$MT5/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
else
    echo "status.json not found"
fi

# 2. Account State JSON
echo ""
echo ">>> ACCOUNT STATE (account_state.json) <<<"
ACCT_FILE="$MT5/MQL5/Files/PropFirmBot/account_state.json"
if [ -f "$ACCT_FILE" ]; then
    cat "$ACCT_FILE"
else
    echo "account_state.json not found"
fi

# 3. Risk params
echo ""
echo ">>> RISK PARAMS (risk_params.json) <<<"
RISK_FILE="$MT5/MQL5/Files/PropFirmBot/risk_params.json"
if [ -f "$RISK_FILE" ]; then
    cat "$RISK_FILE"
else
    echo "risk_params.json not found"
fi

# 4. Search ALL EA logs for trade activity
echo ""
echo "============================================"
echo ">>> TRADE HISTORY FROM EA LOGS <<<"
echo "============================================"

for logfile in $(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -7); do
    LOGDATE=$(basename "$logfile" .log)
    echo ""
    echo "--- Log: $LOGDATE ---"

    # Orders, positions, trades
    echo "[Orders/Trades]"
    cat "$logfile" | tr -d '\0' | grep -i "order\|trade\|position\|buy\|sell\|open\|close\|deal\|profit\|loss" | grep -v "StatusWriter\|FolderCreate\|scanning\|OnTimer\|OnTick" | tail -30

    # Balance/Equity info
    echo "[Balance/Equity]"
    cat "$logfile" | tr -d '\0' | grep -i "balance\|equity\|drawdown\|margin\|account\|fund" | grep -v "StatusWriter\|FolderCreate" | tail -15

    # Signals generated
    echo "[Signals]"
    cat "$logfile" | tr -d '\0' | grep -i "signal\|entry\|exit\|trigger\|pattern\|setup" | grep -v "StatusWriter" | tail -15

    # Guardian/Safety
    echo "[Guardian/Safety]"
    cat "$logfile" | tr -d '\0' | grep -i "guardian\|safety\|emergency\|shutdown\|halt\|warning\|critical\|suspend" | tail -10

    echo ""
done

# 5. Check for trade journal files
echo ""
echo ">>> TRADE JOURNAL FILES <<<"
JOURNAL_DIR="$MT5/MQL5/Files/PropFirmBot"
ls -la "$JOURNAL_DIR/"*journal* "$JOURNAL_DIR/"*trade* "$JOURNAL_DIR/"*history* 2>/dev/null || echo "No trade journal files found"

# 6. MT5 terminal trade log
echo ""
echo ">>> MT5 TERMINAL JOURNAL (last 7 days) <<<"
JOURNAL_DIR2="$MT5/logs"
for jfile in $(ls -t "$JOURNAL_DIR2/"*.log 2>/dev/null | head -7); do
    JDATE=$(basename "$jfile" .log)
    TRADE_LINES=$(cat "$jfile" | tr -d '\0' | grep -i "order\|deal\|trade\|buy\|sell\|position" | grep -v "scanning" | wc -l)
    if [ "$TRADE_LINES" -gt 0 ]; then
        echo ""
        echo "--- Terminal $JDATE ($TRADE_LINES trade lines) ---"
        cat "$jfile" | tr -d '\0' | grep -i "order\|deal\|trade\|buy\|sell\|position" | grep -v "scanning" | tail -20
    fi
done

# 7. Check account connected
echo ""
echo ">>> CONNECTION STATUS <<<"
LATEST_TERM=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM" ]; then
    echo "Last terminal log: $(basename $LATEST_TERM)"
    cat "$LATEST_TERM" | tr -d '\0' | grep -i "authorized\|login\|connect\|disconnect\|account" | tail -10
fi

# 8. All config files summary
echo ""
echo ">>> ALL CONFIG FILES <<<"
for f in "$MT5/MQL5/Files/PropFirmBot/"*.json; do
    if [ -f "$f" ]; then
        echo ""
        echo "=== $(basename $f) ==="
        cat "$f"
    fi
done

echo ""
echo "============================================"
echo "  Report Complete - $NOW"
echo "============================================"
