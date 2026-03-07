#!/bin/bash
###############################################################################
# MT5 Watchdog - Auto-recovery script
# Runs every 2 minutes via cron. Checks MT5 health and fixes issues.
#
# Checks:
# 1. Xvfb + VNC running
# 2. MT5 process running → restart if down
# 3. Account connected → restart if stuck
# 4. AutoTrading enabled → toggle if disabled
# 5. EA producing heartbeats → reattach if missing
#
# Log: /var/log/mt5_watchdog.log
###############################################################################

LOG="/var/log/mt5_watchdog.log"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
CHART="$MT5/MQL5/Profiles/Charts/Default/chart01.chr"
LOCKFILE="/tmp/mt5_watchdog.lock"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Prevent concurrent runs
if [ -f "$LOCKFILE" ]; then
    LOCK_AGE=$(($(date +%s) - $(stat -c %Y "$LOCKFILE" 2>/dev/null || echo 0)))
    if [ "$LOCK_AGE" -lt 180 ]; then
        exit 0
    fi
    rm -f "$LOCKFILE"
fi
echo $$ > "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $1" >> "$LOG"
}

# Trim log if too long
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 1000 ]; then
    tail -500 "$LOG" > /tmp/watchdog_trim.log
    mv /tmp/watchdog_trim.log "$LOG"
fi

###############################################################################
# Functions (defined before use)
###############################################################################

fix_chart_file() {
    log "Fixing chart file..."
    CONTENT=$(cat "$CHART" 2>/dev/null | tr -d '\0')

    if ! echo "$CONTENT" | grep -q "PropFirmBot"; then
        log "EA missing from chart - creating fresh chart file"
        cat > /tmp/chart01_fresh.chr << 'CHREOF'
<chart>
id=0
symbol=EURUSD
period_type=0
period_size=15
digits=5
<expert>
name=PropFirmBot
path=Experts\PropFirmBot\PropFirmBot.ex5
expertmode=3
<inputs>
InpMagicNumber=202502
InpTradeComment=PFBot
InpAccountPhase=1
InpAccountSize=2000
InpProfitTarget=0
InpHardDailyDD=0
InpHardTotalDD=6.0
InpChallengeMode=false
InpMinTradingDays=0
InpFundedDailyDD=0
InpFundedTotalDD=6.0
InpFundedProfitSplit=70.0
InpStrategy=1
InpUseFallback=true
InpEntryTF=16385
InpHTF=16388
InpRiskPercent=0.75
InpMaxPositions=3
InpMinRR=1.5
InpMaxDailyTrades=12
InpTelegramToken=8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
InpTelegramChatId=7013213983
InpAutoBlockSymbol=true
</inputs>
</expert>
expertmode=3
</chart>
CHREOF
        printf '\xff\xfe' > "$CHART"
        iconv -f UTF-8 -t UTF-16LE /tmp/chart01_fresh.chr >> "$CHART" 2>/dev/null
    else
        echo "$CONTENT" | sed 's/expertmode=0/expertmode=3/g' > /tmp/chart01_fix.chr
        printf '\xff\xfe' > "$CHART"
        iconv -f UTF-8 -t UTF-16LE /tmp/chart01_fix.chr >> "$CHART" 2>/dev/null
    fi
    log "Chart file fixed."
}

enable_autotrading() {
    if [ -f "/root/.wine/drive_c/at_keybd.exe" ]; then
        wine "C:\\at_keybd.exe" 2>/dev/null
        sleep 3
        log "AutoTrading toggle sent (at_keybd.exe)"
    else
        MT5_WIN=$(xdotool search --name "MetaTrader\|FundedNext" 2>/dev/null | head -1)
        if [ -n "$MT5_WIN" ]; then
            xdotool windowactivate "$MT5_WIN" 2>/dev/null
            sleep 1
            xdotool key ctrl+e 2>/dev/null
            sleep 2
            log "AutoTrading toggle sent (xdotool)"
        else
            log "WARNING: Cannot find MT5 window to enable AutoTrading"
            return
        fi
    fi

    # Verify
    sleep 2
    EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    LAST_AT=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1)
    if echo "$LAST_AT" | grep -q "disabled"; then
        log "Still DISABLED after first toggle - sending second toggle..."
        if [ -f "/root/.wine/drive_c/at_keybd.exe" ]; then
            wine "C:\\at_keybd.exe" 2>/dev/null
        else
            xdotool key ctrl+e 2>/dev/null
        fi
        sleep 3
    fi
}

start_mt5() {
    log "Starting MT5..."
    pkill -9 -f "terminal64\|start.exe" 2>/dev/null
    screen -X -S mt5 quit 2>/dev/null
    sleep 3

    fix_chart_file

    cd "$MT5"
    screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
    log "MT5 started. Waiting 35s for login..."
    sleep 35

    enable_autotrading
    log "MT5 start complete."
}

is_market_open() {
    DOW=$(date -u +%u)   # 1=Mon ... 7=Sun
    HOUR=$(date -u +%H)
    # Market closed: Friday 22:00 UTC → Sunday 22:00 UTC
    if [ "$DOW" -eq 6 ]; then echo "no"; return; fi
    if [ "$DOW" -eq 7 ] && [ "$HOUR" -lt 22 ]; then echo "no"; return; fi
    if [ "$DOW" -eq 5 ] && [ "$HOUR" -ge 22 ]; then echo "no"; return; fi
    echo "yes"
}

###############################################################################
# Main checks
###############################################################################

# Check 1: Xvfb
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    log "XVFB DOWN - Starting..."
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi

# Check 2: x11vnc
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    log "VNC DOWN - Starting..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
fi

# Check 3: MT5 process
MT5_RUNNING=false
if ps aux | grep -v grep | grep -qi "terminal64.exe"; then
    MT5_RUNNING=true
fi

if [ "$MT5_RUNNING" = false ]; then
    log "MT5 DOWN - Restarting..."
    start_mt5
    exit 0
fi

# Check 4: Account connected (window title has account number)
ACCOUNT_CONNECTED=false
for WID in $(xdotool search --name "11797849" 2>/dev/null); do
    ACCOUNT_CONNECTED=true
    break
done

if [ "$ACCOUNT_CONNECTED" = false ]; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    if [ -n "$MT5_PID" ]; then
        MT5_START=$(stat -c %Y /proc/$MT5_PID 2>/dev/null || echo $(date +%s))
        MT5_AGE=$(( $(date +%s) - MT5_START ))
        if [ "$MT5_AGE" -gt 120 ]; then
            log "ACCOUNT NOT CONNECTED after ${MT5_AGE}s - Restarting..."
            start_mt5
        else
            log "Account loading... (${MT5_AGE}s since start)"
        fi
    fi
    exit 0
fi

# Check 5: AutoTrading enabled
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EALOG" ]; then
    LAST_AT=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1)
    if echo "$LAST_AT" | grep -q "disabled"; then
        log "AUTOTRADING DISABLED - Enabling..."
        enable_autotrading
    fi
fi

# Check 6: EA heartbeat (only when market is open)
if [ "$(is_market_open)" = "yes" ] && [ -n "$EALOG" ]; then
    LAST_HB=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "HEARTBEAT" | tail -1)
    if [ -n "$LAST_HB" ]; then
        HB_TIME=$(echo "$LAST_HB" | grep -oP '\d{2}:\d{2}:\d{2}' | head -1)
        NOW_TIME=$(date -u '+%H:%M:%S')
        HB_SEC=$(echo "$HB_TIME" | awk -F: '{print $1*3600+$2*60+$3}')
        NOW_SEC=$(echo "$NOW_TIME" | awk -F: '{print $1*3600+$2*60+$3}')
        DIFF=$((NOW_SEC - HB_SEC))
        [ "$DIFF" -lt 0 ] && DIFF=$((DIFF + 86400))

        if [ "$DIFF" -gt 900 ]; then
            log "NO HEARTBEAT for ${DIFF}s - EA not active. Full restart..."
            start_mt5
            exit 0
        fi
    else
        # No heartbeat at all - EA probably not attached
        log "NO HEARTBEAT ENTRIES - EA not attached. Full restart..."
        start_mt5
        exit 0
    fi
fi

# All good - log only every 10 minutes (to keep log clean)
MINUTE=$(date -u +%M)
if [ "$((MINUTE % 10))" -eq 0 ]; then
    EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    LAST_HB=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "HEARTBEAT" | tail -1)
    BAL=$(echo "$LAST_HB" | grep -oP 'Bal=\$[\d.]+' || echo "?")
    POS=$(echo "$LAST_HB" | grep -oP 'Positions=\d+' || echo "?")
    log "OK - MT5 running | Account connected | $BAL | $POS"
fi
