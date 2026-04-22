#!/bin/bash
echo "=== $(date -u '+%H:%M UTC')  NY=$(TZ=America/New_York date '+%H:%M') ==="
systemctl is-active futures-bot
echo ""
echo "--- /opt/futures_bot_stable/status/status.json ---"
cat /opt/futures_bot_stable/status/status.json 2>&1
echo ""
echo "--- /opt/futures_bot_stable/logs/bot.log (full) ---"
cat /opt/futures_bot_stable/logs/bot.log 2>&1
echo ""
echo "--- configs in /opt? ---"
ls -la /opt/futures_bot_stable/configs/ 2>&1 | head -10
