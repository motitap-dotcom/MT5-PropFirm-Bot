#!/bin/bash
echo "=== Quick v158 verification ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Service config ---"
systemctl cat futures-bot 2>/dev/null | grep -E "ExecStart|Restart|ExecStopPost"
echo ""

echo "--- Current state ---"
echo "Active: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $PID"
[ -n "$PID" ] && [ "$PID" != "0" ] && echo "CWD: $(readlink /proc/$PID/cwd 2>/dev/null)"
echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""

echo "--- STOP LOG (what killed it?) ---"
tail -20 /var/log/futures-bot-stops.log 2>/dev/null || echo "no stop log"
echo ""

echo "--- Recent journal (last 5 min) ---"
journalctl -u futures-bot --no-pager --since "5 min ago" 2>/dev/null | tail -25
echo ""

echo "=== Done ==="
