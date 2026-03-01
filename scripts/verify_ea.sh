#!/bin/bash
# PropFirmBot - Comprehensive Live Verification
# Dynamically checks today's logs and all critical systems
echo "╔══════════════════════════════════════════════════════╗"
echo "║  PropFirmBot LIVE Verification - $(date -u '+%Y-%m-%d %H:%M:%S UTC')  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date -u '+%Y%m%d')
YESTERDAY=$(date -u -d 'yesterday' '+%Y%m%d' 2>/dev/null || date -u '+%Y%m%d')

# 1. MT5 Process Check
echo "━━━ 1. MT5 Process ━━━"
MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    echo "✅ MT5 is RUNNING (PID: $MT5_PID)"
    ps aux | grep terminal64 | grep -v grep | awk '{printf "   CPU: %s%% | MEM: %s%% | Start: %s %s\n", $3, $4, $9, $10}'
else
    echo "❌ MT5 is NOT RUNNING!"
fi
echo ""

# 2. VNC Display
echo "━━━ 2. Display & VNC ━━━"
pgrep -x "Xvfb" > /dev/null 2>&1 && echo "✅ Xvfb running" || echo "❌ Xvfb not running"
pgrep -x "x11vnc" > /dev/null 2>&1 && echo "✅ x11vnc running" || echo "❌ x11vnc not running"
echo ""

# 3. Network Connections (MT5 broker)
echo "━━━ 3. Broker Connection ━━━"
CONNS=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10)
if [ -n "$CONNS" ]; then
    echo "✅ Active connections:"
    echo "$CONNS" | while IFS= read -r line; do echo "   $line"; done
else
    echo "⚠️  No active broker connections found"
fi
echo ""

# 4. EA Files
echo "━━━ 4. EA Installation ━━━"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    EX5_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)
    EX5_DATE=$(stat -c%y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d. -f1)
    echo "✅ PropFirmBot.ex5: ${EX5_SIZE} bytes (compiled: $EX5_DATE)"
    SRC_COUNT=$(ls "$EA_DIR"/*.mqh "$EA_DIR"/*.mq5 2>/dev/null | wc -l)
    echo "   Source files: $SRC_COUNT"
else
    echo "❌ PropFirmBot.ex5 NOT FOUND!"
fi
echo ""

# 5. Terminal Log (find latest dynamically)
echo "━━━ 5. Terminal Log ━━━"
TERM_LOG=""
for d in "$TODAY" "$YESTERDAY"; do
    if [ -f "$MT5/logs/${d}.log" ]; then
        TERM_LOG="$MT5/logs/${d}.log"
        break
    fi
done
if [ -z "$TERM_LOG" ]; then
    TERM_LOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
fi
if [ -n "$TERM_LOG" ] && [ -f "$TERM_LOG" ]; then
    TERM_NAME=$(basename "$TERM_LOG")
    TERM_SIZE=$(stat -c%s "$TERM_LOG" 2>/dev/null)
    echo "Log file: $TERM_NAME ($TERM_SIZE bytes)"
    echo "--- Last 25 lines ---"
    cat "$TERM_LOG" | tr -d '\0' | tail -25 | while IFS= read -r line; do echo "   $line"; done
else
    echo "⚠️  No terminal log found"
fi
echo ""

# 6. EA Log (find latest dynamically)
echo "━━━ 6. EA Activity Log ━━━"
EA_LOG=""
for d in "$TODAY" "$YESTERDAY"; do
    if [ -f "$MT5/MQL5/Logs/${d}.log" ]; then
        EA_LOG="$MT5/MQL5/Logs/${d}.log"
        break
    fi
done
if [ -z "$EA_LOG" ]; then
    EA_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
fi
if [ -n "$EA_LOG" ] && [ -f "$EA_LOG" ]; then
    EA_SIZE=$(stat -c%s "$EA_LOG" 2>/dev/null)
    EA_NAME=$(basename "$EA_LOG")
    echo "✅ EA Log: $EA_NAME ($EA_SIZE bytes)"

    # Count key events
    HEARTBEATS=$(grep -c "HEARTBEAT" "$EA_LOG" 2>/dev/null); HEARTBEATS=${HEARTBEATS:-0}
    NEWBARS=$(grep -c "NEWBAR" "$EA_LOG" 2>/dev/null); NEWBARS=${NEWBARS:-0}
    SIGNALS=$(grep -c "SIGNAL\|signal" "$EA_LOG" 2>/dev/null); SIGNALS=${SIGNALS:-0}
    TRADES=$(grep -c "TRADE\|OrderSend\|OPENED\|CLOSED" "$EA_LOG" 2>/dev/null); TRADES=${TRADES:-0}
    ERRORS=$(grep -c "error\|ERROR\|failed\|FAILED" "$EA_LOG" 2>/dev/null); ERRORS=${ERRORS:-0}
    BLOCKED=$(grep -c "BLOCKED" "$EA_LOG" 2>/dev/null); BLOCKED=${BLOCKED:-0}

    echo "   Heartbeats: $HEARTBEATS | NewBars: $NEWBARS | Signals: $SIGNALS"
    echo "   Trades: $TRADES | Errors: $ERRORS | Blocked: $BLOCKED"

    # Last heartbeat
    LAST_HB=$(grep "HEARTBEAT" "$EA_LOG" 2>/dev/null | tail -1)
    if [ -n "$LAST_HB" ]; then
        echo ""
        echo "   Last Heartbeat:"
        echo "   $LAST_HB"
    fi

    # Last 20 EA lines
    echo ""
    echo "   --- Last 20 EA entries ---"
    cat "$EA_LOG" | tr -d '\0' | tail -20 | while IFS= read -r line; do echo "   $line"; done
else
    echo "⚠️  No EA log found"
    echo "   Available logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
fi
echo ""

# 7. Account & Guardian State
echo "━━━ 7. Account State ━━━"
if [ -n "$EA_LOG" ] && [ -f "$EA_LOG" ]; then
    # Extract latest state info
    LAST_STATE=$(grep "State=" "$EA_LOG" 2>/dev/null | tail -1)
    LAST_BAL=$(grep "Bal=" "$EA_LOG" 2>/dev/null | tail -1)
    [ -n "$LAST_STATE" ] && echo "   $LAST_STATE"

    # Check for Guardian status
    GUARDIAN=$(grep -i "guardian\|SHUTDOWN\|PAUSED\|ACTIVE" "$EA_LOG" 2>/dev/null | tail -3)
    if [ -n "$GUARDIAN" ]; then
        echo "   Guardian recent:"
        echo "$GUARDIAN" | while IFS= read -r line; do echo "   $line"; done
    fi

    # Check for drawdown warnings
    DD_WARN=$(grep -i "drawdown\|DD_WARNING\|DD_CRITICAL" "$EA_LOG" 2>/dev/null | tail -3)
    if [ -n "$DD_WARN" ]; then
        echo "   ⚠️  Drawdown warnings:"
        echo "$DD_WARN" | while IFS= read -r line; do echo "   $line"; done
    fi
fi
echo ""

# 8. Config Files
echo "━━━ 8. Config Files ━━━"
CONFIG_DIR="$MT5/MQL5/Files/PropFirmBot"
if [ -d "$CONFIG_DIR" ]; then
    for f in "$CONFIG_DIR"/*.json; do
        if [ -f "$f" ]; then
            FNAME=$(basename "$f")
            FSIZE=$(stat -c%s "$f" 2>/dev/null)
            echo "   ✅ $FNAME ($FSIZE bytes)"
        fi
    done
else
    echo "   ⚠️  Config directory not found"
fi
echo ""

# 9. Telegram Test
echo "━━━ 9. Telegram Connectivity ━━━"
TG_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TG_CHAT="7013213983"
TG_TEST=$(curl -s --connect-timeout 5 "https://api.telegram.org/bot${TG_TOKEN}/getMe" 2>&1)
if echo "$TG_TEST" | grep -q '"ok":true'; then
    BOT_NAME=$(echo "$TG_TEST" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
    echo "✅ Telegram Bot online: $BOT_NAME"

    # Send status to Telegram
    SEND=$(curl -s --connect-timeout 5 "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT}" \
        -d "text=🔍 Status Check $(date -u '+%H:%M UTC')
MT5: $([ -n "$MT5_PID" ] && echo '✅ Running' || echo '❌ Down')
EA: $([ -n "$EA_LOG" ] && echo "✅ Active ($HEARTBEATS heartbeats)" || echo '⚠️ No log')
Trades: $TRADES | Errors: $ERRORS" 2>&1)
    echo "$SEND" | grep -q '"ok":true' && echo "✅ Status sent to Telegram" || echo "⚠️  Telegram send failed"
else
    echo "❌ Cannot reach Telegram API"
fi
echo ""

# 10. System Health
echo "━━━ 10. VPS Health ━━━"
echo "   Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "   Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
echo "   Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB ($(( USED_MEM * 100 / TOTAL_MEM ))%)"
echo "   Disk: $(df -h / | awk 'NR==2{printf "%s used, %s free", $5, $4}')"
echo ""

# 11. Watchdog check
echo "━━━ 11. Watchdog ━━━"
if crontab -l 2>/dev/null | grep -q "watchdog\|mt5_monitor\|PropFirmBot"; then
    echo "✅ Watchdog cron found:"
    crontab -l 2>/dev/null | grep "watchdog\|mt5_monitor\|PropFirmBot" | while IFS= read -r line; do echo "   $line"; done
else
    echo "⚠️  No watchdog cron found"
fi
echo ""

echo "╔══════════════════════════════════════════════════════╗"
echo "║  Verification Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')     ║"
echo "╚══════════════════════════════════════════════════════╝"
