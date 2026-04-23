#!/bin/bash
echo "=== Status Check v2 (READ-ONLY) ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Service ---"
echo "Active: $(systemctl is-active futures-bot 2>/dev/null)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value 2>/dev/null)"
echo ""

echo "--- Bot process working directory ---"
BOTPID=$(systemctl show futures-bot --property=MainPID --value 2>/dev/null)
if [ -n "$BOTPID" ] && [ "$BOTPID" != "0" ]; then
  echo "CWD: $(readlink /proc/$BOTPID/cwd 2>/dev/null)"
  echo "Cmd: $(tr '\0' ' ' < /proc/$BOTPID/cmdline 2>/dev/null)"
fi
echo ""

echo "--- /root/MT5-PropFirm-Bot/configs/ contents ---"
ls -la /root/MT5-PropFirm-Bot/configs/ 2>/dev/null || echo "directory missing"
echo ""

echo "--- bot_config.json exists? ---"
[ -f /root/MT5-PropFirm-Bot/configs/bot_config.json ] && echo "YES ($(stat -c%s /root/MT5-PropFirm-Bot/configs/bot_config.json) bytes)" || echo "NO"
[ -f /root/MT5-PropFirm-Bot/configs/restricted_events.json ] && echo "restricted_events.json: YES" || echo "restricted_events.json: NO"
echo ""

echo "--- Full wrapper ---"
cat /usr/local/sbin/futures-bot-wrapper.sh 2>/dev/null
echo ""

echo "--- Git state on VPS ---"
cd /root/MT5-PropFirm-Bot
echo "Branch: $(git branch --show-current 2>/dev/null)"
echo "HEAD: $(git log -1 --oneline 2>/dev/null)"
echo "configs in this commit:"
git show --stat HEAD -- configs/ 2>/dev/null | tail -5
echo ""

echo "--- Running bot log (last 20) ---"
tail -20 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null
echo ""

echo "--- Current positions on account ---"
if [ -f /root/MT5-PropFirm-Bot/configs/.tradovate_token.json ]; then
  TOKEN=$(python3 -c "import json;print(json.load(open('/root/MT5-PropFirm-Bot/configs/.tradovate_token.json'))['accessToken'])" 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    curl -s -H "Authorization: Bearer $TOKEN" https://live.tradovateapi.com/v1/position/list 2>/dev/null | head -c 300
    echo ""
  fi
fi

echo ""
echo "=== Done ==="
