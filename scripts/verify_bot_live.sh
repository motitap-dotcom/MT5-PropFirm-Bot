#!/bin/bash
#=============================================================================
# PropFirmBot - בדיקת בוט חי מקיפה
# מריצים על ה-VPS: bash verify_bot_live.sh
# בודק הכל ושולח דו"ח מלא לטלגרם
#=============================================================================

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date '+%Y%m%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC')

# Colors for terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  PropFirmBot - Full Health Check${NC}"
echo -e "${CYAN}  $TIMESTAMP${NC}"
echo -e "${CYAN}========================================${NC}"

REPORT=""
ISSUES=0
TOTAL_CHECKS=0

check() {
    local name="$1"
    local status="$2"
    local detail="$3"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ "$status" = "OK" ]; then
        echo -e "  ${GREEN}[OK]${NC} $name: $detail"
        REPORT="${REPORT}\n✅ ${name}: ${detail}"
    elif [ "$status" = "WARN" ]; then
        echo -e "  ${YELLOW}[!]${NC} $name: $detail"
        REPORT="${REPORT}\n⚠️ ${name}: ${detail}"
    else
        echo -e "  ${RED}[X]${NC} $name: $detail"
        REPORT="${REPORT}\n❌ ${name}: ${detail}"
        ISSUES=$((ISSUES + 1))
    fi
}

# =============================================
# 1. MT5 PROCESS
# =============================================
echo ""
echo -e "${YELLOW}[1/8] MT5 Process...${NC}"
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null)
if [ -n "$MT5_PID" ]; then
    MT5_UPTIME=$(ps -p "$MT5_PID" -o etime= 2>/dev/null | xargs)
    check "MT5 Process" "OK" "Running (PID: $MT5_PID, uptime: $MT5_UPTIME)"
else
    check "MT5 Process" "FAIL" "NOT RUNNING!"
fi

# =============================================
# 2. VNC & DISPLAY
# =============================================
echo ""
echo -e "${YELLOW}[2/8] Display & VNC...${NC}"
XVFB_PID=$(pgrep -f "Xvfb" 2>/dev/null)
if [ -n "$XVFB_PID" ]; then
    check "Xvfb Display" "OK" "Running (PID: $XVFB_PID)"
else
    check "Xvfb Display" "FAIL" "NOT RUNNING"
fi

VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null)
if [ -n "$VNC_PID" ]; then
    check "VNC Server" "OK" "Running (PID: $VNC_PID, port 5900)"
else
    check "VNC Server" "WARN" "NOT RUNNING"
fi

# =============================================
# 3. NETWORK CONNECTIONS (MT5 to Broker)
# =============================================
echo ""
echo -e "${YELLOW}[3/8] Network Connections...${NC}"
BROKER_CONN=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | grep -v "127.0.0.1" | wc -l)
if [ "$BROKER_CONN" -gt 0 ]; then
    CONN_DETAILS=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | grep -v "127.0.0.1" | head -3 | awk '{print $4 " -> " $5}')
    check "Broker Connection" "OK" "$BROKER_CONN active connections"
else
    check "Broker Connection" "FAIL" "No outbound connections (MT5 not connected to broker)"
fi

# Internet check
if ping -c1 -W3 8.8.8.8 > /dev/null 2>&1; then
    check "Internet" "OK" "Connected"
else
    check "Internet" "FAIL" "No internet connection!"
fi

# =============================================
# 4. EA FILES
# =============================================
echo ""
echo -e "${YELLOW}[4/8] EA Files...${NC}"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    MQ5_COUNT=$(ls "$EA_DIR"/*.mq5 2>/dev/null | wc -l)
    MQH_COUNT=$(ls "$EA_DIR"/*.mqh 2>/dev/null | wc -l)
    EX5_COUNT=$(ls "$EA_DIR"/*.ex5 2>/dev/null | wc -l)
    check "EA Source Files" "OK" "$MQ5_COUNT .mq5 + $MQH_COUNT .mqh files"
    if [ "$EX5_COUNT" -gt 0 ]; then
        EX5_SIZE=$(stat -c%s "$EA_DIR"/*.ex5 2>/dev/null | head -1)
        EX5_DATE=$(stat -c%y "$EA_DIR"/*.ex5 2>/dev/null | head -1 | cut -d. -f1)
        check "EA Compiled" "OK" "PropFirmBot.ex5 ($EX5_SIZE bytes, $EX5_DATE)"
    else
        check "EA Compiled" "FAIL" "No .ex5 file found - EA not compiled!"
    fi
else
    check "EA Files" "FAIL" "EA directory not found at $EA_DIR"
fi

# Config files
CONFIG_DIR="$MT5/MQL5/Files/PropFirmBot"
if [ -d "$CONFIG_DIR" ]; then
    JSON_COUNT=$(ls "$CONFIG_DIR"/*.json 2>/dev/null | wc -l)
    check "Config Files" "OK" "$JSON_COUNT JSON files in $CONFIG_DIR"
else
    check "Config Files" "WARN" "Config directory not found"
fi

# =============================================
# 5. EA LOGS (Is EA actually running?)
# =============================================
echo ""
echo -e "${YELLOW}[5/8] EA Activity...${NC}"

# Check today's EA log
EA_LOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EA_LOG" ]; then
    EA_LOG_SIZE=$(stat -c%s "$EA_LOG" 2>/dev/null)
    EA_LOG_MOD=$(stat -c%y "$EA_LOG" 2>/dev/null | cut -d. -f1)
    EA_LINES=$(cat "$EA_LOG" | tr -d '\0' | wc -l)
    check "EA Log Today" "OK" "$EA_LINES lines, last modified: $EA_LOG_MOD"

    # Check for recent EA activity (last 5 minutes)
    RECENT=$(find "$EA_LOG" -mmin -5 2>/dev/null)
    if [ -n "$RECENT" ]; then
        check "EA Recent Activity" "OK" "Log updated in last 5 min"
    else
        LAST_MOD_MIN=$(( ($(date +%s) - $(stat -c%Y "$EA_LOG")) / 60 ))
        check "EA Recent Activity" "WARN" "No activity for ${LAST_MOD_MIN} min"
    fi

    # Last EA messages
    LAST_EA_MSGS=$(cat "$EA_LOG" | tr -d '\0' | tail -5)
    echo -e "  ${CYAN}Last EA messages:${NC}"
    echo "$LAST_EA_MSGS" | while read line; do echo "    $line"; done

    # Check for errors
    EA_ERRORS=$(cat "$EA_LOG" | tr -d '\0' | grep -ic "error" 2>/dev/null || echo "0")
    if [ "$EA_ERRORS" -gt 0 ]; then
        check "EA Errors" "WARN" "$EA_ERRORS error(s) in today's log"
    fi
else
    # Check most recent EA log
    LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        LATEST_DATE=$(basename "$LATEST_LOG" .log)
        check "EA Log Today" "WARN" "No log for today. Last log: $LATEST_DATE"
    else
        check "EA Log Today" "FAIL" "No EA logs found at all!"
    fi
fi

# Terminal log
TERM_LOG="$MT5/logs/${TODAY}.log"
if [ -f "$TERM_LOG" ]; then
    TERM_SIZE=$(stat -c%s "$TERM_LOG" 2>/dev/null)
    check "Terminal Log" "OK" "Size: $TERM_SIZE bytes"

    # Check for connection/login messages
    LOGIN_MSG=$(cat "$TERM_LOG" | tr -d '\0' | grep -i "authorized\|logged\|connected" | tail -1)
    if [ -n "$LOGIN_MSG" ]; then
        check "Account Login" "OK" "$LOGIN_MSG"
    else
        FAIL_MSG=$(cat "$TERM_LOG" | tr -d '\0' | grep -i "failed\|invalid\|error\|refused" | tail -1)
        if [ -n "$FAIL_MSG" ]; then
            check "Account Login" "FAIL" "$FAIL_MSG"
        fi
    fi
else
    check "Terminal Log" "WARN" "No terminal log for today"
fi

# =============================================
# 6. STATUS.JSON (EA Status File)
# =============================================
echo ""
echo -e "${YELLOW}[6/8] EA Status File...${NC}"
STATUS_FILE="$MT5/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    STATUS_MOD=$(stat -c%y "$STATUS_FILE" 2>/dev/null | cut -d. -f1)
    STATUS_SIZE=$(stat -c%s "$STATUS_FILE" 2>/dev/null)
    check "Status JSON" "OK" "Exists ($STATUS_SIZE bytes, updated: $STATUS_MOD)"

    # Parse status info
    BALANCE=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"balance": [0-9.]*' | head -1 | awk '{print $2}')
    EQUITY=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"equity": [0-9.]*' | head -1 | awk '{print $2}')
    GUARDIAN=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"state": "[^"]*"' | head -1 | awk -F'"' '{print $4}')
    TOTAL_DD=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"total_dd": [0-9.]*' | head -1 | awk '{print $2}')
    POS_COUNT=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"count": [0-9]*' | head -1 | awk '{print $2}')
    CAN_TRADE=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"can_trade": [a-z]*' | head -1 | awk '{print $2}')

    if [ -n "$BALANCE" ]; then
        echo -e "  ${CYAN}Account Status:${NC}"
        echo -e "    Balance:  \$$BALANCE"
        echo -e "    Equity:   \$$EQUITY"
        echo -e "    Guardian: $GUARDIAN"
        echo -e "    Total DD: ${TOTAL_DD}%"
        echo -e "    Positions: $POS_COUNT"
        echo -e "    Can Trade: $CAN_TRADE"

        REPORT="${REPORT}\n\n📊 Account: \$${BALANCE} | Equity: \$${EQUITY}"
        REPORT="${REPORT}\n🛡 Guardian: ${GUARDIAN} | DD: ${TOTAL_DD}%"
        REPORT="${REPORT}\n📈 Positions: ${POS_COUNT} | Trade: ${CAN_TRADE}"
    fi

    # Check if status is fresh
    STATUS_AGE=$(( ($(date +%s) - $(stat -c%Y "$STATUS_FILE")) / 60 ))
    if [ "$STATUS_AGE" -lt 5 ]; then
        check "Status Freshness" "OK" "Updated ${STATUS_AGE} min ago"
    else
        check "Status Freshness" "WARN" "Status is ${STATUS_AGE} min old"
    fi
else
    check "Status JSON" "WARN" "Not found (EA may not have written it yet)"
fi

# =============================================
# 7. SYSTEM HEALTH
# =============================================
echo ""
echo -e "${YELLOW}[7/8] System Health...${NC}"
CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.1f", $2}' || echo "N/A")
RAM_USED=$(free -m 2>/dev/null | awk '/Mem:/{print $3}')
RAM_TOTAL=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')
RAM_PCT=$(free 2>/dev/null | awk '/Mem/{printf "%.0f", $3/$2*100}')
DISK_PCT=$(df / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
UPTIME=$(uptime -p 2>/dev/null)

check "CPU Usage" "OK" "${CPU}%"
if [ "$RAM_PCT" -gt 90 ]; then
    check "RAM Usage" "WARN" "${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}%)"
else
    check "RAM Usage" "OK" "${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}%)"
fi
if [ "$DISK_PCT" -gt 85 ]; then
    check "Disk Usage" "WARN" "${DISK_PCT}%"
else
    check "Disk Usage" "OK" "${DISK_PCT}%"
fi
check "Uptime" "OK" "$UPTIME"

REPORT="${REPORT}\n\n💻 CPU: ${CPU}% | RAM: ${RAM_PCT}% | Disk: ${DISK_PCT}%"
REPORT="${REPORT}\n⏱ ${UPTIME}"

# =============================================
# 8. TELEGRAM CONNECTION TEST
# =============================================
echo ""
echo -e "${YELLOW}[8/8] Telegram Connection...${NC}"
TG_TEST=$(curl -s --connect-timeout 5 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe" 2>&1)
if echo "$TG_TEST" | grep -q '"ok":true'; then
    BOT_NAME=$(echo "$TG_TEST" | grep -o '"first_name":"[^"]*"' | awk -F'"' '{print $4}')
    check "Telegram Bot" "OK" "Connected ($BOT_NAME)"
else
    check "Telegram Bot" "FAIL" "Cannot reach Telegram API"
fi

# =============================================
# SUMMARY
# =============================================
echo ""
echo -e "${CYAN}========================================${NC}"
if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}  ALL CHECKS PASSED! ($TOTAL_CHECKS/$TOTAL_CHECKS)${NC}"
    echo -e "${GREEN}  Bot is ALIVE and KICKING! 🚀${NC}"
    HEADER="✅ PropFirmBot - הכל תקין!"
else
    echo -e "${RED}  $ISSUES ISSUE(S) FOUND ($((TOTAL_CHECKS - ISSUES))/$TOTAL_CHECKS passed)${NC}"
    HEADER="⚠️ PropFirmBot - נמצאו $ISSUES בעיות"
fi
echo -e "${CYAN}========================================${NC}"

# =============================================
# SEND TO TELEGRAM
# =============================================
echo ""
echo -e "${YELLOW}Sending report to Telegram...${NC}"

TG_MSG="<b>${HEADER}</b>
<pre>$(date '+%d/%m/%Y %H:%M UTC')</pre>
$(echo -e "$REPORT")"

RESULT=$(curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${TG_MSG}" \
    -d "parse_mode=HTML" \
    2>&1)

if echo "$RESULT" | grep -q '"ok":true'; then
    echo -e "${GREEN}[OK] Report sent to Telegram!${NC}"
else
    echo -e "${RED}[FAIL] Could not send to Telegram${NC}"
    echo "$RESULT"
fi

echo ""
echo -e "${CYAN}Done! Check your Telegram for the full report.${NC}"
