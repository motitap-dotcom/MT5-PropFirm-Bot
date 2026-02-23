#!/bin/bash
# Check connection status after 5-minute EA timeout + network diagnostics
echo "=== NETWORK CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- 1. Full Terminal Log Today ---"
if [ -f "$MT5/logs/20260223.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260223.log") bytes"
    cat "$MT5/logs/20260223.log" | tr -d '\0'
fi

echo ""
echo "--- 2. EA Log Today ---"
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "EA LOG EXISTS!"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0'
else
    echo "No EA log (EA not initialized)"
fi

echo ""
echo "--- 3. MT5 Process ---"
ps aux | grep -E "terminal64|wine" | grep -v grep

echo ""
echo "--- 4. Network diagnostics ---"
echo "Firewall rules:"
iptables -L -n 2>&1 | head -20

echo ""
echo "Outbound connections (MT5):"
ss -tnp | grep -i wine 2>/dev/null || ss -tnp 2>/dev/null | grep -E "443|44[0-9]|8443|55[0-9]" | head -10

echo ""
echo "DNS working:"
nslookup google.com 2>&1 | head -5

echo ""
echo "--- 5. Extract server IPs from servers.dat ---"
# servers.dat is binary but contains server IPs
strings "$MT5/config/servers.dat" 2>/dev/null | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]" | head -20
echo ""
strings "$MT5/config/servers.dat" 2>/dev/null | grep -i "funded" | head -10

echo ""
echo "--- 6. Try to extract server IPs from Bases ---"
strings "$MT5/Bases/FundedNext-Server/config.bin" 2>/dev/null | grep -E "[0-9]+\.[0-9]+\.[0-9]" | head -10
ls -la "$MT5/Bases/FundedNext-Server/" 2>/dev/null

echo ""
echo "--- 7. Test common MT5 ports ---"
for port in 443 444 445 446 447 448 449 450 2000 2222 2223 443; do
    timeout 3 bash -c "echo > /dev/tcp/google.com/$port" 2>/dev/null && echo "Port $port: OPEN" || true
done

echo ""
echo "--- 8. Check if MT5 has ANY network connection ---"
# Get MT5 PID
MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
if [ -n "$MT5_PID" ]; then
    echo "MT5 PID: $MT5_PID"
    ls -la /proc/$MT5_PID/fd 2>/dev/null | grep socket | head -10
    cat /proc/$MT5_PID/net/tcp 2>/dev/null | head -10
fi

echo ""
echo "--- 9. Telegram test (proves outbound HTTPS works) ---"
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🔌 Network check $(date '+%H:%M UTC')" > /dev/null 2>&1
echo "Telegram: SENT"

echo ""
echo "=== DONE ==="
