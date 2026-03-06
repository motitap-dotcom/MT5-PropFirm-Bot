#!/bin/bash
# Fix common.ini: Enable WebRequest for Telegram + verify AutoTrading
echo "=== FIX common.ini $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
CINI="$MT5/config/common.ini"

# 1. Fix WebRequest in common.ini [Experts] section
echo "[1] Fixing common.ini..."
if [ -f "$CINI" ]; then
    # Enable WebRequest
    sed -i 's/^WebRequest=0/WebRequest=1/' "$CINI"
    # Set WebRequest URL to Telegram API
    sed -i 's|^WebRequestUrl=$|WebRequestUrl=https://api.telegram.org|' "$CINI"
    sed -i 's|^WebRequestUrl=\s*$|WebRequestUrl=https://api.telegram.org|' "$CINI"

    echo "Fixed. Current [Experts] section:"
    sed -n '/\[Experts\]/,/\[/p' "$CINI" | head -15
else
    echo "common.ini NOT FOUND!"
fi
echo ""

# 2. Restart MT5
echo "[2] Restarting MT5..."
pkill -f terminal64 2>/dev/null
sleep 5

export DISPLAY=:99
export WINEPREFIX=/root/.wine
pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)

nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
sleep 12

# 3. Check EA log for AutoTrading errors
echo "[3] EA log check:"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    # Look for error 10027 or successful trade or telegram
    tail -30 "$LATEST_LOG" 2>&1 | grep -i "10027\|disabled\|SELL\|BUY\|Telegram\|INIT\|HEARTBEAT\|NEWBAR\|error\|fail\|success\|opened\|order" || tail -15 "$LATEST_LOG" 2>&1
fi
echo ""

# 4. Verify MT5 running
echo "[4] MT5 status:"
pgrep -f terminal64 > /dev/null && echo "RUNNING" || echo "NOT RUNNING"

echo ""
echo "=== DONE $(date -u) ==="
