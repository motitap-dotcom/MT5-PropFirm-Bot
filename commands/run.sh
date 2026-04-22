#!/bin/bash
# Trigger: deep-systemd-diag
cd /root/MT5-PropFirm-Bot
echo "=== Deep systemd diag $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
echo ""
echo "=== systemd unit file cat ==="
systemctl cat futures-bot 2>&1
echo ""
echo "=== overrides/drop-ins ==="
ls -la /etc/systemd/system/futures-bot.service.d/ 2>/dev/null || echo "no drop-in dir"
echo ""
echo "=== full show ==="
systemctl show futures-bot --property=ExecStart --property=WorkingDirectory --property=RootDirectory --property=FragmentPath --property=DropInPaths 2>&1
echo ""
echo "=== try ExecStart EXACTLY as systemd would ==="
cd /root/MT5-PropFirm-Bot
env -i PATH=/usr/bin PYTHONUNBUFFERED=1 PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 -m futures_bot.bot --help 2>&1 | head -5 &
BOT_PID=$!
sleep 3
kill $BOT_PID 2>/dev/null
wait $BOT_PID 2>/dev/null
echo "exit code: $?"
echo ""
echo "=== try with .env sourced, like systemd ==="
(
  set -a
  source .env 2>/dev/null
  set +a
  cd /root/MT5-PropFirm-Bot
  PYTHONUNBUFFERED=1 PYTHONPATH=/root/MT5-PropFirm-Bot timeout 3 /usr/bin/python3 -m futures_bot.bot 2>&1 | head -10
)
echo "=== done ==="
echo ""
echo "=== current service state ==="
systemctl status futures-bot --no-pager -n 5 2>&1 | head -15
echo ""
echo "=== ls PYTHONPATH-visible ==="
ls -la /root/MT5-PropFirm-Bot/futures_bot/__init__.py /root/MT5-PropFirm-Bot/futures_bot/bot.py
