#!/bin/bash
# VPS Management Script for PropFirmBot
# Usage: bash vps_manage.sh [status|restart-mt5|view-trades|view-balance]

ACTION="${1:-status}"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date '+%Y%m%d')

echo "=== PropFirmBot | $(echo $ACTION | tr '[:lower:]' '[:upper:]') | $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
echo ""

case "$ACTION" in

  status)
    echo "--- MT5 Process ---"
    if ps aux | grep -q "[t]erminal64"; then
        echo "MT5: RUNNING ✅"
        ps aux | grep "[t]erminal64" | awk '{print "  PID:"$2, "CPU:"$3"%", "MEM:"$4"%"}'
    else
        echo "MT5: NOT RUNNING ❌"
    fi

    echo ""
    echo "--- Connections ---"
    CONNS=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | wc -l)
    echo "Active connections: $CONNS"
    ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -5

    echo ""
    echo "--- EA Status ---"
    EALOG="$MT5/MQL5/Logs/${TODAY}.log"
    if [ -f "$EALOG" ]; then
        echo "EA Log: EXISTS ✅ ($(stat -c%s "$EALOG") bytes)"
        echo "Last 10 lines:"
        cat "$EALOG" | tr -d '\0' | tail -10
    else
        echo "No EA log today"
        echo "Latest:"
        ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -3
    fi

    echo ""
    echo "--- Server Health ---"
    df -h / | tail -1 | awk '{print "Disk: "$3" / "$2" ("$5" used)"}'
    free -h | grep Mem | awk '{print "RAM: "$3" / "$2}'
    uptime | awk -F'load average:' '{print "Load:"$2}'
    ;;

  restart-mt5)
    echo "--- Stopping MT5 ---"
    pkill -f terminal64 2>/dev/null
    sleep 3

    if ps aux | grep -q "[t]erminal64"; then
        echo "MT5 still running, force killing..."
        pkill -9 -f terminal64 2>/dev/null
        sleep 2
    fi
    echo "MT5 stopped ✅"

    echo ""
    echo "--- Starting MT5 ---"
    export DISPLAY=:99
    export WINEPREFIX=/root/.wine

    # Make sure Xvfb is running
    if ! ps aux | grep -q "[X]vfb"; then
        Xvfb :99 -screen 0 1280x1024x24 &
        sleep 2
    fi

    cd "$MT5"
    wine terminal64.exe /portable &
    sleep 5

    if ps aux | grep -q "[t]erminal64"; then
        echo "MT5 restarted successfully ✅"
        ps aux | grep "[t]erminal64" | awk '{print "  PID:"$2, "CPU:"$3"%", "MEM:"$4"%"}'
    else
        echo "MT5 failed to start ❌"
    fi
    ;;

  view-trades)
    echo "--- Open Trades ---"
    EALOG="$MT5/MQL5/Logs/${TODAY}.log"
    if [ -f "$EALOG" ]; then
        # Look for trade entries
        cat "$EALOG" | tr -d '\0' | grep -i "order\|trade\|position\|open\|close\|buy\|sell" | tail -20
        echo ""
        TRADE_COUNT=$(cat "$EALOG" | tr -d '\0' | grep -ci "order sent\|position opened\|trade opened" 2>/dev/null || echo "0")
        echo "Trade signals today: $TRADE_COUNT"
    else
        echo "No EA log for today"
    fi

    echo ""
    echo "--- Recent EA Activity ---"
    # Check last 3 days of logs
    for i in 0 1 2; do
        LOGDATE=$(date -d "-${i} days" '+%Y%m%d' 2>/dev/null || date -v-${i}d '+%Y%m%d' 2>/dev/null)
        LOGFILE="$MT5/MQL5/Logs/${LOGDATE}.log"
        if [ -f "$LOGFILE" ]; then
            SIGNALS=$(cat "$LOGFILE" | tr -d '\0' | grep -ci "signal\|order\|trade" 2>/dev/null || echo "0")
            SIZE=$(stat -c%s "$LOGFILE" 2>/dev/null || echo "0")
            echo "  ${LOGDATE}: ${SIZE} bytes, ${SIGNALS} trade-related entries"
        fi
    done
    ;;

  view-balance)
    echo "--- Account Info ---"
    EALOG="$MT5/MQL5/Logs/${TODAY}.log"
    if [ -f "$EALOG" ]; then
        # Look for balance/equity info
        cat "$EALOG" | tr -d '\0' | grep -i "balance\|equity\|profit\|drawdown\|DD\|account\|Bal=" | tail -15
    else
        echo "No EA log for today - checking recent logs..."
        for i in 0 1 2 3; do
            LOGDATE=$(date -d "-${i} days" '+%Y%m%d' 2>/dev/null || date -v-${i}d '+%Y%m%d' 2>/dev/null)
            LOGFILE="$MT5/MQL5/Logs/${LOGDATE}.log"
            if [ -f "$LOGFILE" ]; then
                echo "From ${LOGDATE}:"
                cat "$LOGFILE" | tr -d '\0' | grep -i "balance\|equity\|profit\|drawdown\|DD\|Bal=" | tail -10
                break
            fi
        done
    fi

    echo ""
    echo "--- Guardian Status ---"
    if [ -f "$EALOG" ]; then
        cat "$EALOG" | tr -d '\0' | grep -i "guardian\|GUARDIAN" | tail -5
    fi

    echo ""
    echo "--- Trade Journal Files ---"
    ls -lt "$MT5/MQL5/Files/PropFirmBot/"*Journal* 2>/dev/null | head -5
    LATEST_JOURNAL=$(ls -t "$MT5/MQL5/Files/PropFirmBot/"*Journal* 2>/dev/null | head -1)
    if [ -n "$LATEST_JOURNAL" ]; then
        echo ""
        echo "Latest journal entries:"
        tail -5 "$LATEST_JOURNAL"
    fi
    ;;

  *)
    echo "Unknown action: $ACTION"
    echo "Available: status, restart-mt5, view-trades, view-balance"
    ;;
esac

echo ""
echo "=== DONE ==="
