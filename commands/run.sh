#!/bin/bash
# =============================================================
# Restart MT5 to load new EA and verify trading
# =============================================================

echo "============================================"
echo "  Restart MT5 with new EA"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Confirm .ex5 is fresh
echo "=== [1] EA file ==="
ls -la "$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.ex5"
echo ""

# 2. Restart MT5
echo "=== [2] Restart MT5 ==="
pkill -f terminal64.exe 2>/dev/null
sleep 5
cd "$MT5_DIR"
screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && cd '$MT5_DIR' && wine ./terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
echo "Waiting 30s for MT5 to start..."
sleep 30

if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 RUNNING"
else
    echo "MT5 NOT running - trying nohup"
    nohup bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine '$MT5_DIR/terminal64.exe' /portable /login:11797849 /server:FundedNext-Server" > /dev/null 2>&1 &
    sleep 30
fi
echo ""

# 3. Wait for EA to connect and check
echo "=== [3] Bot Status ==="
sleep 10
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null
else
    echo "Status file not found"
fi
echo ""

# 4. EA log
echo "=== [4] EA Log (last 30 lines) ==="
EA_LOG_DIR="$MT5_DIR/MQL5/Logs"
LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    tail -30 "$LATEST_LOG" | strings
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
