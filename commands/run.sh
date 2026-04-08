#!/bin/bash
# Trigger: v158 - check if futures_bot exists after deploy
cd /root/MT5-PropFirm-Bot
echo "=== File Check v158 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- Current git commit ---"
git log -1 --oneline
echo ""
echo "--- git branch ---"
git branch -v
echo ""
echo "--- futures_bot directory ---"
ls -la futures_bot/ 2>/dev/null || echo "futures_bot/ DOES NOT EXIST!"
echo ""
echo "--- futures_bot/__init__.py ---"
cat futures_bot/__init__.py 2>/dev/null || echo "__init__.py NOT FOUND"
echo ""
echo "--- futures_bot/bot.py (first 5 lines) ---"
head -5 futures_bot/bot.py 2>/dev/null || echo "bot.py NOT FOUND"
echo ""
echo "--- What python3 sees ---"
/usr/bin/python3 -c "
import sys
sys.path.insert(0, '/root/MT5-PropFirm-Bot')
import os
print('CWD:', os.getcwd())
print('PYTHONPATH:', os.environ.get('PYTHONPATH', 'NOT SET'))
print('futures_bot dir exists:', os.path.isdir('/root/MT5-PropFirm-Bot/futures_bot'))
print('__init__.py exists:', os.path.isfile('/root/MT5-PropFirm-Bot/futures_bot/__init__.py'))
print('bot.py exists:', os.path.isfile('/root/MT5-PropFirm-Bot/futures_bot/bot.py'))
try:
    import futures_bot.bot
    print('IMPORT: OK')
except Exception as e:
    print(f'IMPORT ERROR: {e}')
" 2>&1
echo ""
echo "--- Running processes with bot ---"
ps aux | grep -i "futures_bot\|python.*bot" | grep -v grep
