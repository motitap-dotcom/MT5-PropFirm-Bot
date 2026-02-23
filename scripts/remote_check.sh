#!/bin/bash
# Run this ON the VPS to get status report
echo "REPORT_START"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "=== 1. MT5 PROCESS ==="
ps aux | grep -i terminal64 | grep -v grep || echo "MT5_NOT_RUNNING"
echo ""

echo "=== 2. VNC ==="
pgrep -la x11vnc 2>/dev/null || echo "VNC_DOWN"
pgrep -la Xvfb 2>/dev/null || echo "XVFB_DOWN"
echo ""

echo "=== 3. EA FILES ==="
ls -la "$MT5/MQL5/Experts/PropFirmBot/" 2>&1
echo ""

echo "=== 4. LOG FILES LIST ==="
ls -la "$MT5/MQL5/Logs/" 2>&1
echo ""

echo "=== 5. MT5 LOG CONTENT ==="
LOGFILE=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LOGFILE" ]; then
  echo "File: $LOGFILE"
  echo "Size: $(stat -c%s "$LOGFILE" 2>/dev/null) bytes"
  echo "Modified: $(stat -c%y "$LOGFILE" 2>/dev/null)"
  cat "$LOGFILE" | tr -d '\0' | tail -50
else
  echo "NO_LOGS"
fi
echo ""

echo "=== 6. EA MESSAGES ==="
if [ -n "$LOGFILE" ]; then
  cat "$LOGFILE" | tr -d '\0' | grep -i "TRADE\|SIGNAL\|GUARDIAN\|CLOSED\|ERROR\|BUY\|SELL\|INIT\|NEWS\|PropFirmBot" | tail -30
fi
echo ""

echo "=== 7. TRADE JOURNAL ==="
find "$MT5/MQL5/Files/" -name "*.csv" -type f 2>/dev/null | while read f; do
  echo "CSV: $f"
  wc -l < "$f" 2>/dev/null
  tail -5 "$f" 2>/dev/null
done
echo "JOURNAL_DONE"
echo ""

echo "=== 8. TELEGRAM ==="
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/getMe" 2>&1 | grep -o '"ok":[^,]*' || echo "TELEGRAM_FAIL"
echo ""

echo "=== 9. SYSTEM ==="
echo "Uptime: $(uptime -p 2>/dev/null)"
echo "Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
free -m | awk '/Mem:/{printf "Memory: %dMB / %dMB (%d%%)\n", $3, $2, $3*100/$2}'
df -h / | awk 'NR==2{printf "Disk: %s used (%s free)\n", $5, $4}'
echo ""

echo "=== 10. DNS ==="
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
ping -c1 -W3 -4 google.com 2>&1 | head -2
echo ""

echo "REPORT_END"
