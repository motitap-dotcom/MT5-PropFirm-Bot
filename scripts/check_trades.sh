#!/bin/bash
# PropFirmBot - Deep Signal & Trade Diagnostics
# WHY is the bot not trading?

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOGS="$MT5/MQL5/Logs"
TERM_LOGS="$MT5/logs"
NOW=$(date '+%Y-%m-%d %H:%M:%S UTC')

echo "============================================"
echo "  WHY IS THE BOT NOT TRADING?"
echo "  Deep Diagnostic - $NOW"
echo "============================================"

# 1. List ALL EA log files
echo ""
echo ">>> ALL EA LOG FILES <<<"
ls -lh "$EA_LOGS/"*.log 2>/dev/null || echo "No EA logs found!"

# 2. List ALL terminal log files
echo ""
echo ">>> ALL TERMINAL LOG FILES <<<"
ls -lh "$TERM_LOGS/"*.log 2>/dev/null || echo "No terminal logs found!"

# 3. Read the BIGGEST/most recent EA log fully for signal info
echo ""
echo "============================================"
echo ">>> FULL EA LOG ANALYSIS <<<"
echo "============================================"

LATEST_EA=$(ls -t "$EA_LOGS/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA" ]; then
    echo "Analyzing: $LATEST_EA"
    echo "Size: $(stat -c%s "$LATEST_EA") bytes"
    CONTENT=$(cat "$LATEST_EA" | tr -d '\0')

    echo ""
    echo "--- [1] SIGNAL ENGINE lines ---"
    echo "$CONTENT" | grep -i "signal" | head -50

    echo ""
    echo "--- [2] TRADE / ORDER / POSITION lines ---"
    echo "$CONTENT" | grep -i "trade\|order\|position\|buy\|sell\|open pos\|close pos\|deal" | head -50

    echo ""
    echo "--- [3] SESSION FILTER lines ---"
    echo "$CONTENT" | grep -i "session\|london\|newyork\|new york\|outside.*session\|trading.*hours\|market.*closed\|market.*open" | head -30

    echo ""
    echo "--- [4] SPREAD FILTER lines ---"
    echo "$CONTENT" | grep -i "spread\|slippage\|too wide\|high spread" | head -30

    echo ""
    echo "--- [5] GUARDIAN / RISK lines ---"
    echo "$CONTENT" | grep -i "guardian\|risk\|drawdown\|halt\|shutdown\|emergency\|suspend\|weekend\|can_trade\|cannot trade\|blocked" | head -50

    echo ""
    echo "--- [6] BALANCE / EQUITY / ACCOUNT lines ---"
    echo "$CONTENT" | grep -i "balance\|equity\|margin\|account\|fund\|initial" | head -30

    echo ""
    echo "--- [7] ERROR / WARNING lines ---"
    echo "$CONTENT" | grep -i "error\|warning\|fail\|invalid\|cannot\|denied\|reject" | head -50

    echo ""
    echo "--- [8] INIT / DEINIT / STARTUP lines ---"
    echo "$CONTENT" | grep -i "init\|start\|loaded\|attach\|deinit\|remove\|version\|config\|param" | head -30

    echo ""
    echo "--- [9] TICK / TIMER lines (sample) ---"
    echo "$CONTENT" | grep -i "tick\|timer\|ontick\|ontimer" | head -10
    echo "... total tick/timer lines: $(echo "$CONTENT" | grep -ic "tick\|timer\|ontick\|ontimer")"

    echo ""
    echo "--- [10] TELEGRAM lines ---"
    echo "$CONTENT" | grep -i "telegram\|notification\|alert\|message.*sent" | head -20

    echo ""
    echo "--- [11] NEWS FILTER lines ---"
    echo "$CONTENT" | grep -i "news\|calendar\|event\|nfp\|fomc\|cpi" | head -20

    echo ""
    echo "--- [12] COMPLETE FIRST 100 LINES (to see startup) ---"
    echo "$CONTENT" | head -100

    echo ""
    echo "--- [13] COMPLETE LAST 100 LINES (latest activity) ---"
    echo "$CONTENT" | tail -100

    echo ""
    echo "--- [14] UNIQUE MESSAGE TYPES (counts) ---"
    echo "$CONTENT" | sed 's/^[A-Z]*[[:space:]]*[0-9]*[[:space:]]*//' | sed 's/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*/TIME/' | sort | uniq -c | sort -rn | head -40

else
    echo "NO EA LOGS FOUND!"
fi

# 4. Check the second most recent EA log too
echo ""
echo "============================================"
SECOND_EA=$(ls -t "$EA_LOGS/"*.log 2>/dev/null | sed -n '2p')
if [ -n "$SECOND_EA" ]; then
    echo ">>> SECOND EA LOG: $SECOND_EA <<<"
    echo "Size: $(stat -c%s "$SECOND_EA") bytes"
    CONTENT2=$(cat "$SECOND_EA" | tr -d '\0')

    echo ""
    echo "--- Signal lines ---"
    echo "$CONTENT2" | grep -i "signal" | head -30

    echo ""
    echo "--- Trade/Order lines ---"
    echo "$CONTENT2" | grep -i "trade\|order\|position\|buy\|sell" | head -30

    echo ""
    echo "--- Error lines ---"
    echo "$CONTENT2" | grep -i "error\|warning\|fail" | head -30

    echo ""
    echo "--- First 50 lines ---"
    echo "$CONTENT2" | head -50

    echo ""
    echo "--- Last 50 lines ---"
    echo "$CONTENT2" | tail -50
fi

# 5. Terminal log analysis
echo ""
echo "============================================"
echo ">>> TERMINAL LOG ANALYSIS <<<"
echo "============================================"

LATEST_TERM=$(ls -t "$TERM_LOGS/"*.log 2>/dev/null | grep -v metaeditor | head -1)
if [ -n "$LATEST_TERM" ]; then
    echo "Analyzing: $LATEST_TERM"
    TCONTENT=$(cat "$LATEST_TERM" | tr -d '\0')

    echo ""
    echo "--- Expert/EA related ---"
    echo "$TCONTENT" | grep -i "expert\|ea \|propfirm\|autotrading\|algo\|allow" | head -20

    echo ""
    echo "--- Connection/Login ---"
    echo "$TCONTENT" | grep -i "authorized\|login\|connect\|disconnect\|account\|server" | head -20

    echo ""
    echo "--- Errors ---"
    echo "$TCONTENT" | grep -i "error\|fail\|denied\|reject\|cannot" | head -20

    echo ""
    echo "--- Full log ---"
    echo "$TCONTENT" | tail -50
fi

# 6. Check if AutoTrading is actually enabled
echo ""
echo ">>> AUTOTRADING CHECK <<<"
CONFIG_DIR="$MT5/config"
if [ -d "$CONFIG_DIR" ]; then
    echo "Config files:"
    ls -la "$CONFIG_DIR/" 2>/dev/null
    for cf in "$CONFIG_DIR/"*; do
        if [ -f "$cf" ]; then
            echo ""
            echo "=== $(basename "$cf") ==="
            cat "$cf" 2>/dev/null | head -30
        fi
    done
fi

# 7. Check EA parameters in chart
echo ""
echo ">>> CHART PROFILES <<<"
PROFILES="$MT5/MQL5/Profiles"
if [ -d "$PROFILES" ]; then
    find "$PROFILES" -name "*.chr" -o -name "*.ini" 2>/dev/null | head -10
    for chr in $(find "$PROFILES" -name "*.chr" 2>/dev/null | head -3); do
        echo ""
        echo "=== $chr ==="
        cat "$chr" 2>/dev/null | head -50
    done
fi

echo ""
echo "============================================"
echo "  Diagnostic Complete - $NOW"
echo "============================================"
