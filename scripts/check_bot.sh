#!/bin/bash
echo "=== Deep kill investigation ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- /etc/cron.d/ files ---"
ls -la /etc/cron.d/ 2>/dev/null
for f in /etc/cron.d/*; do
  [ -f "$f" ] && echo "=== $f ===" && cat "$f"
done
echo ""

echo "--- /etc/cron.hourly/ /etc/cron.daily/ /etc/cron.weekly/ ---"
ls /etc/cron.hourly/ /etc/cron.daily/ /etc/cron.weekly/ 2>/dev/null
echo ""

echo "--- All user crontabs ---"
for user in root $(cut -d: -f1 /etc/passwd 2>/dev/null); do
  ct=$(crontab -u "$user" -l 2>/dev/null)
  if [ -n "$ct" ]; then
    echo "=== $user ==="
    echo "$ct"
  fi
done
echo ""

echo "--- Systemd timers ---"
systemctl list-timers --all --no-pager 2>/dev/null | head -20
echo ""

echo "--- Search for ALL files that reference futures-bot or futures_bot ---"
for loc in /root /opt /etc /usr/local; do
  grep -rlEs "futures-bot|futures_bot\.service|MT5-PropFirm|bot\.py" "$loc" 2>/dev/null | grep -v "\.git/" | grep -v "\.log$" | grep -v "\.json$" | head -30
done
echo ""

echo "--- Journalctl _PID=1 for futures-bot (who called systemctl?) ---"
journalctl _PID=1 --no-pager --since "30 min ago" 2>/dev/null | grep -i futures-bot | tail -20
echo ""

echo "--- Last 30 min of ALL systemd journal mentioning futures-bot ---"
journalctl --no-pager --since "30 min ago" 2>/dev/null | grep -i "futures-bot\.service" | tail -30
echo ""

echo "--- Is /root/MT5-PropFirm-Bot/futures_bot/bot.py still there? ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/bot.py 2>/dev/null || echo "MISSING"
echo ""

echo "--- Is bot still running? ---"
systemctl is-active futures-bot
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
BOTPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
[ -n "$BOTPID" ] && [ "$BOTPID" != "0" ] && echo "CWD: $(readlink /proc/$BOTPID/cwd 2>/dev/null)"
echo ""

echo "=== Done ==="
