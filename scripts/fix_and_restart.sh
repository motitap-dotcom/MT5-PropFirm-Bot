#!/bin/bash
# v156 - simple restart so wrapper picks /root/MT5-PropFirm-Bot (has fresh configs)
echo "=== Fix & Restart v156 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- BEFORE ---"
BOTPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $BOTPID"
if [ -n "$BOTPID" ] && [ "$BOTPID" != "0" ]; then
  echo "CWD: $(readlink /proc/$BOTPID/cwd 2>/dev/null)"
fi

echo ""
echo "--- Verify files in /root/MT5-PropFirm-Bot ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/bot.py 2>/dev/null || echo "bot.py MISSING!"
ls -la /root/MT5-PropFirm-Bot/configs/bot_config.json 2>/dev/null || echo "bot_config.json MISSING!"
ls -la /root/MT5-PropFirm-Bot/configs/restricted_events.json 2>/dev/null || echo "restricted_events.json MISSING!"

echo ""
echo "--- Restart ---"
systemctl restart futures-bot
sleep 8

echo ""
echo "--- AFTER ---"
echo "Active: $(systemctl is-active futures-bot)"
NEWPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $NEWPID"
if [ -n "$NEWPID" ] && [ "$NEWPID" != "0" ]; then
  echo "CWD: $(readlink /proc/$NEWPID/cwd 2>/dev/null)"
  echo "Cmd: $(tr '\0' ' ' < /proc/$NEWPID/cmdline 2>/dev/null)"
fi

echo ""
echo "--- Bot log from new instance ---"
# Log will be in cwd/logs/bot.log
CWD=$(readlink /proc/$NEWPID/cwd 2>/dev/null)
[ -n "$CWD" ] && tail -30 "$CWD/logs/bot.log" 2>/dev/null

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
