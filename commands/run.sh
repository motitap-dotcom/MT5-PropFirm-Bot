#!/bin/bash
# Trigger: full-check-v1 — comprehensive verification
cd /root/MT5-PropFirm-Bot

echo "=== FULL BOT VERIFICATION ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "ET Time: $(TZ='America/New_York' date '+%H:%M %Z')"
echo ""

echo "=== 1. SERVICE STATUS ==="
systemctl is-active futures-bot
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime since: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Restarts: $(systemctl show futures-bot --property=NRestarts --value 2>/dev/null || echo N/A)"
MEM=$(ps -p $(systemctl show futures-bot --property=MainPID --value) -o rss= 2>/dev/null)
echo "Memory: $((${MEM:-0}/1024))MB"
echo ""

echo "=== 2. SYSTEMD SERVICE FILE ==="
cat /etc/systemd/system/futures-bot.service
echo ""
echo "--- Drop-ins:"
ls /etc/systemd/system/futures-bot.service.d/ 2>/dev/null || echo "No drop-ins"
echo ""

echo "=== 3. TOKEN STATUS ==="
python3 -c "
import json, time
d = json.loads(open('configs/.tradovate_token.json').read())
exp = d.get('expiry', 0)
remaining = exp - time.time()
print(f'Token saved at: {d.get(\"saved_at\", \"unknown\")}')
print(f'Expires in: {remaining/60:.0f} minutes')
if remaining < 0:
    print('STATUS: EXPIRED!')
elif remaining < 900:
    print('STATUS: EXPIRING SOON')
else:
    print('STATUS: VALID')
" 2>/dev/null || echo "No token file!"
echo ""

echo "=== 4. .ENV FILE ==="
if [ -f .env ]; then
    echo "File exists"
    # Show keys only, not values
    grep -oP '^[A-Z_]+' .env | sort
else
    echo ".env MISSING!"
fi
echo ""

echo "=== 5. CONFIG VALIDATION ==="
venv/bin/python -c "
import json
c = json.loads(open('configs/bot_config.json').read())
print(f'Live mode: {c.get(\"live\", \"NOT SET\")}')
print(f'Symbols: {c.get(\"symbols\", [])}')
print(f'Telegram: {c.get(\"telegram_enabled\", False)}')
g = c.get('guardian', {})
print(f'Max drawdown: \${g.get(\"max_drawdown\", \"?\")}')
print(f'Profit target: \${g.get(\"profit_target\", \"?\")}')
print(f'Max daily loss: \${g.get(\"max_daily_loss\", \"?\")}')
print(f'Max daily profit: \${g.get(\"max_daily_profit\", \"?\")}')
print(f'Max daily trades: {g.get(\"max_daily_trades\", \"?\")}')
r = c.get('risk', {})
print(f'Max risk/trade: \${r.get(\"max_risk_per_trade\", \"?\")}')
print(f'Max positions: {r.get(\"max_positions\", \"?\")}')
print(f'Max contracts/trade: {r.get(\"max_contracts_per_trade\", \"?\")}')
" 2>/dev/null || echo "Config error"
echo ""

echo "=== 6. PYTHON IMPORTS ==="
venv/bin/python -c "
import futures_bot; print('futures_bot: OK')
from futures_bot.core.tradovate_client import TradovateClient; print('TradovateClient: OK')
from futures_bot.core.guardian import Guardian; print('Guardian: OK')
from futures_bot.core.risk_manager import RiskManager; print('RiskManager: OK')
from futures_bot.core.news_filter import NewsFilter; print('NewsFilter: OK')
from futures_bot.core.notifier import TelegramNotifier; print('Notifier: OK')
from futures_bot.core.status_writer import StatusWriter; print('StatusWriter: OK')
from futures_bot.strategies.vwap_mean_reversion import VWAPMeanReversion; print('VWAP: OK')
from futures_bot.strategies.orb_breakout import ORBBreakout; print('ORB: OK')
from playwright.async_api import async_playwright; print('Playwright: OK')
" 2>&1
echo ""

echo "=== 7. FILES ON DISK ==="
echo "futures_bot/:"
ls -la futures_bot/*.py futures_bot/core/*.py futures_bot/strategies/*.py 2>/dev/null | awk '{print $NF}'
echo ""
echo "configs/:"
ls -la configs/ 2>/dev/null | awk '{print $NF}'
echo ""
echo "status/:"
ls -la status/ 2>/dev/null | awk '{print $NF}'
echo ""
echo "logs/:"
ls -la logs/ 2>/dev/null | awk '{print $NF}'
echo ""

echo "=== 8. LAST 50 JOURNAL LINES ==="
journalctl -u futures-bot --no-pager -n 50
echo ""

echo "=== 9. BOT LOG (last 30 lines) ==="
tail -30 logs/bot.log 2>/dev/null || echo "No bot log"
echo ""

echo "=== 10. DISK & MEMORY ==="
df -h / | tail -1
free -h | head -2
echo ""

echo "=== DONE ==="
