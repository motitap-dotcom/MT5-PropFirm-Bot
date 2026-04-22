#!/bin/bash
# Trigger: check-after-bash-wrap-fix
cd /root/MT5-PropFirm-Bot
echo "=== After bash-wrap fix $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
echo ""
echo "=== service state ==="
systemctl is-active futures-bot
systemctl show futures-bot --property=MainPID --property=ExecStart --property=SubState --property=ActiveEnterTimestamp --property=Restart --property=NRestarts 2>&1
echo ""
echo "=== service file on disk ==="
cat /etc/systemd/system/futures-bot.service
echo ""
echo "=== last 30 journalctl lines ==="
journalctl -u futures-bot --no-pager -n 30 2>&1 | tail -30
echo ""
echo "=== last 30 bot log lines ==="
tail -30 logs/bot.log 2>/dev/null || echo "no log"
echo ""
echo "=== status.json ==="
cat status/status.json 2>/dev/null | head -30
