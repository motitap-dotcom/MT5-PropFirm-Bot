#!/bin/bash
echo "=== Investigate 5-min kill source ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Crontab ---"
crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$'
echo ""

echo "--- /root/tradovate-bot/server_cron.sh references ---"
if [ -f /root/tradovate-bot/server_cron.sh ]; then
  grep -nE "SERVICE=|futures-bot|systemctl" /root/tradovate-bot/server_cron.sh 2>/dev/null
else
  echo "file not found"
fi
echo ""

echo "--- /root/MT5-PropFirm-Bot/server_cron.sh references ---"
if [ -f /root/MT5-PropFirm-Bot/server_cron.sh ]; then
  grep -nE "SERVICE=|futures-bot|systemctl" /root/MT5-PropFirm-Bot/server_cron.sh 2>/dev/null
else
  echo "file not found"
fi
echo ""

echo "--- /root/mt5_watchdog.sh ---"
if [ -f /root/mt5_watchdog.sh ]; then
  grep -nE "futures-bot|MT5-PropFirm|systemctl" /root/mt5_watchdog.sh 2>/dev/null
else
  echo "file not found"
fi
echo ""

echo "--- /root/PropFirmBot/scripts/watchdog.sh ---"
if [ -f /root/PropFirmBot/scripts/watchdog.sh ]; then
  grep -nE "futures-bot|MT5-PropFirm|systemctl" /root/PropFirmBot/scripts/watchdog.sh 2>/dev/null
else
  echo "file not found"
fi
echo ""

echo "--- /opt/hyrotrader-bot/scripts/auto_deploy.sh ---"
if [ -f /opt/hyrotrader-bot/scripts/auto_deploy.sh ]; then
  grep -nE "futures-bot|MT5-PropFirm|systemctl" /opt/hyrotrader-bot/scripts/auto_deploy.sh 2>/dev/null
else
  echo "file not found"
fi
echo ""

echo "--- Journal events for futures-bot stop/kill (last 30 min) ---"
journalctl --no-pager --since "30 min ago" 2>/dev/null | grep -iE "futures-bot.*(stop|kill|restart|terminat)" | tail -20
echo ""

echo "--- Log tail (what was bot doing just before kill?) ---"
BOTPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
CWD=$(readlink /proc/$BOTPID/cwd 2>/dev/null)
echo "Current bot CWD: $CWD"
tail -10 "$CWD/logs/bot.log" 2>/dev/null

echo ""
echo "=== Done ==="
