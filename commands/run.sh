#!/bin/bash
# Trigger: force-pull-restart-v1
cd /root/MT5-PropFirm-Bot
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

# Stop bot first
systemctl stop futures-bot
echo "Bot stopped"

# Force pull latest code
echo "=== Git pull ==="
git fetch origin claude/fix-bot-functionality-h1Sb3
git reset --hard origin/claude/fix-bot-functionality-h1Sb3
echo ""

# Verify file exists and no syntax errors
echo "=== Syntax check ==="
python3 -c "import py_compile; py_compile.compile('futures_bot/core/tradovate_client.py', doraise=True); print('tradovate_client.py OK')"
python3 -c "import py_compile; py_compile.compile('futures_bot/bot.py', doraise=True); print('bot.py OK')"
echo ""

# Check module can be found
echo "=== Module check ==="
python3 -c "import futures_bot.bot; print('Module import OK')" 2>&1 || echo "Module import FAILED"
echo ""

# Restart
mkdir -p logs status
systemctl daemon-reload
systemctl restart futures-bot
sleep 5
echo "Bot status: $(systemctl is-active futures-bot)"
echo ""
journalctl -u futures-bot --no-pager -n 20 --since "10 sec ago"
echo "DONE"
