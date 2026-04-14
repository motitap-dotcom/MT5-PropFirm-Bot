#!/bin/bash
echo "=== TradeDay Futures Bot - Diagnostic $(date -u +'%Y-%m-%d %H:%M:%S UTC') ==="
echo ""

echo "--- Service ---"
systemctl is-active futures-bot
systemctl show futures-bot --property=ActiveState,SubState,Result,NRestarts,MainPID,ExecMainStartTimestamp,ExecMainExitTimestamp,ActiveEnterTimestamp --no-pager
echo ""

echo "--- systemctl status (full) ---"
systemctl status futures-bot --no-pager -l | head -30
echo ""

echo "--- journalctl last 50 lines (includes crash traces) ---"
journalctl -u futures-bot --no-pager -n 50 --since "30 minutes ago"
echo ""

echo "--- Python import check (does the bot module load?) ---"
cd /root/MT5-PropFirm-Bot
PYTHONPATH=/root/MT5-PropFirm-Bot python3 -c "
import sys
sys.path.insert(0, '/root/MT5-PropFirm-Bot')
try:
    import futures_bot.bot
    print('IMPORT OK: futures_bot.bot')
    import futures_bot.core.tradovate_client
    print('IMPORT OK: tradovate_client')
except Exception as e:
    print(f'IMPORT FAIL: {type(e).__name__}: {e}')
    import traceback
    traceback.print_exc()
" 2>&1
echo ""

echo "--- Token file ---"
ls -la configs/.tradovate_token.json 2>/dev/null || echo "no token file"
if [ -f configs/.tradovate_token.json ]; then
  python3 -c "import json,time; d=json.load(open('configs/.tradovate_token.json')); exp=d.get('expiry',0); print(f'  expiry: {exp} ({(exp-time.time())/60:.0f}min from now)'); print(f'  saved_at: {d.get(\"saved_at\",\"?\")}')" 2>&1
fi
echo ""

echo "--- .env check ---"
for v in TRADOVATE_USER TRADOVATE_PASS TELEGRAM_TOKEN TELEGRAM_CHAT_ID; do
  if grep -q "^${v}=" /root/MT5-PropFirm-Bot/.env 2>/dev/null; then
    VAL=$(grep "^${v}=" /root/MT5-PropFirm-Bot/.env | cut -d= -f2-)
    echo "  $v: SET (len=${#VAL})"
  else
    echo "  $v: MISSING"
  fi
done
echo ""

echo "--- Playwright install check ---"
python3 -c "from playwright.async_api import async_playwright; print('playwright: OK')" 2>&1 | head -3
ls -la /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>&1 | head -2
echo ""

echo "--- Recent bot.log (last 15 lines) ---"
tail -15 /root/MT5-PropFirm-Bot/logs/bot.log 2>/dev/null || echo "no log"
echo ""

echo "=== END DIAGNOSTIC ==="
