#!/bin/bash
echo "=== Check v3: full startup log ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

BOTPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
echo "PID: $BOTPID"
[ -n "$BOTPID" ] && [ "$BOTPID" != "0" ] && {
  echo "CWD: $(readlink /proc/$BOTPID/cwd 2>/dev/null)"
  START_TIME=$(ps -o lstart= -p "$BOTPID" 2>/dev/null)
  echo "Started: $START_TIME"
}
echo ""

echo "--- Current bot log: last 60 lines ---"
LOG=$(readlink /proc/$BOTPID/cwd 2>/dev/null)/logs/bot.log
echo "Log file: $LOG"
tail -60 "$LOG" 2>/dev/null
echo ""

echo "--- Grep: config loading + symbols in this log ---"
grep -iE "config|symbols|trading|restricted_events|Starting" "$LOG" 2>/dev/null | tail -20
echo ""

echo "--- Config file content (first 5 lines) ---"
head -5 /root/MT5-PropFirm-Bot/configs/bot_config.json 2>/dev/null
echo ""

echo "=== Done ==="
