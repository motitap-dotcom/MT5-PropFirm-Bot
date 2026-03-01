#!/bin/bash
# =============================================================
# PropFirmBot - Comprehensive Live Bot Verification
# Runs ON the VPS to verify everything is alive and kicking
# Reads credentials from .env if available
# =============================================================

set -o pipefail

echo ""
echo "=============================================="
echo "  PropFirmBot - LIVE VERIFICATION"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "=============================================="
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
LOG_DIR="$MT5_DIR/MQL5/Logs"
TERM_LOG_DIR="$MT5_DIR/logs"
FILES_DIR="$MT5_DIR/MQL5/Files"
CONFIG_DIR="$FILES_DIR/PropFirmBot"

# --- Load .env if exists ---
ENV_FILE=""
for epath in /root/.env /root/MT5-PropFirm-Bot/.env /root/propfirmbot/.env /etc/propfirmbot/.env; do
    if [ -f "$epath" ]; then
        ENV_FILE="$epath"
        echo "[ENV] Loading credentials from $epath"
        set -a
        source "$epath"
        set +a
        break
    fi
done

if [ -z "$ENV_FILE" ]; then
    echo "[ENV] No .env file found, using defaults from script"
fi

# Use env vars or defaults
TG_TOKEN="${TELEGRAM_TOKEN:-${TELEGRAM_BOT_TOKEN:-${TG_TOKEN:-}}}"
TG_CHAT="${TELEGRAM_CHAT_ID:-${TG_CHAT_ID:-${TG_CHAT:-}}}"
ACCOUNT="${MT5_ACCOUNT:-${ACCOUNT_NUMBER:-}}"

echo "[ENV] Telegram Token: ${TG_TOKEN:+SET (${#TG_TOKEN} chars)}${TG_TOKEN:-NOT SET}"
echo "[ENV] Telegram Chat: ${TG_CHAT:-NOT SET}"
echo "[ENV] Account: ${ACCOUNT:-NOT SET}"
echo ""

# Results tracking
PASS=0
FAIL=0
WARN=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

# ==============================================================
# 1. MT5 PROCESS
# ==============================================================
echo "--- 1. MT5 Process ---"
MT5_PID=$(pgrep -f "terminal64" 2>/dev/null | head -1)
if [ -n "$MT5_PID" ]; then
    pass "MT5 is RUNNING (PID: $MT5_PID)"
    MT5_CPU=$(ps -p "$MT5_PID" -o %cpu= 2>/dev/null | tr -d ' ')
    MT5_MEM=$(ps -p "$MT5_PID" -o %mem= 2>/dev/null | tr -d ' ')
    MT5_START=$(ps -p "$MT5_PID" -o lstart= 2>/dev/null)
    echo "       CPU: ${MT5_CPU}% | MEM: ${MT5_MEM}% | Started: $MT5_START"
    MT5_RUNNING=true
else
    fail "MT5 is NOT RUNNING!"
    MT5_RUNNING=false
fi
echo ""

# ==============================================================
# 2. VNC / DISPLAY
# ==============================================================
echo "--- 2. Display & VNC ---"
XVFB_PID=$(pgrep -x "Xvfb" 2>/dev/null)
VNC_PID=$(pgrep -x "x11vnc" 2>/dev/null)
if [ -n "$XVFB_PID" ]; then
    pass "Xvfb display is RUNNING (PID: $XVFB_PID)"
else
    fail "Xvfb display is NOT RUNNING"
fi
if [ -n "$VNC_PID" ]; then
    pass "VNC server is RUNNING (PID: $VNC_PID)"
else
    warn "VNC server is not running (not critical for bot operation)"
fi
echo ""

# ==============================================================
# 3. EA FILES CHECK
# ==============================================================
echo "--- 3. EA Files ---"
if [ -d "$EA_DIR" ]; then
    SRC_COUNT=$(ls "$EA_DIR"/*.mqh "$EA_DIR"/*.mq5 2>/dev/null | wc -l)
    if [ "$SRC_COUNT" -ge 11 ]; then
        pass "All $SRC_COUNT source files present"
    else
        warn "Only $SRC_COUNT source files (expected 11+)"
    fi

    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        EX5_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)
        EX5_DATE=$(stat -c%y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d. -f1)
        pass "PropFirmBot.ex5 compiled (${EX5_SIZE} bytes, $EX5_DATE)"
    else
        fail "PropFirmBot.ex5 NOT FOUND - EA not compiled!"
    fi
else
    fail "EA directory not found: $EA_DIR"
fi
echo ""

# ==============================================================
# 4. CONFIG FILES
# ==============================================================
echo "--- 4. Config Files ---"
if [ -d "$CONFIG_DIR" ]; then
    CONFIGS=$(ls "$CONFIG_DIR"/*.json 2>/dev/null | wc -l)
    if [ "$CONFIGS" -ge 4 ]; then
        pass "$CONFIGS config JSON files present"
        for f in "$CONFIG_DIR"/*.json; do
            FNAME=$(basename "$f")
            if python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
                echo "       $FNAME - valid JSON"
            else
                warn "$FNAME - INVALID JSON!"
            fi
        done
    else
        warn "Only $CONFIGS config files found"
    fi
else
    warn "Config directory not found"
fi
echo ""

# ==============================================================
# 5. STATUS.JSON (EA real-time status)
# ==============================================================
echo "--- 5. EA Status File ---"
STATUS_FILE="$CONFIG_DIR/status.json"
if [ -f "$STATUS_FILE" ]; then
    STATUS_AGE=$(( $(date +%s) - $(stat -c%Y "$STATUS_FILE") ))
    if [ "$STATUS_AGE" -lt 120 ]; then
        pass "status.json is FRESH (${STATUS_AGE}s old)"
    elif [ "$STATUS_AGE" -lt 600 ]; then
        warn "status.json is ${STATUS_AGE}s old (may be stale)"
    else
        fail "status.json is ${STATUS_AGE}s old - EA may not be writing!"
    fi
    echo "       Content:"
    python3 -c "
import json
try:
    with open('$STATUS_FILE') as f:
        d = json.load(f)
    for k,v in d.items():
        print(f'       {k}: {v}')
except Exception as e:
    print(f'       Error reading: {e}')
" 2>/dev/null || cat "$STATUS_FILE" 2>/dev/null | head -20
else
    warn "status.json not found (EA may not write it when market is closed)"
fi
echo ""

# ==============================================================
# 6. MT5 TERMINAL LOGS
# ==============================================================
echo "--- 6. MT5 Terminal Logs ---"
TODAY=$(date '+%Y%m%d')
TERM_LOG="$TERM_LOG_DIR/${TODAY}.log"
if [ -f "$TERM_LOG" ]; then
    TERM_SIZE=$(stat -c%s "$TERM_LOG" 2>/dev/null)
    TERM_AGE=$(( $(date +%s) - $(stat -c%Y "$TERM_LOG") ))
    pass "Today's terminal log exists (${TERM_SIZE} bytes, ${TERM_AGE}s ago)"
    echo "       Last 15 lines:"
    tail -15 "$TERM_LOG" 2>/dev/null | tr -d '\0' | while IFS= read -r line; do
        echo "       $line"
    done
else
    # Check for most recent log
    LATEST=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        warn "No log for today, latest: $(basename $LATEST)"
        tail -10 "$LATEST" 2>/dev/null | tr -d '\0' | while IFS= read -r line; do
            echo "       $line"
        done
    else
        fail "No terminal logs found"
    fi
fi
echo ""

# ==============================================================
# 7. EA (MQL5) LOGS
# ==============================================================
echo "--- 7. EA Logs ---"
EA_LOG="$LOG_DIR/${TODAY}.log"
if [ -f "$EA_LOG" ]; then
    EA_SIZE=$(stat -c%s "$EA_LOG" 2>/dev/null)
    EA_AGE=$(( $(date +%s) - $(stat -c%Y "$EA_LOG") ))
    pass "Today's EA log exists (${EA_SIZE} bytes, ${EA_AGE}s ago)"

    # Check for heartbeat
    HEARTBEAT=$(grep -i "HEARTBEAT\|heartbeat" "$EA_LOG" 2>/dev/null | tail -1)
    if [ -n "$HEARTBEAT" ]; then
        pass "EA HEARTBEAT detected!"
        echo "       Last heartbeat: $HEARTBEAT"
    fi

    # Check for errors
    ERROR_COUNT=$(grep -ci "ERROR\|CRITICAL\|FATAL\|EMERGENCY" "$EA_LOG" 2>/dev/null)
    if [ "$ERROR_COUNT" -gt 0 ]; then
        warn "$ERROR_COUNT error entries in today's log"
        echo "       Last errors:"
        grep -i "ERROR\|CRITICAL\|FATAL\|EMERGENCY" "$EA_LOG" 2>/dev/null | tr -d '\0' | tail -5 | while IFS= read -r line; do
            echo "       $line"
        done
    else
        pass "No errors in today's EA log"
    fi

    # Check for trades
    TRADE_COUNT=$(grep -ci "BUY\|SELL\|OPENED\|CLOSED\|TRADE" "$EA_LOG" 2>/dev/null)
    if [ "$TRADE_COUNT" -gt 0 ]; then
        pass "$TRADE_COUNT trade-related entries today"
    else
        echo "       No trades today (market may be closed)"
    fi

    echo "       Last 20 EA log lines:"
    tail -20 "$EA_LOG" 2>/dev/null | tr -d '\0' | while IFS= read -r line; do
        echo "       $line"
    done
else
    LATEST_EA=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_EA" ]; then
        warn "No EA log for today, latest: $(basename $LATEST_EA)"
        echo "       Last 15 lines from latest EA log:"
        tail -15 "$LATEST_EA" 2>/dev/null | tr -d '\0' | while IFS= read -r line; do
            echo "       $line"
        done
    else
        warn "No EA logs found at all"
    fi
fi
echo ""

# ==============================================================
# 8. TRADE JOURNAL
# ==============================================================
echo "--- 8. Trade Journal ---"
JOURNAL=$(find "$FILES_DIR" -name "*ournal*" -o -name "*trade*csv" 2>/dev/null | head -5)
if [ -n "$JOURNAL" ]; then
    echo "$JOURNAL" | while read jf; do
        JLINES=$(wc -l < "$jf" 2>/dev/null)
        pass "Journal: $(basename $jf) ($JLINES lines)"
        echo "       Last 5 entries:"
        tail -5 "$jf" 2>/dev/null | while IFS= read -r line; do
            echo "       $line"
        done
    done
else
    echo "       No trade journal files (bot may not have traded yet)"
fi
echo ""

# ==============================================================
# 9. NETWORK & MT5 SERVER CONNECTION
# ==============================================================
echo "--- 9. Network & MT5 Connection ---"
# Internet
if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    pass "Internet connectivity OK"
else
    fail "No internet connectivity!"
fi

# DNS
if ping -c 1 -W 3 google.com > /dev/null 2>&1; then
    pass "DNS resolution OK"
else
    warn "DNS resolution failed"
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    echo "       DNS fixed, retrying..."
    ping -c 1 -W 3 google.com > /dev/null 2>&1 && pass "DNS fixed" || fail "DNS still broken"
fi

# MT5 connections (look for trading server connections)
MT5_CONNS=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | wc -l)
echo "       Active outbound connections: $MT5_CONNS"
if [ "$MT5_CONNS" -gt 0 ]; then
    pass "MT5 has active server connections"
    ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -5 | while IFS= read -r line; do
        echo "       $line"
    done
else
    warn "No outbound connections detected (market may be closed)"
fi
echo ""

# ==============================================================
# 10. TELEGRAM BOT
# ==============================================================
echo "--- 10. Telegram Bot ---"
if [ -n "$TG_TOKEN" ]; then
    TG_RESP=$(curl -s --connect-timeout 10 "https://api.telegram.org/bot${TG_TOKEN}/getMe" 2>&1)
    if echo "$TG_RESP" | grep -q '"ok":true'; then
        BOT_NAME=$(echo "$TG_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['first_name'])" 2>/dev/null)
        BOT_USER=$(echo "$TG_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['username'])" 2>/dev/null)
        pass "Telegram Bot ONLINE: $BOT_NAME (@$BOT_USER)"

        # Get recent updates
        UPDATES=$(curl -s --connect-timeout 10 "https://api.telegram.org/bot${TG_TOKEN}/getUpdates?limit=3&offset=-3" 2>&1)
        UPDATE_COUNT=$(echo "$UPDATES" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('result',[])))" 2>/dev/null)
        echo "       Recent updates: $UPDATE_COUNT"

        # Send verification message
        if [ -n "$TG_CHAT" ]; then
            MT5_STATUS="DOWN"; [ "$MT5_RUNNING" = "true" ] && MT5_STATUS="RUNNING"
            EA_STATUS="MISSING"; [ -f "$EA_DIR/PropFirmBot.ex5" ] && EA_STATUS="COMPILED"
            HB_STATUS="N/A"; [ -n "$HEARTBEAT" ] && HB_STATUS="ACTIVE"
            VERIFY_MSG="Bot Verification Report - $(date '+%Y-%m-%d %H:%M UTC')

MT5: ${MT5_STATUS}
EA: ${EA_STATUS}
Heartbeat: ${HB_STATUS}
Errors: ${ERROR_COUNT:-0}
Trades today: ${TRADE_COUNT:-0}
Connections: $MT5_CONNS
Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"

            SEND=$(curl -s --connect-timeout 10 -X POST \
                "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
                -d "chat_id=${TG_CHAT}" \
                -d "text=${VERIFY_MSG}" 2>&1)
            if echo "$SEND" | grep -q '"ok":true'; then
                pass "Verification report sent to Telegram!"
            else
                fail "Could not send Telegram message"
                echo "       Response: $SEND"
            fi
        else
            warn "No chat ID configured - can't send messages"
        fi
    else
        fail "Telegram Bot is NOT reachable"
        echo "       Response: $TG_RESP"
    fi
else
    warn "No Telegram token available (set TELEGRAM_TOKEN in .env)"
fi
echo ""

# ==============================================================
# 11. .ENV FILE CONTENTS (masked)
# ==============================================================
echo "--- 11. Environment File ---"
if [ -n "$ENV_FILE" ]; then
    pass ".env found at $ENV_FILE"
    echo "       Variables defined:"
    grep -v '^#\|^$' "$ENV_FILE" 2>/dev/null | while IFS='=' read -r key val; do
        key=$(echo "$key" | tr -d ' ')
        if [ -n "$key" ]; then
            # Mask sensitive values
            MASKED="${val:0:4}****"
            echo "       $key = $MASKED"
        fi
    done
else
    warn "No .env file found on server"
    echo "       Searched: /root/.env, /root/MT5-PropFirm-Bot/.env, /root/propfirmbot/.env"
fi
echo ""

# ==============================================================
# 12. SYSTEM HEALTH
# ==============================================================
echo "--- 12. System Health ---"
echo "       Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "       CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$((USED_MEM * 100 / TOTAL_MEM))
echo "       Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB (${MEM_PCT}%)"
if [ "$MEM_PCT" -gt 90 ]; then
    fail "Memory usage is CRITICAL (${MEM_PCT}%)"
elif [ "$MEM_PCT" -gt 80 ]; then
    warn "Memory usage is HIGH (${MEM_PCT}%)"
else
    pass "Memory usage OK (${MEM_PCT}%)"
fi
DISK_PCT=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}')
echo "       Disk: ${DISK_PCT}% used (${DISK_AVAIL} free)"
if [ "$DISK_PCT" -gt 90 ]; then
    fail "Disk usage is CRITICAL (${DISK_PCT}%)"
else
    pass "Disk usage OK (${DISK_PCT}%)"
fi
echo ""

# ==============================================================
# 13. SYSTEMD SERVICES
# ==============================================================
echo "--- 13. Services ---"
for svc in xvfb x11vnc mt5; do
    if systemctl is-active "$svc" > /dev/null 2>&1; then
        pass "Service $svc is ACTIVE"
    elif systemctl list-unit-files | grep -q "$svc"; then
        warn "Service $svc exists but is NOT active"
    fi
done
echo ""

# ==============================================================
# SUMMARY
# ==============================================================
echo "=============================================="
echo "  VERIFICATION SUMMARY"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warnings: $WARN"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "  BOT STATUS: ALIVE AND KICKING!"
    FINAL_STATUS="HEALTHY"
elif [ "$FAIL" -le 2 ]; then
    echo "  BOT STATUS: RUNNING WITH ISSUES"
    FINAL_STATUS="WARNING"
else
    echo "  BOT STATUS: NEEDS ATTENTION!"
    FINAL_STATUS="CRITICAL"
fi
echo "=============================================="
echo ""

# Send final summary to Telegram if available
if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT" ]; then
    EMOJI=""; case "$FINAL_STATUS" in HEALTHY) EMOJI="OK";; WARNING) EMOJI="WARN";; *) EMOJI="ALERT";; esac
    MT5_LINE="Down"; [ "$MT5_RUNNING" = "true" ] && MT5_LINE="Running"
    EA_LINE="Missing"; [ -f "$EA_DIR/PropFirmBot.ex5" ] && EA_LINE="Compiled"
    NET_LINE="No connections"; [ "$MT5_CONNS" -gt 0 ] 2>/dev/null && NET_LINE="Connected ($MT5_CONNS)"

    SUMMARY_MSG="[${EMOJI}] PropFirmBot Verification Complete

Status: ${FINAL_STATUS}
Passed: ${PASS} | Failed: ${FAIL} | Warnings: ${WARN}

MT5: ${MT5_LINE}
EA: ${EA_LINE}
Network: ${NET_LINE}
Memory: ${MEM_PCT}%
Disk: ${DISK_PCT}%

Time: $(date '+%Y-%m-%d %H:%M UTC')"

    curl -s --connect-timeout 10 -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT}" \
        -d "text=${SUMMARY_MSG}" > /dev/null 2>&1
fi

echo "VERIFICATION_COMPLETE"
echo "EXIT_STATUS=$FINAL_STATUS"
