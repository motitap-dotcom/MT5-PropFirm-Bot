#!/bin/bash
echo "=== Quick kill source check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- /etc/cron.d/ ---"
ls -la /etc/cron.d/ 2>/dev/null
echo ""
for f in /etc/cron.d/*; do
  [ -f "$f" ] && { echo "=== $f ==="; grep -iE "futures|MT5|bot\.py" "$f" 2>/dev/null && echo "MATCH!" || echo "no match"; }
done
echo ""

echo "--- systemd timers ---"
systemctl list-timers --all --no-pager 2>/dev/null | grep -iE "futures|bot" | head -10
echo ""

echo "--- ALL crontabs on the system ---"
for user in $(cut -d: -f1 /etc/passwd 2>/dev/null); do
  ct=$(crontab -u "$user" -l 2>/dev/null)
  [ -n "$ct" ] && echo "=== $user ===" && echo "$ct" | grep -vE '^#|^$' | head -15
done
echo ""

echo "--- What shells had systemctl recently? ---"
ls -la /var/log/auth.log /var/log/syslog 2>/dev/null | head -5
journalctl --since "30 min ago" --no-pager 2>/dev/null | grep -iE "systemctl.*futures|restart futures-bot|stop futures-bot" | head -10
echo ""

echo "--- /root/*.sh files (look for kill patterns) ---"
for f in /root/*.sh; do
  [ -f "$f" ] && grep -lE "futures-bot|futures_bot|MT5-PropFirm" "$f" 2>/dev/null
done
echo ""

echo "--- /root directory scripts containing futures-bot ---"
grep -rl "futures-bot" /root 2>/dev/null | grep -v "\.git/" | grep -v "\.log$" | grep -v "\.json$" | head -10
echo ""

echo "--- Current bot state ---"
echo "Service: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $PID"
[ -n "$PID" ] && [ "$PID" != "0" ] && echo "CWD: $(readlink /proc/$PID/cwd 2>/dev/null)"
echo "ActiveEnterTimestamp: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value 2>/dev/null)"
echo ""

echo "=== Done ==="
