#!/bin/bash
cd /root/MT5-PropFirm-Bot 2>/dev/null || cd /opt/futures_bot_stable
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
echo "Service: $(systemctl is-active futures-bot)  PID: $(systemctl show futures-bot --property=MainPID --value)  NRestarts: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""
echo "--- /opt/futures_bot_stable ---"
ls -la /opt/futures_bot_stable/ 2>&1 | head -10
ls -la /opt/futures_bot_stable/futures_bot/ 2>&1 | head -10
echo ""
echo "--- /root/MT5-PropFirm-Bot/futures_bot/ ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/ 2>&1 | head -10
echo ""
echo "--- journalctl last 20 ---"
journalctl -u futures-bot --no-pager -n 20 2>&1 | tail -20
echo ""
echo "--- bot log last 15 ---"
tail -15 /root/MT5-PropFirm-Bot/logs/bot.log /opt/futures_bot_stable/logs/bot.log 2>/dev/null | tail -15
