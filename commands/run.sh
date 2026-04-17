#!/bin/bash
# Trigger: check-code-exists
cd /root/MT5-PropFirm-Bot
echo "=== Directory Check $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "--- Current branch ---"
git branch --show-current
git log -1 --oneline
echo ""
echo "--- Top-level files ---"
ls -la /root/MT5-PropFirm-Bot/ | head -30
echo ""
echo "--- futures_bot dir ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/ 2>&1 | head -20
echo ""
echo "--- Test import manually ---"
cd /root/MT5-PropFirm-Bot
PYTHONPATH=/root/MT5-PropFirm-Bot /usr/bin/python3 -c "import futures_bot.bot; print('OK')" 2>&1
echo ""
echo "--- Find any bot.py ---"
find /root/MT5-PropFirm-Bot -name "bot.py" -not -path "*/\.*" 2>/dev/null
