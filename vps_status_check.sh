#!/bin/bash
# PropFirmBot - Full Status Report
# Run on VPS via: ssh root@77.237.234.2 'bash -s' < vps_status_check.sh

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║     PropFirmBot - Status Report                  ║"
echo "║     $(date '+%Y-%m-%d %H:%M:%S')                        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
LOG_DIR="$MT5_DIR/MQL5/Logs"
FILES_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"

# 1. MT5 Process
echo "━━━ 1. MT5 Process ━━━"
if pgrep -x "terminal64.exe" > /dev/null 2>&1 || pgrep -f "terminal64" > /dev/null 2>&1; then
    echo "✅ MT5 is RUNNING"
    ps aux | grep -i terminal64 | grep -v grep | awk '{printf "   PID: %s | CPU: %s%% | MEM: %s%% | Running since: %s %s\n", $2, $3, $4, $9, $10}'
else
    echo "❌ MT5 is NOT RUNNING!"
fi
echo ""

# 2. VNC
echo "━━━ 2. VNC Server ━━━"
if pgrep -x "x11vnc" > /dev/null 2>&1; then
    echo "✅ VNC is RUNNING (x11vnc)"
else
    echo "❌ VNC is NOT RUNNING"
fi
if pgrep -x "Xvfb" > /dev/null 2>&1; then
    echo "✅ Xvfb display server is RUNNING"
else
    echo "❌ Xvfb is NOT RUNNING"
fi
echo ""

# 3. EA Files
echo "━━━ 3. EA Files ━━━"
if [ -d "$EA_DIR" ]; then
    EA_COUNT=$(ls "$EA_DIR"/*.mqh "$EA_DIR"/*.mq5 2>/dev/null | wc -l)
    EX5_COUNT=$(ls "$EA_DIR"/*.ex5 2>/dev/null | wc -l)
    echo "   Source files: $EA_COUNT"
    echo "   Compiled (.ex5): $EX5_COUNT"
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        EX5_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)
        EX5_DATE=$(stat -c%y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d. -f1)
        echo "   ✅ PropFirmBot.ex5: ${EX5_SIZE} bytes (compiled: $EX5_DATE)"
    else
        echo "   ❌ PropFirmBot.ex5 NOT FOUND!"
    fi
else
    echo "   ❌ EA directory not found: $EA_DIR"
fi
echo ""

# 4. Config Files
echo "━━━ 4. Config Files ━━━"
if [ -d "$FILES_DIR" ]; then
    for f in "$FILES_DIR"/*.json; do
        if [ -f "$f" ]; then
            echo "   ✅ $(basename $f)"
        fi
    done
else
    echo "   ⚠️  Config directory not found"
fi
echo ""

# 5. MT5 Logs (most recent)
echo "━━━ 5. Latest MT5 Logs ━━━"
if [ -d "$LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "   Log file: $(basename $LATEST_LOG)"
        echo "   Last modified: $(stat -c%y "$LATEST_LOG" 2>/dev/null | cut -d. -f1)"
        echo "   --- Last 30 lines ---"
        tail -30 "$LATEST_LOG" 2>/dev/null | while IFS= read -r line; do
            echo "   $line"
        done
    else
        echo "   ⚠️  No log files found"
    fi
else
    echo "   ⚠️  Log directory not found"
fi
echo ""

# 6. Check for EA-specific logs
echo "━━━ 6. EA Activity (PropFirmBot entries) ━━━"
if [ -d "$LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        PFB_LINES=$(grep -c "PropFirmBot\|PFBot\|GUARDIAN\|SIGNAL\|TRADE\|INIT\|Guardian\|guardian" "$LATEST_LOG" 2>/dev/null)
        echo "   PropFirmBot log entries: $PFB_LINES"
        echo "   --- Last EA messages ---"
        grep "PropFirmBot\|PFBot\|GUARDIAN\|SIGNAL\|TRADE\|\[INIT\]\|\[CLOSED\]\|\[NEWS\]\|Guardian\|guardian\|SignalEngine\|RiskManager" "$LATEST_LOG" 2>/dev/null | tail -20 | while IFS= read -r line; do
            echo "   $line"
        done
    fi
fi
echo ""

# 7. Trade Journal CSV
echo "━━━ 7. Trade Journal ━━━"
JOURNAL_FILE=$(ls -t "$MT5_DIR/MQL5/Files/"*journal*.csv "$MT5_DIR/MQL5/Files/"*trade*.csv "$MT5_DIR/MQL5/Files/PropFirmBot/"*journal*.csv 2>/dev/null | head -1)
if [ -n "$JOURNAL_FILE" ]; then
    TRADE_COUNT=$(wc -l < "$JOURNAL_FILE" 2>/dev/null)
    echo "   ✅ Journal file found: $(basename $JOURNAL_FILE)"
    echo "   Total entries: $TRADE_COUNT"
    echo "   --- Last 10 entries ---"
    tail -10 "$JOURNAL_FILE" 2>/dev/null | while IFS= read -r line; do
        echo "   $line"
    done
else
    echo "   ⚠️  No trade journal found (bot may not have traded yet)"
fi
echo ""

# 8. Check Telegram connectivity from VPS
echo "━━━ 8. Telegram Connectivity ━━━"
TGTEST=$(curl -s --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/getMe" 2>&1)
if echo "$TGTEST" | grep -q '"ok":true'; then
    BOT_NAME=$(echo "$TGTEST" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
    echo "   ✅ Telegram Bot is ONLINE ($BOT_NAME)"

    # Send test message
    SEND_RESULT=$(curl -s --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
        -d "chat_id=7013213983" \
        -d "text=📊 Status check from VPS - $(date '+%H:%M:%S')
Bot is being monitored." 2>&1)
    if echo "$SEND_RESULT" | grep -q '"ok":true'; then
        echo "   ✅ Test message sent to Telegram successfully!"
    else
        echo "   ❌ Failed to send test message"
    fi
else
    echo "   ❌ Cannot reach Telegram API from VPS"
    echo "   Response: $TGTEST"
fi
echo ""

# 9. System Resources
echo "━━━ 9. VPS System Health ━━━"
echo "   Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "   CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$((USED_MEM * 100 / TOTAL_MEM))
echo "   Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB (${MEM_PCT}%)"
DISK_PCT=$(df -h / | awk 'NR==2{print $5}')
DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}')
echo "   Disk: ${DISK_PCT} used (${DISK_AVAIL} free)"
echo ""

# 10. Network / MT5 connection
echo "━━━ 10. Network Status ━━━"
echo "   Internet: $(ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo '✅ OK' || echo '❌ NO INTERNET')"
echo "   DNS: $(ping -c 1 -W 2 google.com > /dev/null 2>&1 && echo '✅ OK' || echo '❌ DNS FAILED')"
echo ""

echo "╔══════════════════════════════════════════════════╗"
echo "║           End of Status Report                   ║"
echo "╚══════════════════════════════════════════════════╝"
