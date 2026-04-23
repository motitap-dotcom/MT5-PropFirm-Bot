#!/bin/bash
echo "=== WebSocket / market data check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

PID=$(systemctl show futures-bot --property=MainPID --value)
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
echo "PID: $PID, CWD: $CWD"
echo "Uptime since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

LOG="$CWD/logs/bot.log"
[ ! -f "$LOG" ] && LOG=/root/MT5-PropFirm-Bot/logs/bot.log
[ ! -f "$LOG" ] && LOG=/opt/futures_bot_stable/logs/bot.log
echo "Log: $LOG"
echo ""

echo "--- ALL log lines from current uptime (last 14:31 start) ---"
awk '/^2026-04-23 14:31:3[3-9]|^2026-04-23 14:[3-5][0-9]/' "$LOG" 2>/dev/null | head -80
echo ""

echo "--- websocket / market data specific errors ---"
grep -iE "websocket|ws|market.*data|chart|subscribe|symbol" "$LOG" 2>/dev/null | tail -20
echo ""

echo "--- ALL errors in log (last 50 lines that contain ERROR or WARNING) ---"
grep -E "ERROR|WARNING" "$LOG" 2>/dev/null | tail -30
echo ""

echo "--- Check TCP connections from the bot ---"
[ -n "$PID" ] && [ "$PID" != "0" ] && {
  ss -tnp 2>/dev/null | grep "pid=$PID" | head -10 || echo "no connections visible"
}
echo ""

echo "--- Tradovate API reachability ---"
curl -s -o /dev/null -w "demo REST: %{http_code} (%{time_total}s)\n" https://demo.tradovateapi.com/v1
curl -s -o /dev/null -w "demo WS: %{http_code} (%{time_total}s)\n" https://md.tradovateapi.com/v1/websocket

echo ""
echo "=== Done ==="
