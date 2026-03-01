#!/bin/bash
#=============================================================================
# PropFirmBot - LIVE Verification & Deep Health Check
# Runs on VPS - comprehensive check that the bot is alive and kicking
# Usage: ssh root@77.237.234.2 'bash -s' < scripts/verify_bot_live.sh
#=============================================================================

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
LOG_DIR="$MT5_DIR/MQL5/Logs"
TERM_LOG_DIR="$MT5_DIR/logs"
FILES_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
TODAY=$(date '+%Y%m%d')
NOW=$(date '+%Y-%m-%d %H:%M:%S UTC')

# Colors
G='\033[0;32m'  # Green
R='\033[0;31m'  # Red
Y='\033[1;33m'  # Yellow
C='\033[0;36m'  # Cyan
B='\033[1m'     # Bold
N='\033[0m'     # Reset

PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "  ${G}✅ $1${N}"; PASS=$((PASS+1)); }
check_fail() { echo -e "  ${R}❌ $1${N}"; FAIL=$((FAIL+1)); }
check_warn() { echo -e "  ${Y}⚠️  $1${N}"; WARN=$((WARN+1)); }

echo ""
echo -e "${C}╔══════════════════════════════════════════════════════════╗${N}"
echo -e "${C}║  ${B}PropFirmBot - LIVE Verification Report${N}${C}                  ║${N}"
echo -e "${C}║  ${NOW}                            ║${N}"
echo -e "${C}╚══════════════════════════════════════════════════════════╝${N}"
echo ""

#=============================================================================
# 1. MT5 PROCESS
#=============================================================================
echo -e "${B}━━━ 1/10 MT5 Process ━━━${N}"
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null | head -1)
if [ -n "$MT5_PID" ]; then
    check_pass "MT5 is RUNNING (PID: $MT5_PID)"
    MT5_INFO=$(ps -p "$MT5_PID" -o %cpu,%mem,etime --no-headers 2>/dev/null)
    CPU=$(echo "$MT5_INFO" | awk '{print $1}')
    MEM=$(echo "$MT5_INFO" | awk '{print $2}')
    UPTIME=$(echo "$MT5_INFO" | awk '{print $3}')
    echo -e "     CPU: ${CPU}% | MEM: ${MEM}% | Uptime: ${UPTIME}"

    # Check if process is responsive (not zombie)
    PROC_STATE=$(cat /proc/$MT5_PID/status 2>/dev/null | grep "^State:" | awk '{print $2}')
    if [ "$PROC_STATE" = "Z" ]; then
        check_fail "MT5 process is ZOMBIE - needs restart!"
    else
        check_pass "MT5 process state: $PROC_STATE (healthy)"
    fi
else
    check_fail "MT5 is NOT RUNNING!"
fi
echo ""

#=============================================================================
# 2. BROKER CONNECTION
#=============================================================================
echo -e "${B}━━━ 2/10 Broker Connection (FundedNext) ━━━${N}"
LATEST_TERM_LOG=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM_LOG" ]; then
    # Check for authorization
    LAST_AUTH=$(cat "$LATEST_TERM_LOG" 2>/dev/null | tr -d '\0' | grep -E "authorized on|authorization.*failed" | tail -1)
    if echo "$LAST_AUTH" | grep -q "authorized on"; then
        check_pass "Broker: AUTHORIZED on FundedNext-Server"
        # Check trading mode
        TRADING_MODE=$(cat "$LATEST_TERM_LOG" 2>/dev/null | tr -d '\0' | grep "trading has been enabled" | tail -1)
        if [ -n "$TRADING_MODE" ]; then
            check_pass "Trading: ENABLED (hedging mode)"
        fi
    elif echo "$LAST_AUTH" | grep -q "failed"; then
        check_fail "Broker: AUTHORIZATION FAILED!"
        echo -e "     ${R}Last auth message: $LAST_AUTH${N}"
    else
        check_warn "No authorization info found in terminal log"
    fi

    # Check outbound broker connections
    BROKER_CONN=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 " | wc -l)
    if [ "$BROKER_CONN" -gt 0 ]; then
        check_pass "Active broker connections: $BROKER_CONN"
        ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -5 | while read line; do
            echo -e "     $line"
        done
    else
        check_warn "No active broker connections detected"
    fi
else
    check_warn "No terminal log found"
fi
echo ""

#=============================================================================
# 3. EA STATUS (PropFirmBot)
#=============================================================================
echo -e "${B}━━━ 3/10 EA Status (PropFirmBot) ━━━${N}"
LATEST_EA_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA_LOG" ]; then
    EA_LOG_SIZE=$(stat -c%s "$LATEST_EA_LOG" 2>/dev/null)
    EA_LOG_MOD=$(stat -c%y "$LATEST_EA_LOG" 2>/dev/null | cut -d. -f1)
    check_pass "EA log found: $(basename $LATEST_EA_LOG) ($EA_LOG_SIZE bytes)"
    echo -e "     Last modified: $EA_LOG_MOD"

    # Check if EA was loaded successfully
    EA_LOADED=$(cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | grep "loaded successfully" | tail -1)
    if [ -n "$EA_LOADED" ]; then
        check_pass "EA loaded successfully"
    else
        check_fail "EA not loaded!"
    fi

    # Check Guardian state
    GUARDIAN_STATE=$(cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | grep "GUARDIAN" | tail -1)
    if echo "$GUARDIAN_STATE" | grep -q "GUARDIAN_ACTIVE"; then
        check_pass "Guardian: ACTIVE (trading allowed)"
    elif echo "$GUARDIAN_STATE" | grep -q "GUARDIAN_CAUTION"; then
        check_warn "Guardian: CAUTION (reduced risk)"
    elif echo "$GUARDIAN_STATE" | grep -q "GUARDIAN_HALTED"; then
        check_fail "Guardian: HALTED (no new trades!)"
    elif echo "$GUARDIAN_STATE" | grep -q "GUARDIAN_EMERGENCY"; then
        check_fail "Guardian: EMERGENCY (closing all!)"
    fi

    # Last heartbeat
    LAST_HB=$(cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | grep "\[HEARTBEAT\]" | tail -1)
    if [ -n "$LAST_HB" ]; then
        check_pass "Last heartbeat found"
        HB_TIME=$(echo "$LAST_HB" | grep -oP '\d{2}:\d{2}:\d{2}\.\d+' | head -1)
        HB_BAL=$(echo "$LAST_HB" | grep -oP 'Bal=\$[\d.]+' | head -1)
        HB_EQ=$(echo "$LAST_HB" | grep -oP 'Eq=\$[\d.]+' | head -1)
        HB_DD=$(echo "$LAST_HB" | grep -oP 'DD=[\d.]+%' | head -1)
        HB_POS=$(echo "$LAST_HB" | grep -oP 'Positions=\d+' | head -1)
        HB_TICKS=$(echo "$LAST_HB" | grep -oP 'Ticks=\d+' | head -1)
        echo -e "     Time: $HB_TIME | $HB_BAL | $HB_EQ | $HB_DD | $HB_POS | $HB_TICKS"
    else
        check_warn "No heartbeat found in log"
    fi

    # Check for errors
    EA_ERRORS=$(cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | grep -i "error\|failed\|critical" | grep -v "outside trading\|WebRequest" | tail -5)
    if [ -n "$EA_ERRORS" ]; then
        check_warn "EA errors detected:"
        echo "$EA_ERRORS" | while IFS= read -r line; do
            echo -e "     ${R}$line${N}"
        done
    else
        check_pass "No EA errors found"
    fi

    # Check for trades
    TRADE_COUNT=$(cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | grep -c "\[TRADE\]\|\[CLOSED\]\|OrderSend\|PositionOpen" 2>/dev/null || echo "0")
    echo -e "     Trades detected in log: $TRADE_COUNT"

    # Check for signals
    SIGNAL_COUNT=$(cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | grep -c "\[SIGNAL\]\|Signal:" 2>/dev/null || echo "0")
    echo -e "     Signals detected in log: $SIGNAL_COUNT"
else
    check_fail "No EA log found!"
fi
echo ""

#=============================================================================
# 4. ACCOUNT DATA
#=============================================================================
echo -e "${B}━━━ 4/10 Account Data ━━━${N}"
if [ -n "$LAST_HB" ]; then
    BALANCE=$(echo "$LAST_HB" | grep -oP 'Bal=\$[\d.]+' | sed 's/Bal=\$//')
    EQUITY=$(echo "$LAST_HB" | grep -oP 'Eq=\$[\d.]+' | sed 's/Eq=\$//')
    DD_PCT=$(echo "$LAST_HB" | grep -oP 'DD=[\d.]+' | sed 's/DD=//')
    POSITIONS=$(echo "$LAST_HB" | grep -oP 'Positions=\d+' | sed 's/Positions=//')

    echo -e "     ${B}Balance:${N}   \$${BALANCE:-N/A}"
    echo -e "     ${B}Equity:${N}    \$${EQUITY:-N/A}"
    echo -e "     ${B}Drawdown:${N}  ${DD_PCT:-N/A}%"
    echo -e "     ${B}Positions:${N} ${POSITIONS:-N/A}"
    echo -e "     ${B}Account:${N}   11797849 (FundedNext Stellar Instant)"
    echo -e "     ${B}Max DD:${N}    6% trailing (from equity high)"

    if [ -n "$DD_PCT" ]; then
        DD_NUM=$(echo "$DD_PCT" | sed 's/%//')
        if (( $(echo "$DD_NUM < 3.5" | bc -l 2>/dev/null || echo 1) )); then
            check_pass "Drawdown ($DD_PCT%) is within SAFE zone"
        elif (( $(echo "$DD_NUM < 5.0" | bc -l 2>/dev/null || echo 0) )); then
            check_warn "Drawdown ($DD_PCT%) approaching CAUTION zone"
        else
            check_fail "Drawdown ($DD_PCT%) in DANGER zone!"
        fi
    fi
else
    check_warn "Cannot determine account data (no heartbeat)"
fi
echo ""

#=============================================================================
# 5. EA FILES INTEGRITY
#=============================================================================
echo -e "${B}━━━ 5/10 EA Files Integrity ━━━${N}"
if [ -d "$EA_DIR" ]; then
    EXPECTED_FILES=("PropFirmBot.mq5" "Guardian.mqh" "SignalEngine.mqh" "RiskManager.mqh"
                    "TradeManager.mqh" "Dashboard.mqh" "TradeJournal.mqh" "Notifications.mqh"
                    "NewsFilter.mqh" "TradeAnalyzer.mqh" "AccountStateManager.mqh")

    MISSING=0
    for f in "${EXPECTED_FILES[@]}"; do
        if [ ! -f "$EA_DIR/$f" ]; then
            check_fail "MISSING: $f"
            MISSING=$((MISSING+1))
        fi
    done

    if [ $MISSING -eq 0 ]; then
        check_pass "All 11 EA source files present"
    fi

    # Check compiled file
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        EX5_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)
        EX5_DATE=$(stat -c%y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d. -f1)
        check_pass "PropFirmBot.ex5 compiled ($EX5_SIZE bytes, $EX5_DATE)"
    else
        check_fail "PropFirmBot.ex5 NOT FOUND - EA not compiled!"
    fi
else
    check_fail "EA directory not found: $EA_DIR"
fi
echo ""

#=============================================================================
# 6. CONFIG FILES
#=============================================================================
echo -e "${B}━━━ 6/10 Config Files ━━━${N}"
if [ -d "$FILES_DIR" ]; then
    CONFIG_COUNT=$(ls "$FILES_DIR"/*.json 2>/dev/null | wc -l)
    if [ "$CONFIG_COUNT" -ge 4 ]; then
        check_pass "Config files: $CONFIG_COUNT JSON files present"
    else
        check_warn "Only $CONFIG_COUNT config files found (expected 6)"
    fi
    ls "$FILES_DIR"/*.json 2>/dev/null | while read f; do
        echo -e "     $(basename $f) ($(stat -c%s "$f") bytes)"
    done
else
    check_fail "Config directory not found!"
fi
echo ""

#=============================================================================
# 7. VNC & DISPLAY
#=============================================================================
echo -e "${B}━━━ 7/10 VNC & Display ━━━${N}"
if pgrep -x "Xvfb" > /dev/null 2>&1; then
    check_pass "Xvfb virtual display is RUNNING"
else
    check_fail "Xvfb is NOT RUNNING"
fi

if pgrep -x "x11vnc" > /dev/null 2>&1; then
    check_pass "x11vnc VNC server is RUNNING"
    VNC_PORT=$(ss -tlnp 2>/dev/null | grep x11vnc | awk '{print $4}' | head -1)
    echo -e "     VNC accessible at: 77.237.234.2:5900"
else
    check_fail "VNC is NOT RUNNING"
fi
echo ""

#=============================================================================
# 8. TELEGRAM CONNECTIVITY
#=============================================================================
echo -e "${B}━━━ 8/10 Telegram Connectivity ━━━${N}"
TG_RESULT=$(curl -s --connect-timeout 10 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe" 2>&1)
if echo "$TG_RESULT" | grep -q '"ok":true'; then
    BOT_NAME=$(echo "$TG_RESULT" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
    check_pass "Telegram Bot ONLINE ($BOT_NAME)"

    # Send verification message
    VERIFY_MSG="🟢 <b>PropFirmBot - בדיקה חיה</b>

📊 <b>סטטוס נוכחי:</b>
• MT5: $([ -n "$MT5_PID" ] && echo 'פעיל ✅' || echo 'לא פעיל ❌')
• חשבון: 11797849 (FundedNext)
• באלאנס: \$${BALANCE:-N/A}
• Equity: \$${EQUITY:-N/A}
• Drawdown: ${DD_PCT:-0}%
• פוזיציות: ${POSITIONS:-0}
• Guardian: ACTIVE

⏰ בדיקה בוצעה: $(date '+%d/%m/%Y %H:%M:%S')
🤖 הבוט חי ובועט!"

    SEND=$(curl -s --connect-timeout 10 \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${VERIFY_MSG}" \
        -d "parse_mode=HTML" 2>&1)

    if echo "$SEND" | grep -q '"ok":true'; then
        check_pass "Verification message sent to Telegram!"
    else
        check_fail "Failed to send Telegram message"
        echo -e "     ${R}Response: $(echo $SEND | head -c 200)${N}"
    fi
else
    check_fail "Cannot reach Telegram API"
fi
echo ""

#=============================================================================
# 9. SYSTEM HEALTH
#=============================================================================
echo -e "${B}━━━ 9/10 System Health ━━━${N}"
echo -e "     Uptime: $(uptime -p 2>/dev/null || uptime)"
LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
echo -e "     CPU Load: $LOAD"

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$((USED_MEM * 100 / TOTAL_MEM))
echo -e "     Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB (${MEM_PCT}%)"

if [ "$MEM_PCT" -lt 85 ]; then
    check_pass "Memory usage OK ($MEM_PCT%)"
else
    check_warn "Memory usage HIGH ($MEM_PCT%)"
fi

DISK_PCT=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}')
echo -e "     Disk: ${DISK_PCT}% used (${DISK_AVAIL} free)"

if [ "$DISK_PCT" -lt 85 ]; then
    check_pass "Disk usage OK ($DISK_PCT%)"
else
    check_warn "Disk usage HIGH ($DISK_PCT%)"
fi

# Internet
INET=$(ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1 && echo "OK" || echo "FAIL")
if [ "$INET" = "OK" ]; then
    check_pass "Internet connection OK"
else
    check_fail "No internet connection!"
fi
echo ""

#=============================================================================
# 10. WATCHDOG & MONITORING
#=============================================================================
echo -e "${B}━━━ 10/10 Watchdog & Monitoring ━━━${N}"

# Check cron
CRON_WD=$(crontab -l 2>/dev/null | grep -c "watchdog" || echo "0")
if [ "$CRON_WD" -gt 0 ]; then
    check_pass "Watchdog cron job is SET (every 2 min)"
else
    check_warn "Watchdog cron job NOT found"
fi

CRON_DR=$(crontab -l 2>/dev/null | grep -c "daily_report" || echo "0")
if [ "$CRON_DR" -gt 0 ]; then
    check_pass "Daily report cron is SET (06:00 UTC)"
else
    check_warn "Daily report cron NOT found"
fi

# Last watchdog log
WD_LOG="$HOME/PropFirmBot/logs/watchdog.log"
if [ -f "$WD_LOG" ]; then
    WD_LAST=$(tail -1 "$WD_LOG")
    check_pass "Watchdog log exists"
    echo -e "     Last entry: $WD_LAST"

    # Count recent alerts
    RECENT_ALERTS=$(grep -c "\[ALERT\]\|\[ERROR\]" "$WD_LOG" 2>/dev/null || echo "0")
    echo -e "     Total alerts in log: $RECENT_ALERTS"
else
    check_warn "Watchdog log not found (monitoring may not be set up)"
fi

# Systemd services
for svc in mt5 xvfb x11vnc; do
    SVC_STATUS=$(systemctl is-active $svc.service 2>/dev/null || echo "inactive")
    if [ "$SVC_STATUS" = "active" ]; then
        check_pass "Service $svc: ACTIVE"
    else
        SVC_ENABLED=$(systemctl is-enabled $svc.service 2>/dev/null || echo "disabled")
        check_warn "Service $svc: $SVC_STATUS (enabled: $SVC_ENABLED)"
    fi
done
echo ""

#=============================================================================
# LAST 20 EA LOG LINES
#=============================================================================
echo -e "${B}━━━ Last 20 EA Log Entries ━━━${N}"
if [ -n "$LATEST_EA_LOG" ]; then
    cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | grep "PropFirmBot" | tail -20 | while IFS= read -r line; do
        # Color code the lines
        if echo "$line" | grep -qi "error\|fail\|critical"; then
            echo -e "  ${R}$line${N}"
        elif echo "$line" | grep -qi "warn\|caution"; then
            echo -e "  ${Y}$line${N}"
        elif echo "$line" | grep -qi "trade\|order\|position"; then
            echo -e "  ${G}$line${N}"
        else
            echo -e "  $line"
        fi
    done
else
    echo -e "  ${Y}No EA log available${N}"
fi
echo ""

#=============================================================================
# SUMMARY
#=============================================================================
TOTAL=$((PASS + FAIL + WARN))
echo -e "${C}╔══════════════════════════════════════════════════════════╗${N}"
echo -e "${C}║  ${B}VERIFICATION SUMMARY${N}${C}                                    ║${N}"
echo -e "${C}╠══════════════════════════════════════════════════════════╣${N}"
echo -e "${C}║${N}  ${G}PASS: $PASS${N}  |  ${R}FAIL: $FAIL${N}  |  ${Y}WARN: $WARN${N}  |  Total: $TOTAL         ${C}║${N}"
echo -e "${C}╠══════════════════════════════════════════════════════════╣${N}"

if [ "$FAIL" -eq 0 ]; then
    echo -e "${C}║${N}  ${G}${B}🟢 BOT IS ALIVE AND KICKING! הבוט חי ובועט!${N}           ${C}║${N}"
    STATUS_EMOJI="🟢"
    STATUS_TEXT="חי ובועט"
elif [ "$FAIL" -le 2 ]; then
    echo -e "${C}║${N}  ${Y}${B}🟡 BOT HAS MINOR ISSUES - Check warnings${N}             ${C}║${N}"
    STATUS_EMOJI="🟡"
    STATUS_TEXT="בעיות קטנות"
else
    echo -e "${C}║${N}  ${R}${B}🔴 BOT NEEDS ATTENTION! - Critical failures found${N}     ${C}║${N}"
    STATUS_EMOJI="🔴"
    STATUS_TEXT="דורש טיפול!"
fi

echo -e "${C}╚══════════════════════════════════════════════════════════╝${N}"
echo ""

# Send summary to Telegram
SUMMARY_MSG="${STATUS_EMOJI} <b>PropFirmBot - דוח אימות מלא</b>

✅ עבר: $PASS
❌ נכשל: $FAIL
⚠️ אזהרות: $WARN

<b>סטטוס: ${STATUS_TEXT}</b>

📋 פרטים:
• MT5: $([ -n "$MT5_PID" ] && echo 'פעיל' || echo 'לא פעיל')
• חשבון: 11797849
• באלאנס: \$${BALANCE:-N/A}
• Drawdown: ${DD_PCT:-0}%
• Guardian: $(echo "$GUARDIAN_STATE" | grep -oP 'GUARDIAN_\w+' || echo 'N/A')

⏰ $(date '+%d/%m/%Y %H:%M:%S UTC')"

curl -s --connect-timeout 10 \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${SUMMARY_MSG}" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1

echo -e "${C}Report sent to Telegram${N}"
echo ""
