#!/bin/bash
# PropFirmBot - Comprehensive VPS & Bot Status Check
# Runs on VPS via GitHub Actions workflow
echo "=== FULL STATUS CHECK $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date -u +%Y%m%d)

# --- 1. MT5 Process ---
echo ""
echo "--- MT5 Process ---"
MT5_PID=$(pgrep -f "terminal64" 2>/dev/null | head -1)
if [ -n "$MT5_PID" ]; then
    echo "STATUS: RUNNING (PID $MT5_PID)"
    ps -p "$MT5_PID" -o %cpu=,%mem=,etime= 2>/dev/null | awk '{printf "CPU: %s%% | RAM: %s%% | Uptime: %s\n", $1, $2, $3}'
else
    echo "STATUS: NOT RUNNING!"
fi

# --- 2. VNC & Display ---
echo ""
echo "--- VNC & Display ---"
pgrep -x "Xvfb" > /dev/null 2>&1 && echo "Xvfb: RUNNING" || echo "Xvfb: NOT RUNNING"
pgrep -x "x11vnc" > /dev/null 2>&1 && echo "VNC: RUNNING" || echo "VNC: NOT RUNNING"

# --- 3. Network Connections ---
echo ""
echo "--- Outbound Connections ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

# --- 4. Terminal Log (latest - dynamic date) ---
echo ""
echo "--- Terminal Log (latest) ---"
TERM_LOG=$(ls -t "$MT5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "File: $(basename $TERM_LOG) | Size: $(stat -c%s "$TERM_LOG" 2>/dev/null) bytes"
    # Show last auth events
    echo "--- Last auth events ---"
    grep -E "authorized on|authorization.*failed|terminal synchronized|trading has been" "$TERM_LOG" 2>/dev/null | tr -d '\0' | tail -10
    echo "--- Last 30 lines ---"
    cat "$TERM_LOG" | tr -d '\0' | tail -30
else
    echo "No terminal logs found"
fi

# --- 5. EA Log (dynamic date) ---
echo ""
echo "--- EA Log ---"
EA_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EA_LOG" ]; then
    echo "File: $(basename $EA_LOG) | Size: $(stat -c%s "$EA_LOG" 2>/dev/null) bytes"
    echo "--- Last 50 lines ---"
    cat "$EA_LOG" | tr -d '\0' | tail -50
    echo ""
    echo "--- Trade/Signal activity ---"
    TRADE_LINES=$(grep -ciE "TRADE|ORDER|BUY|SELL|position|OPEN|CLOSE" "$EA_LOG" 2>/dev/null)
    SIGNAL_LINES=$(grep -ciE "SIGNAL|signal" "$EA_LOG" 2>/dev/null)
    GUARDIAN_LINES=$(grep -ciE "GUARDIAN|guardian|drawdown|halt|emergency" "$EA_LOG" 2>/dev/null)
    echo "Trade entries: $TRADE_LINES | Signal entries: $SIGNAL_LINES | Guardian entries: $GUARDIAN_LINES"
    echo "--- Recent signals/trades ---"
    grep -iE "SIGNAL|TRADE|ORDER|BUY|SELL|OPEN|CLOSE|position" "$EA_LOG" 2>/dev/null | tr -d '\0' | tail -15
else
    echo "No EA logs found"
    echo "Available logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
fi

# --- 6. Status JSON (written by EA every 3 sec) ---
echo ""
echo "--- EA Status JSON ---"
STATUS_FILE="$MT5/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    STATUS_AGE=$(( $(date +%s) - $(stat -c%Y "$STATUS_FILE" 2>/dev/null || echo 0) ))
    echo "Last updated: $(stat -c%y "$STATUS_FILE" 2>/dev/null | cut -d. -f1) (${STATUS_AGE}s ago)"
    cat "$STATUS_FILE" 2>/dev/null
else
    echo "No status.json found"
fi

# --- 7. Config files ---
echo ""
echo "--- Config Files ---"
ls -la "$MT5/MQL5/Files/PropFirmBot/"*.json 2>/dev/null || echo "No config files found"

# --- 8. Trade Journal ---
echo ""
echo "--- Trade Journal ---"
find "$MT5/MQL5/Files/" -name "*journal*" -o -name "*trade*" 2>/dev/null | while read f; do
    if [ -f "$f" ]; then
        echo "File: $(basename $f) | Lines: $(wc -l < "$f") | Modified: $(stat -c%y "$f" | cut -d. -f1)"
        tail -10 "$f" 2>/dev/null
    fi
done
[ -z "$(find "$MT5/MQL5/Files/" -name "*journal*" -o -name "*trade*" 2>/dev/null)" ] && echo "No trade journal found"

# --- 9. EA Files ---
echo ""
echo "--- EA Files ---"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    ls -la "$EA_DIR/" 2>/dev/null
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        echo "PropFirmBot.ex5: $(stat -c%s "$EA_DIR/PropFirmBot.ex5") bytes, compiled: $(stat -c%y "$EA_DIR/PropFirmBot.ex5" | cut -d. -f1)"
    fi
else
    echo "EA directory not found"
fi

# --- 10. System Health ---
echo ""
echo "--- System Health ---"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
free -m | awk '/^Mem:/{printf "Memory: %dMB / %dMB (%d%%)\n", $3, $2, $3*100/$2}'
df -h / | awk 'NR==2{printf "Disk: %s used, %s free\n", $5, $4}'

# --- 11. Wine version ---
echo ""
echo "--- Wine Version ---"
wine --version 2>/dev/null || echo "Wine not found"

# --- 12. AutoTrading status ---
echo ""
echo "--- AutoTrading Status ---"
if [ -n "$TERM_LOG" ]; then
    grep "automated trading" "$TERM_LOG" 2>/dev/null | tr -d '\0' | tail -3
fi

echo ""
echo "=== DONE ==="
