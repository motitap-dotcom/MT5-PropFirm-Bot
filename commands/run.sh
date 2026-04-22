#!/bin/bash
# Trigger: debug-no-trades
cd /root/MT5-PropFirm-Bot
echo "=== Debug No Trades $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "=== SERVICE ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
echo "=== TIME (ET = UTC-4 EDT) ==="
echo "UTC:     $(date -u '+%Y-%m-%d %H:%M:%S')"
echo "NY:      $(TZ=America/New_York date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Weekday: $(date -u '+%A')"
echo ""
echo "=== STATUS.JSON ==="
if [ -f status/status.json ]; then
  cat status/status.json
else
  echo "!!! status/status.json MISSING !!!"
fi
echo ""
echo "=== LAST 80 LOG LINES ==="
tail -80 logs/bot.log 2>/dev/null || echo "!!! no log file !!!"
echo ""
echo "=== GREP: signals / setups / trades / blocks ==="
grep -iE "signal|setup|trade|block|reject|skip|guard|news|session" logs/bot.log 2>/dev/null | tail -40
echo ""
echo "=== GREP: errors / warnings ==="
grep -iE "error|warning|failed|exception|traceback" logs/bot.log 2>/dev/null | tail -20
