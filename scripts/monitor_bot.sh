#!/bin/bash
# Bot health monitor + auto-fixer
# Checks if bot is running and fixes common problems automatically
cd /root/MT5-PropFirm-Bot

TIMESTAMP=$(date -u +'%Y-%m-%d %H:%M:%S UTC')
STATUS="OK"
DETAILS=""
FIXED=""
PYTHON_BIN="/root/MT5-PropFirm-Bot/venv/bin/python3"

# Use system python if venv doesn't exist
[ ! -f "$PYTHON_BIN" ] && PYTHON_BIN="python3"

# ─── FIX 1: Service not running → restart ───
SERVICE_STATE=$(systemctl is-active futures-bot 2>/dev/null || echo "not-found")
if [ "$SERVICE_STATE" = "not-found" ]; then
    # Service doesn't exist at all - install it
    FIXED="${FIXED} | Installed service"
    cat > /etc/systemd/system/futures-bot.service << SERVICEEOF
[Unit]
Description=TradeDay Futures Trading Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/MT5-PropFirm-Bot
ExecStart=${PYTHON_BIN} -m futures_bot.bot
Restart=on-failure
RestartSec=30
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/root/MT5-PropFirm-Bot/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF
    systemctl daemon-reload
    systemctl enable futures-bot
    systemctl start futures-bot
    sleep 10
    SERVICE_STATE=$(systemctl is-active futures-bot 2>/dev/null)
elif [ "$SERVICE_STATE" != "active" ]; then
    # Service exists but not running - restart
    FIXED="${FIXED} | Restarted service"
    systemctl restart futures-bot 2>/dev/null
    sleep 10
    SERVICE_STATE=$(systemctl is-active futures-bot 2>/dev/null)
fi

if [ "$SERVICE_STATE" != "active" ]; then
    STATUS="DOWN"
    DETAILS="Service: ${SERVICE_STATE} after fix attempt"
fi

# ─── FIX 2: Dependencies missing → install ───
if [ -f logs/bot.log ]; then
    if tail -10 logs/bot.log | grep -q "ModuleNotFoundError\|No module named"; then
        FIXED="${FIXED} | Reinstalled dependencies"
        if [ -f venv/bin/pip ]; then
            venv/bin/pip install -r requirements.txt > /dev/null 2>&1
        else
            python3 -m venv venv 2>/dev/null
            venv/bin/pip install -r requirements.txt > /dev/null 2>&1
        fi
        systemctl restart futures-bot 2>/dev/null
        sleep 10
    fi
fi

# ─── FIX 3: Token expired → try renewal from saved token ───
if [ -f logs/bot.log ]; then
    if tail -20 logs/bot.log | grep -q "CAPTCHA\|Expired Access Token"; then
        # Check if saved token file exists - try to renew it
        if [ -f configs/.tradovate_token.json ] || [ -f configs/.tradovate_token_backup.json ]; then
            FIXED="${FIXED} | Attempting token renewal"
            $PYTHON_BIN -c "
import sys, os, asyncio, json
sys.path.insert(0, '/root/MT5-PropFirm-Bot')
with open('.env') as f:
    for line in f:
        if '=' in line:
            k, v = line.strip().split('=', 1)
            os.environ[k] = v
from futures_bot.core.tradovate_client import TradovateClient
async def fix():
    c = TradovateClient(
        username=os.environ.get('TRADOVATE_USER', ''),
        password=os.environ.get('TRADOVATE_PASS', ''),
        live=False, organization='TradeDay')
    try:
        await c.connect()
        print(f'Token renewed OK: {c.account_spec}')
        await c.disconnect()
        return True
    except Exception as e:
        print(f'Token renewal failed: {e}')
        return False
asyncio.run(fix())
" 2>&1
            # Restart bot with hopefully renewed token
            systemctl restart futures-bot 2>/dev/null
            sleep 10
            # Check if CAPTCHA error persists
            if tail -5 logs/bot.log | grep -q "CAPTCHA"; then
                STATUS="CAPTCHA"
                DETAILS="CAPTCHA required - needs manual token refresh"
            else
                FIXED="${FIXED} | Token renewed successfully"
            fi
        else
            STATUS="CAPTCHA"
            DETAILS="Token expired, no saved token to renew"
        fi
    fi
fi

# ─── FIX 4: .env missing or empty → warn ───
if [ ! -f .env ] || [ ! -s .env ]; then
    STATUS="NO_ENV"
    DETAILS="Missing .env file with credentials"
fi

# ─── FIX 5: Log file too big → rotate ───
if [ -f logs/bot.log ]; then
    LOG_SIZE=$(stat -c %s logs/bot.log 2>/dev/null || echo 0)
    if [ "$LOG_SIZE" -gt 52428800 ]; then  # > 50MB
        mv logs/bot.log logs/bot.log.old
        FIXED="${FIXED} | Rotated large log (${LOG_SIZE} bytes)"
        systemctl restart futures-bot 2>/dev/null
    fi
fi

# ─── CHECK: Log freshness ───
if [ -f logs/bot.log ] && [ "$STATUS" = "OK" ]; then
    LAST_MOD=$(stat -c %Y logs/bot.log 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE=$(( NOW - LAST_MOD ))
    if [ "$AGE" -gt 600 ]; then
        STATUS="STALE"
        DETAILS="${DETAILS} | Log not updated for ${AGE}s"
        # Try restart
        FIXED="${FIXED} | Restarted stale bot"
        systemctl restart futures-bot 2>/dev/null
    fi

    # Check for recent errors (only if not already an error status)
    RECENT_ERRORS=$(tail -20 logs/bot.log | grep -c "ERROR\|Fatal\|Max retries")
    if [ "$RECENT_ERRORS" -gt 3 ]; then
        STATUS="ERROR"
        LAST_ERROR=$(tail -20 logs/bot.log | grep "ERROR\|Fatal" | tail -1)
        DETAILS="${DETAILS} | Errors: ${LAST_ERROR}"
    fi

    # What is the bot doing right now?
    LAST_LINES=$(tail -5 logs/bot.log)
    if echo "$LAST_LINES" | grep -q "TRADE:"; then
        DETAILS="${DETAILS} | TRADING"
    elif echo "$LAST_LINES" | grep -q "Main loop"; then
        DETAILS="${DETAILS} | Active - scanning"
    elif echo "$LAST_LINES" | grep -q "Outside trading session"; then
        DETAILS="${DETAILS} | Waiting for session"
    elif echo "$LAST_LINES" | grep -q "Bot started"; then
        DETAILS="${DETAILS} | Just started"
    fi
fi

# ─── CHECK: Guardian & Balance from status.json ───
if [ -f status/status.json ]; then
    GUARDIAN=$($PYTHON_BIN -c "import json; d=json.load(open('status/status.json')); print(d.get('guardian',{}).get('state','?'))" 2>/dev/null)
    BALANCE=$($PYTHON_BIN -c "import json; d=json.load(open('status/status.json')); print(d.get('guardian',{}).get('balance','?'))" 2>/dev/null)
    DAILY_PNL=$($PYTHON_BIN -c "import json; d=json.load(open('status/status.json')); print(d.get('guardian',{}).get('daily_pnl','?'))" 2>/dev/null)
    if [ -n "$GUARDIAN" ] && [ "$GUARDIAN" != "?" ]; then
        DETAILS="${DETAILS} | Guardian: ${GUARDIAN} | Bal: \$${BALANCE} | Daily: \$${DAILY_PNL}"
    fi
fi

# ─── Summary ───
[ -n "$FIXED" ] && DETAILS="${DETAILS} | AUTO-FIXED:${FIXED}"

echo "${TIMESTAMP} | Status: ${STATUS} | ${DETAILS}"

echo "BOT_STATUS=${STATUS}" > /tmp/bot_monitor_result.txt
echo "BOT_DETAILS=${DETAILS}" >> /tmp/bot_monitor_result.txt
echo "BOT_TIMESTAMP=${TIMESTAMP}" >> /tmp/bot_monitor_result.txt
