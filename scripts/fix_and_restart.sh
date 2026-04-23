#!/bin/bash
# v161 - restart with trend-day threshold fix + historical backfill
echo "=== Fix & Restart v161 ==="
echo "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "--- Verify new code is in place ---"
if grep -q "MD WebSocket connect failed" /root/MT5-PropFirm-Bot/futures_bot/core/tradovate_client.py 2>/dev/null; then
  echo "NEW CODE confirmed in /root/MT5-PropFirm-Bot"
else
  echo "NEW CODE NOT FOUND - aborting"
  exit 1
fi

echo ""
echo "--- Sync /opt/futures_bot_stable from /root (so fallback also has new code) ---"
rsync -a --delete /root/MT5-PropFirm-Bot/futures_bot/ /opt/futures_bot_stable/futures_bot/
cp /root/MT5-PropFirm-Bot/configs/bot_config.json /opt/futures_bot_stable/configs/ 2>/dev/null
cp /root/MT5-PropFirm-Bot/configs/restricted_events.json /opt/futures_bot_stable/configs/ 2>/dev/null
cp /root/MT5-PropFirm-Bot/requirements.txt /opt/futures_bot_stable/ 2>/dev/null
echo "Sync done"
echo ""

echo "--- Restart bot ---"
systemctl restart futures-bot
sleep 10

echo ""
echo "--- AFTER ---"
echo "Active: $(systemctl is-active futures-bot)"
PID=$(systemctl show futures-bot --property=MainPID --value)
echo "PID: $PID"
[ -n "$PID" ] && [ "$PID" != "0" ] && {
  echo "CWD: $(readlink /proc/$PID/cwd 2>/dev/null)"
  echo "Started: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
}

echo ""
echo "--- Recent bot log (last 25 lines) ---"
CWD=$(readlink /proc/$PID/cwd 2>/dev/null)
[ -n "$CWD" ] && tail -25 "$CWD/logs/bot.log" 2>/dev/null

echo ""
echo "--- Look for MD WebSocket connection in log ---"
grep -iE "MD WebSocket|md_ws|mode: None|OperationNotSupported" "$CWD/logs/bot.log" 2>/dev/null | tail -10

echo ""
echo "=== Done at $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
