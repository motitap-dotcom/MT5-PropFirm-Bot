#!/bin/bash
# Trigger: v151 - understand paths and find killer
cd /root/MT5-PropFirm-Bot
echo "=== v151 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Service file ---"
cat /etc/systemd/system/futures-bot.service 2>/dev/null
echo ""
echo "--- futures-bot-wrapper.sh ---"
find / -name "futures-bot-wrapper.sh" 2>/dev/null | head -5
for f in $(find / -name "futures-bot-wrapper.sh" 2>/dev/null); do
  echo "=== $f ==="
  cat "$f"
done
echo ""
echo "--- /opt/futures_bot_stable contents ---"
ls -la /opt/futures_bot_stable/ 2>/dev/null | head -20
echo ""
echo "--- Compare bot.py: /opt vs /root ---"
if [ -f /opt/futures_bot_stable/futures_bot/bot.py ] && [ -f /root/MT5-PropFirm-Bot/futures_bot/bot.py ]; then
  OPT_HASH=$(md5sum /opt/futures_bot_stable/futures_bot/bot.py | awk '{print $1}')
  REPO_HASH=$(md5sum /root/MT5-PropFirm-Bot/futures_bot/bot.py | awk '{print $1}')
  echo "/opt/futures_bot_stable/futures_bot/bot.py: $OPT_HASH"
  echo "/root/MT5-PropFirm-Bot/futures_bot/bot.py: $REPO_HASH"
  if [ "$OPT_HASH" = "$REPO_HASH" ]; then
    echo "SAME CONTENT"
  else
    echo "DIFFERENT! /opt is stale or different"
  fi
  echo ""
  echo "/opt bot.py mtime: $(stat -c '%y' /opt/futures_bot_stable/futures_bot/bot.py)"
  echo "/root bot.py mtime: $(stat -c '%y' /root/MT5-PropFirm-Bot/futures_bot/bot.py)"
fi
echo ""
echo "--- Who sent SIGKILL to bot PIDs (audit from kernel log) ---"
dmesg 2>/dev/null | tail -40 | grep -iE "kill|oom|python" || echo "no dmesg matches"
echo ""
echo "--- journalctl for 'futures-bot' kill events ---"
journalctl --no-pager --since "1 hour ago" 2>/dev/null | grep -iE "futures-bot|systemctl.*futures" | grep -iE "kill|stop|restart|signal" | tail -30
echo ""
echo "--- Any scripts that reference futures-bot systemctl ---"
grep -rls "systemctl.*futures-bot\|futures-bot.service" /root /opt /etc 2>/dev/null | grep -v "\.git/" | head -20
echo ""
echo "--- Hyrotrader auto_deploy.sh (read-only check) ---"
[ -f /opt/hyrotrader-bot/scripts/auto_deploy.sh ] && grep -iE "futures-bot|MT5-PropFirm" /opt/hyrotrader-bot/scripts/auto_deploy.sh | head -10 || echo "no file"
echo ""
echo "--- PropFirmBot watchdog (read-only) ---"
[ -f /root/PropFirmBot/scripts/watchdog.sh ] && grep -iE "futures-bot|MT5-PropFirm|kill" /root/PropFirmBot/scripts/watchdog.sh | head -10 || echo "no file"
echo ""
echo "--- mt5_watchdog.sh (read-only) ---"
[ -f /root/mt5_watchdog.sh ] && grep -iE "futures-bot|MT5-PropFirm|kill" /root/mt5_watchdog.sh | head -10 || echo "no file"
echo ""
echo "--- Status now ---"
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo ""
echo "--- Time ---"
date -u
