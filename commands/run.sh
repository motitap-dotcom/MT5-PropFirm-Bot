#!/bin/bash
# Deep diagnostic - check why bot not trading
echo "=== DEEP DIAGNOSTIC $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
TERM_LOG_DIR="${MT5_BASE}/logs"

# 1. INIT log entries - shows actual running parameters
echo "--- INIT LOG ENTRIES (actual EA parameters) ---"
EA_LATEST=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    echo "Log file: $EA_LATEST ($(wc -l < "$EA_LATEST") lines)"
    # Get INIT entries
    strings "$EA_LATEST" | grep -i "\[INIT\]\|Init:\|STARTUP\|ALL SYSTEMS\|Risk multiplier\|Symbols\|Phase:" | head -30
fi

# 2. Check ALL NEWBAR entries - are they hourly or every 15 min?
echo ""
echo "--- ALL NEWBAR entries today (first 60) ---"
if [ -n "$EA_LATEST" ]; then
    strings "$EA_LATEST" | grep "NEWBAR" | head -60
fi

# 3. Check ALL SCAN/SIGNAL entries - any signals at all?
echo ""
echo "--- ALL SCAN/SIGNAL entries today ---"
if [ -n "$EA_LATEST" ]; then
    strings "$EA_LATEST" | grep -i "\[SCAN\]\|\[SMC\]\|\[EMA\]\|\[SIGNAL\]\|\[TRADE\]\|BUY\|SELL\|NO SIGNAL\|no H4 bias\|bullish bias\|bearish bias\|no OB/FVG" | head -60
fi

# 4. Check session filter entries
echo ""
echo "--- SESSION FILTER details ---"
if [ -n "$EA_LATEST" ]; then
    strings "$EA_LATEST" | grep -i "session\|Outside\|BLOCKED" | head -30
fi

# 5. Check yesterday's and day-before logs for same issues
echo ""
echo "--- RECENT LOG FILES ---"
ls -la "$EA_LOG_DIR"/*.log 2>/dev/null | tail -5

# 6. Check previous day log for any trades
PREV_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -2 | tail -1)
if [ -n "$PREV_LOG" ] && [ "$PREV_LOG" != "$EA_LATEST" ]; then
    echo ""
    echo "--- PREVIOUS DAY TRADES ---"
    echo "File: $PREV_LOG"
    strings "$PREV_LOG" | grep -i "\[TRADE\]\|SIGNAL_BUY\|SIGNAL_SELL\|\[CLOSED\]\|BUY signal\|SELL signal\|GOT SIGNAL" | head -20
    echo ""
    echo "--- PREVIOUS DAY NEWBARs (sample) ---"
    strings "$PREV_LOG" | grep "NEWBAR" | head -10
    strings "$PREV_LOG" | grep "NEWBAR" | tail -10
fi

# 7. Check the actual EA .ex5 compilation date
echo ""
echo "--- EA FILES on VPS ---"
ls -la "$MT5_BASE/MQL5/Experts/PropFirmBot/"*.mq5 2>/dev/null
ls -la "$MT5_BASE/MQL5/Experts/PropFirmBot/"*.ex5 2>/dev/null
ls -la "$MT5_BASE/MQL5/Experts/PropFirmBot/"*.mqh 2>/dev/null

# 8. Check MT5 terminal config for EA parameters
echo ""
echo "--- MT5 Expert Settings (if available) ---"
find "$MT5_BASE" -name "*.set" -path "*PropFirmBot*" 2>/dev/null -exec echo "File: {}" \; -exec cat {} \; | head -60
find "$MT5_BASE" -name "experts.xml" 2>/dev/null -exec echo "File: {}" \; -exec strings {} \; | head -60

# 9. Current time check - what does MT5 think time is?
echo ""
echo "--- TIME CHECK ---"
echo "VPS system time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "VPS timezone: $(cat /etc/timezone 2>/dev/null || timedatectl 2>/dev/null | grep 'Time zone')"

# 10. Total line count per type today
echo ""
echo "--- LOG ENTRY COUNTS TODAY ---"
if [ -n "$EA_LATEST" ]; then
    echo "NEWBAR entries: $(strings "$EA_LATEST" | grep -c "NEWBAR")"
    echo "HEARTBEAT entries: $(strings "$EA_LATEST" | grep -c "HEARTBEAT")"
    echo "BLOCKED entries: $(strings "$EA_LATEST" | grep -c "BLOCKED")"
    echo "SCAN entries: $(strings "$EA_LATEST" | grep -c "\[SCAN\]")"
    echo "SIGNAL entries: $(strings "$EA_LATEST" | grep -c "signal")"
    echo "TRADE entries: $(strings "$EA_LATEST" | grep -c "\[TRADE\]")"
    echo "Total lines: $(wc -l < "$EA_LATEST")"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
