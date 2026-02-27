#!/bin/bash
# Network diagnostics - Why can't MT5 connect to FundedNext?
echo "=== NETWORK DIAGNOSTICS $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo ""
echo "--- 1. DNS Resolution ---"
for host in mt5.fundednext.com mt5-real.fundednext.com server.fundednext.com fundednext.com; do
    IP=$(dig +short "$host" 2>/dev/null | head -1)
    [ -n "$IP" ] && echo "  $host -> $IP" || echo "  $host -> FAILED"
done

echo ""
echo "--- 2. MT5 Server Config ---"
# Check MT5 server files
SRVDIR="$MT5/config/servers"
echo "  Server config dir: $(ls "$SRVDIR" 2>/dev/null | head -20 || echo 'NOT FOUND')"

# Find FundedNext server files
find "$MT5/config" -type f -name "*FundedNext*" 2>/dev/null | while read f; do
    echo "  Found: $f"
    cat "$f" 2>/dev/null | tr -d '\0' | head -20
done

# Check for any .srv files
find "$MT5" -name "*.srv" 2>/dev/null | head -10 | while read f; do
    echo "  SRV: $f ($(stat -c%s "$f") bytes)"
done

echo ""
echo "--- 3. MT5 Common Config ---"
COMMON="$MT5/config/common.ini"
if [ -f "$COMMON" ]; then
    echo "  common.ini exists"
    cat "$COMMON" | tr -d '\0'
else
    echo "  common.ini NOT FOUND"
fi

echo ""
echo "--- 4. MT5 Last Known Server (origin.ini) ---"
for ini in "$MT5/origin.ini" "$MT5/config/origin.ini"; do
    if [ -f "$ini" ]; then
        echo "  Found: $ini"
        cat "$ini" | tr -d '\0'
    fi
done

echo ""
echo "--- 5. All current TCP connections ---"
ss -tn state established 2>/dev/null | head -20

echo ""
echo "--- 6. Port connectivity test ---"
# MT5 commonly uses these ports
for port in 443 1950 1951 1952 1953 1960 4433 4443; do
    # Try connecting to known FundedNext IPs
    timeout 3 bash -c "echo > /dev/tcp/185.68.16.106/$port" 2>/dev/null && echo "  185.68.16.106:$port OPEN" || true
    timeout 3 bash -c "echo > /dev/tcp/185.68.16.107/$port" 2>/dev/null && echo "  185.68.16.107:$port OPEN" || true
done

echo ""
echo "--- 7. Traceroute to common broker ports ---"
# Try resolving any FundedNext server
FNIP=$(dig +short mt5.fundednext.com 2>/dev/null | head -1)
if [ -n "$FNIP" ]; then
    echo "  FundedNext IP: $FNIP"
    for port in 443 1950 1951 1952 1953; do
        timeout 3 bash -c "echo > /dev/tcp/$FNIP/$port" 2>/dev/null && echo "  $FNIP:$port OPEN" || echo "  $FNIP:$port CLOSED/TIMEOUT"
    done
else
    echo "  Cannot resolve FundedNext DNS"
fi

echo ""
echo "--- 8. Wine network test ---"
export DISPLAY=:99 WINEPREFIX=/root/.wine
# Check if Wine can resolve DNS
wine cmd /c "ping -n 1 8.8.8.8" 2>/dev/null | head -5 || echo "  Wine ping failed (normal on Linux)"

echo ""
echo "--- 9. MT5 Terminal Log (full for today) ---"
TODAY=$(date '+%Y%m%d')
TLOG="$MT5/logs/${TODAY}.log"
if [ -f "$TLOG" ]; then
    echo "  Full terminal log:"
    cat "$TLOG" | tr -d '\0'
else
    echo "  No log for today"
    # Show the latest log
    LATEST=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
    [ -n "$LATEST" ] && echo "  Latest: $LATEST" && cat "$LATEST" | tr -d '\0' | tail -30
fi

echo ""
echo "--- 10. MT5 EA log ---"
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EALOG" ]; then
    echo "  EA log:"
    cat "$EALOG" | tr -d '\0'
else
    echo "  No EA log for today"
fi

echo ""
echo "--- 11. Firewall rules ---"
iptables -L -n 2>/dev/null | head -30 || echo "  Cannot read iptables"
ufw status 2>/dev/null || echo "  UFW not available"

echo ""
echo "--- 12. MT5 process & network ---"
PID=$(pgrep -f terminal64.exe 2>/dev/null | head -1)
if [ -n "$PID" ]; then
    echo "  MT5 PID: $PID"
    echo "  Open files/sockets:"
    ls -la /proc/$PID/fd 2>/dev/null | grep socket | head -10
    echo "  Network (from /proc):"
    cat /proc/$PID/net/tcp 2>/dev/null | head -10
else
    echo "  MT5 not running"
fi

echo ""
echo "--- 13. General internet check ---"
curl -s -o /dev/null -w "HTTP: %{http_code}\n" https://www.google.com 2>/dev/null
curl -s -o /dev/null -w "Telegram API: %{http_code}\n" https://api.telegram.org 2>/dev/null

echo ""
echo "=== END DIAGNOSTICS ==="
