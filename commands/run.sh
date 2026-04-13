#!/bin/bash
# Trigger: v151 — diagnose crash loop via journalctl
cd /root/MT5-PropFirm-Bot
echo "=== v151 crash diagnosis $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""
echo "--- SERVICE ---"
systemctl status futures-bot --no-pager 2>&1 | head -15
echo ""
echo "--- JOURNALCTL (last 60 lines - where stderr/Python errors go) ---"
journalctl -u futures-bot --no-pager -n 60 2>&1 | tail -60
echo ""
echo "--- BOT LOG TAIL (last 20) ---"
tail -20 logs/bot.log 2>/dev/null
echo ""
echo "--- CONFIG JSON VALIDITY ---"
python3 -c "import json; c=json.load(open('configs/bot_config.json')); print('OK, keys:', list(c.keys()))" 2>&1
echo ""
echo "--- IMPORT TEST ---"
PYTHONPATH=/root/MT5-PropFirm-Bot python3 -c "
try:
    from futures_bot.bot import FuturesBot
    print('Import OK')
    b = FuturesBot()
    print('Init OK, symbols:', b.symbols)
except Exception as e:
    import traceback
    traceback.print_exc()
" 2>&1
echo ""
echo "=== END v151 ==="
