#!/bin/bash
cd /root/MT5-PropFirm-Bot
echo "=== $(date -u '+%H:%M UTC') futures_bot deep check ==="
echo ""
echo "--- git HEAD on VPS ---"
git log -1 --oneline
git branch --show-current
echo "tree files: $(git ls-files 2>/dev/null | wc -l)"
echo ""
echo "--- futures_bot/ ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/ 2>&1
echo ""
echo "--- futures_bot/core/ ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/core/ 2>&1 | head -10
echo ""
echo "--- key files wc ---"
for f in futures_bot/__init__.py futures_bot/bot.py futures_bot/core/__init__.py; do
  if [ -f "$f" ]; then wc -l "$f"; else echo "MISSING: $f"; fi
done
echo ""
echo "--- try importing ---"
cd /root/MT5-PropFirm-Bot
export PYTHONPATH=/root/MT5-PropFirm-Bot
timeout 4 /usr/bin/python3 -c "
import os, sys
print('cwd:', os.getcwd())
print('PYTHONPATH env:', os.environ.get('PYTHONPATH'))
print('futures_bot items:', sorted(os.listdir('futures_bot')) if os.path.isdir('futures_bot') else 'NO DIR')
try:
    import futures_bot
    print('futures_bot package:', futures_bot.__file__)
except Exception as e:
    print('import futures_bot FAILED:', type(e).__name__, e)
try:
    import futures_bot.bot
    print('bot OK')
except Exception as e:
    print('import futures_bot.bot FAILED:', type(e).__name__, e)
" 2>&1 | head -20
