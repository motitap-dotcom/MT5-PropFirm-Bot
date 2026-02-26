#!/bin/bash
# PropFirmBot - Full VPS & EA Status Check
# Dynamic dates - no hardcoded values
echo "╔══════════════════════════════════════════════════╗"
echo "║     PropFirmBot - VPS Status Check               ║"
echo "║     $(date '+%Y-%m-%d %H:%M:%S UTC')                       ║"
echo "╚══════════════════════════════════════════════════╝"

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date '+%Y%m%d')

echo ""
echo "━━━ 1. MT5 Process ━━━"
if pgrep -f "terminal64" > /dev/null 2>&1; then
    echo "✅ MT5 is RUNNING"
    ps aux | grep terminal64 | grep -v grep | awk '{printf "   PID: %s | CPU: %s%% | MEM: %s%% | Started: %s %s\n", $2, $3, $4, $9, $10}'
else
    echo "❌ MT5 is NOT RUNNING!"
fi

echo ""
echo "━━━ 2. VNC / Display ━━━"
pgrep -x "x11vnc" > /dev/null 2>&1 && echo "✅ VNC (x11vnc) is RUNNING" || echo "❌ VNC is NOT running"
pgrep -x "Xvfb" > /dev/null 2>&1 && echo "✅ Xvfb display is RUNNING" || echo "❌ Xvfb is NOT running"

echo ""
echo "━━━ 3. EA Files ━━━"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    SRC_COUNT=$(ls "$EA_DIR"/*.mqh "$EA_DIR"/*.mq5 2>/dev/null | wc -l)
    echo "   Source files (.mq5/.mqh): $SRC_COUNT"
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        EX5_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)
        EX5_DATE=$(stat -c%y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d. -f1)
        echo "   ✅ PropFirmBot.ex5: ${EX5_SIZE} bytes (compiled: $EX5_DATE)"
    else
        echo "   ❌ PropFirmBot.ex5 NOT FOUND!"
    fi
else
    echo "   ❌ EA directory not found"
fi

echo ""
echo "━━━ 4. Outbound Connections (MT5 broker) ━━━"
CONNS=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 ")
if [ -n "$CONNS" ]; then
    echo "✅ Active connections:"
    echo "$CONNS" | head -10 | while IFS= read -r line; do echo "   $line"; done
else
    echo "❌ No outbound connections (MT5 may be disconnected from broker)"
fi

echo ""
echo "━━━ 5. Terminal Log (latest) ━━━"
TERM_LOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "   File: $(basename $TERM_LOG) | Size: $(stat -c%s "$TERM_LOG" 2>/dev/null) bytes"
    echo "   --- Last 25 lines ---"
    cat "$TERM_LOG" | tr -d '\0' | tail -25 | while IFS= read -r line; do echo "   $line"; done
else
    echo "   ⚠️ No terminal logs found"
fi

echo ""
echo "━━━ 6. EA Log (today: $TODAY) ━━━"
EA_LOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EA_LOG" ]; then
    EA_SIZE=$(stat -c%s "$EA_LOG" 2>/dev/null)
    echo "   ✅ EA log exists! Size: ${EA_SIZE} bytes"
    echo "   --- Last 30 lines ---"
    cat "$EA_LOG" | tr -d '\0' | tail -30 | while IFS= read -r line; do echo "   $line"; done
else
    echo "   ⚠️ No EA log for today ($TODAY)"
    echo "   Latest EA logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5 | while IFS= read -r line; do echo "   $line"; done
fi

echo ""
echo "━━━ 7. Config Files ━━━"
FILES_DIR="$MT5/MQL5/Files/PropFirmBot"
if [ -d "$FILES_DIR" ]; then
    for f in "$FILES_DIR"/*.json; do
        [ -f "$f" ] && echo "   ✅ $(basename $f)"
    done
else
    echo "   ⚠️ Config directory not found"
fi

echo ""
echo "━━━ 8. Trade Journal ━━━"
JOURNAL=$(ls -t "$MT5/MQL5/Files/"*journal*.csv "$MT5/MQL5/Files/"*trade*.csv "$MT5/MQL5/Files/PropFirmBot/"*journal*.csv 2>/dev/null | head -1)
if [ -n "$JOURNAL" ]; then
    ENTRIES=$(wc -l < "$JOURNAL" 2>/dev/null)
    echo "   ✅ $(basename $JOURNAL) - $ENTRIES entries"
    echo "   --- Last 5 entries ---"
    tail -5 "$JOURNAL" 2>/dev/null | while IFS= read -r line; do echo "   $line"; done
else
    echo "   ⚠️ No trade journal (bot may not have traded yet)"
fi

echo ""
echo "━━━ 9. Telegram Connectivity ━━━"
TG_RESULT=$(curl -s --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/getMe" 2>&1)
if echo "$TG_RESULT" | grep -q '"ok":true'; then
    echo "   ✅ Telegram Bot is ONLINE"
else
    echo "   ❌ Cannot reach Telegram API"
fi

echo ""
echo "━━━ 10. System Health ━━━"
echo "   Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "   CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$((USED_MEM * 100 / TOTAL_MEM))
echo "   Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB (${MEM_PCT}%)"
DISK_PCT=$(df -h / | awk 'NR==2{print $5}')
DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}')
echo "   Disk: ${DISK_PCT} used (${DISK_AVAIL} free)"
echo "   Internet: $(ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo '✅ OK' || echo '❌ NO INTERNET')"

echo ""
echo "━━━ 11. Wine Version ━━━"
wine --version 2>/dev/null || echo "Wine not found in PATH"

echo ""
echo "━━━ 12. Watchdog/Cron Status ━━━"
if crontab -l 2>/dev/null | grep -q "mt5_watchdog\|monitor\|terminal64"; then
    echo "   ✅ Watchdog cron is ACTIVE"
    crontab -l 2>/dev/null | grep "mt5_watchdog\|monitor\|terminal64" | while IFS= read -r line; do echo "   $line"; done
else
    echo "   ⚠️ No watchdog cron found"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║           End of Status Report                   ║"
echo "╚══════════════════════════════════════════════════╝"
