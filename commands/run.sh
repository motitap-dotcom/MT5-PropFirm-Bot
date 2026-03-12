#!/bin/bash
# Deploy all hardening fixes + install watchdog cron
echo "=== FULL DEPLOY + WATCHDOG $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
REPO="/root/MT5-PropFirm-Bot"

# 1. Pull latest code
echo "--- Pulling latest code ---"
cd "$REPO"
git fetch origin claude/fix-bot-trading-config-N1uDv 2>&1
git checkout claude/fix-bot-trading-config-N1uDv 2>&1
git pull origin claude/fix-bot-trading-config-N1uDv 2>&1

# 2. Copy EA files
echo ""
echo "--- Copying EA files ---"
for f in "$REPO"/EA/*.mq5 "$REPO"/EA/*.mqh; do
    [ -f "$f" ] && cp -v "$f" "$EA_DIR/" 2>&1
done

# 3. Remove old .ex5 and restart MT5
echo ""
echo "--- Removing old .ex5 ---"
rm -f "$EA_DIR/PropFirmBot.ex5"

echo ""
echo "--- Restarting MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    echo "Stopping MT5 (PID=$MT5_PID)..."
    kill "$MT5_PID" 2>/dev/null
    sleep 5
    pgrep -f "terminal64.exe" > /dev/null && kill -9 "$MT5_PID" 2>/dev/null
    sleep 3
fi

cd "$MT5_BASE"
DISPLAY=:99 WINEPREFIX=/root/.wine nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
sleep 20

if pgrep -f "terminal64.exe" > /dev/null; then
    echo "MT5 started (PID=$(pgrep -f terminal64.exe | head -1))"
else
    echo "ERROR: MT5 failed to start!"
fi

# 4. Install watchdog cron
echo ""
echo "--- Installing MT5 Watchdog ---"
chmod +x "$REPO/scripts/mt5_watchdog.sh"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "mt5_watchdog"; then
    echo "Watchdog cron already installed"
else
    # Add to crontab
    (crontab -l 2>/dev/null; echo "*/5 * * * * /root/MT5-PropFirm-Bot/scripts/mt5_watchdog.sh >> /var/log/mt5_watchdog.log 2>&1") | crontab -
    echo "Watchdog cron INSTALLED (runs every 5 minutes)"
fi

# Verify cron
echo ""
echo "Current crontab:"
crontab -l 2>/dev/null | grep -v "^#"

# 5. Wait for compilation and check
sleep 10
echo ""
echo "--- Verification ---"
echo ".ex5:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "Not yet compiled"

echo ""
echo "New EA log:"
EA_LATEST=$(ls -t "$MT5_BASE/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    TMPLOG="/tmp/ea_final.txt"
    iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
      sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"

    echo "INIT messages:"
    grep "\[INIT\]" "$TMPLOG" 2>/dev/null | tail -15

    echo ""
    echo "Guardian init:"
    grep "\[GUARDIAN\].*INIT\|TRAILING\|FUNDED" "$TMPLOG" 2>/dev/null | tail -5

    echo ""
    echo "SignalEngine (M15 check):"
    grep "\[SignalEngine\]" "$TMPLOG" 2>/dev/null | tail -8

    echo ""
    echo "Last 10 lines:"
    tail -10 "$TMPLOG"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
