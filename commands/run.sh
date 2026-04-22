#!/bin/bash
# Post-DST-fix health check (read-only, no restart)
cd /root/MT5-PropFirm-Bot
echo "=== Post-DST-fix health check $(date -u '+%Y-%m-%d %H:%M UTC') ==="

echo ""
echo "--- Service ---"
echo "Status:  $(systemctl is-active futures-bot)"
echo "PID:     $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime:  $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"

echo ""
echo "--- Deployed code ---"
echo "Head:    $(git log -1 --oneline)"
echo ""
echo "DST fix present in risk_manager.py:"
if grep -q "from zoneinfo import ZoneInfo" futures_bot/core/risk_manager.py; then
  echo "  YES"
  grep -n "zoneinfo\|_ET_TZ" futures_bot/core/risk_manager.py | head -4
else
  echo "  NO - DST fix not deployed yet"
fi
echo ""
echo "DST fix present in news_filter.py:"
if grep -q "from zoneinfo import ZoneInfo" futures_bot/core/news_filter.py; then
  echo "  YES"
else
  echo "  NO - DST fix not deployed yet"
fi

echo ""
echo "--- Import + ET time sanity (does zoneinfo load cleanly?) ---"
PYTHONPATH=/root/MT5-PropFirm-Bot python3 -c "
from futures_bot.core.risk_manager import RiskManager
from futures_bot.core.news_filter import NewsFilter
rm = RiskManager({})
print('RiskManager _get_et_time():', rm._get_et_time())
ok, msg = rm.is_trading_session()
print(f'is_trading_session: ok={ok} msg={msg!r}')
print('must_flatten():', rm.must_flatten())
nf = NewsFilter('configs/restricted_events.json')
print(f'NewsFilter loaded {len(nf.events)} events')
" 2>&1

echo ""
echo "--- Bot log tail (last 30 lines) ---"
tail -30 logs/bot.log 2>/dev/null || echo "(no log file)"

echo ""
echo "--- Recent errors (if any) ---"
grep -iE "error|traceback|exception" logs/bot.log 2>/dev/null | tail -10 || echo "(no recent errors)"
