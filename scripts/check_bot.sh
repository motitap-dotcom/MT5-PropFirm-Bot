#!/bin/bash
echo "=== Bot activity check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "NY Time: $(TZ=America/New_York date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

BOTPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $BOTPID"
[ -n "$BOTPID" ] && [ "$BOTPID" != "0" ] && {
  echo "CWD: $(readlink /proc/$BOTPID/cwd 2>/dev/null)"
  echo "Active: $(systemctl is-active futures-bot)"
  echo "Started: $(ps -o lstart= -p $BOTPID 2>/dev/null)"
}
echo ""

echo "--- Full current log (last 100 lines) ---"
CWD=$(readlink /proc/$BOTPID/cwd 2>/dev/null)
tail -100 "$CWD/logs/bot.log" 2>/dev/null
echo ""

echo "--- Bot config: trading hours + session ---"
python3 -c "
import json
c = json.load(open('/root/MT5-PropFirm-Bot/configs/bot_config.json'))
import pprint
print('live:', c.get('live'))
print('symbols:', c.get('symbols'))
print('timeframe:', c.get('timeframe'))
pprint.pprint(c.get('risk_manager', {}))
pprint.pprint(c.get('session', {}))
" 2>/dev/null
echo ""

echo "=== Done ==="
