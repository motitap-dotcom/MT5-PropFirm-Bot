#!/bin/bash
# v157 - restart so bot picks fresh config with 6 symbols
echo "=== Fix & Restart v157 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- BEFORE ---"
BOTPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $BOTPID"
[ -n "$BOTPID" ] && [ "$BOTPID" != "0" ] && echo "CWD: $(readlink /proc/$BOTPID/cwd 2>/dev/null)"

echo ""
echo "--- Verify config has 6 symbols ---"
CFG=/root/MT5-PropFirm-Bot/configs/bot_config.json
if [ -f "$CFG" ]; then
  echo "Size: $(stat -c%s $CFG)B"
  python3 -c "import json;c=json.load(open('$CFG'));print('symbols:',c.get('symbols','MISSING'))" 2>&1
else
  echo "CONFIG MISSING! Aborting restart."
  exit 1
fi

echo ""
echo "--- Also sync config to /opt/futures_bot_stable as safety copy ---"
mkdir -p /opt/futures_bot_stable/configs
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/ 2>/dev/null && echo "bot_config.json copied"
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/ 2>/dev/null && echo "restricted_events.json copied"

echo ""
echo "--- Restart ---"
systemctl restart futures-bot
sleep 10

echo ""
echo "--- AFTER ---"
echo "Active: $(systemctl is-active futures-bot)"
NEWPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $NEWPID"
[ -n "$NEWPID" ] && [ "$NEWPID" != "0" ] && {
  echo "CWD: $(readlink /proc/$NEWPID/cwd 2>/dev/null)"
}

echo ""
echo "--- First log lines after restart ---"
CWD=$(readlink /proc/$NEWPID/cwd 2>/dev/null)
[ -n "$CWD" ] && tail -30 "$CWD/logs/bot.log" 2>/dev/null | grep -iE "Config|symbols|Trading|Starting|Bot started|ERROR|restricted_events" | tail -15

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
