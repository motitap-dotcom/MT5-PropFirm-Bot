#!/bin/bash
# Trigger: v107 - Debug module not found
cd /root/MT5-PropFirm-Bot
echo "=== DEBUG v107 ==="
date -u
echo ""
echo "=== Current dir ==="
pwd
echo ""
echo "=== Git branch + commit ==="
git branch --show-current
git log --oneline -1
echo ""
echo "=== futures_bot files ==="
ls -la futures_bot/ 2>/dev/null || echo "futures_bot dir NOT FOUND"
ls -la futures_bot/__init__.py 2>/dev/null || echo "No __init__.py"
ls -la futures_bot/bot.py 2>/dev/null || echo "No bot.py"
echo ""
echo "=== Python check ==="
/usr/bin/python3 -c "import sys; print('Python:', sys.version); print('Path:', sys.path[:3])"
/usr/bin/python3 -c "import os; os.chdir('/root/MT5-PropFirm-Bot'); import futures_bot; print('Import OK')" 2>&1
echo ""
echo "=== Service file ==="
cat /etc/systemd/system/futures-bot.service 2>/dev/null
echo ""
echo "=== Try manual run ==="
cd /root/MT5-PropFirm-Bot
/usr/bin/python3 -c "from futures_bot.bot import main; print('bot.py importable')" 2>&1
echo ""
echo "=== END ==="
