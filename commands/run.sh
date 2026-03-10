#!/bin/bash
# Quick verification - is EA v4.0 running and trading?
echo "=== EA v4.0 VERIFICATION $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5}/MQL5/Experts/PropFirmBot"

# MT5 process
echo ""
echo ">>> MT5 PROCESS"
pgrep -a terminal64 || echo "NOT RUNNING"

# EA source version
echo ""
echo ">>> EA SOURCE VERSION"
grep "version\|v[0-9]" "${EA_DIR}/PropFirmBot.mq5" 2>/dev/null | head -3

# Check for .ex5 files anywhere
echo ""
echo ">>> ALL .ex5 FILES"
find "${MT5}/MQL5" -name "*.ex5" -type f -ls 2>/dev/null

# Also check Wine virtual FS
find /root/.wine -name "PropFirmBot.ex5" -type f -ls 2>/dev/null

# MT5 EA logs from today
echo ""
echo ">>> EA LOG (today - last 30 entries)"
LOGFILE="${MT5}/MQL5/Logs/$(date +%Y%m%d).log"
if [ -f "$LOGFILE" ]; then
    iconv -f UTF-16LE -t UTF-8 "$LOGFILE" 2>/dev/null | grep -i "propfirm\|heartbeat\|signal\|trade\|error\|init\|guardian\|risk\|newbar\|buy\|sell\|open\|close" | tail -30
else
    echo "No EA log for today"
    # Check yesterday
    YESTERDAY=$(date -d "yesterday" +%Y%m%d)
    LOGFILE2="${MT5}/MQL5/Logs/${YESTERDAY}.log"
    if [ -f "$LOGFILE2" ]; then
        echo "Yesterday's log:"
        iconv -f UTF-16LE -t UTF-8 "$LOGFILE2" 2>/dev/null | tail -15
    fi
fi

# MT5 terminal logs
echo ""
echo ">>> TERMINAL LOG (last 15)"
tail -15 "${MT5}/logs/$(date +%Y%m%d).log" 2>/dev/null

# Account info from status
echo ""
echo ">>> STATUS FILES"
cat "${MT5}/MQL5/Files/PropFirmBot/account_state.json" 2>/dev/null | head -20

# Watchdog
echo ""
echo ">>> WATCHDOG"
crontab -l 2>/dev/null | grep mt5_watchdog
cat /root/mt5_watchdog.log 2>/dev/null || echo "(no restarts needed yet)"

# VNC
echo ""
echo ">>> SERVICES"
echo "Xvfb: $(pgrep Xvfb > /dev/null && echo 'OK' || echo 'DOWN')"
echo "VNC: $(pgrep x11vnc > /dev/null && echo 'OK on :5900' || echo 'DOWN')"

echo ""
echo "=== DONE $(date -u) ==="
