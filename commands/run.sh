#!/bin/bash
# Trigger: full-final-check-v1
cd /root/MT5-PropFirm-Bot
echo "============================================================"
echo "  FULL SYSTEM & BOT DIAGNOSTIC"
echo "  $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "============================================================"
echo ""

echo "=== 1. VPS SYSTEM ==="
echo "Uptime: $(uptime -p)"
echo "Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"
echo "Memory: $(free -h | awk '/Mem/{print $3 "/" $2 " used"}')"
echo "Disk: $(df -h / | awk 'NR==2{print $3 "/" $2 " used (" $5 ")"}')"
echo ""

echo "=== 2. BOT SERVICE ==="
echo "Status: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Uptime: $(systemctl show futures-bot --property=ActiveEnterTimestamp --value)"
echo "Restart count: $(systemctl show futures-bot --property=NRestarts --value)"
echo ""

echo "=== 3. TOKEN & AUTH ==="
python3 << 'PYEOF'
import json, time, base64

# Check token file
try:
    d = json.load(open('configs/.tradovate_token.json'))
    token = d.get('access_token', '')
    expiry = d.get('expiry', 0)
    remaining = (expiry - time.time()) / 3600
    print(f"Token file: EXISTS ({len(token)} chars)")
    print(f"Expires in: {remaining:.1f} hours ({'VALID' if remaining > 0 else 'EXPIRED'})")
    print(f"Saved at: {d.get('saved_at', 'unknown')}")

    # Decode JWT
    p = token.split('.')[1]
    p += '=' * (4 - len(p) % 4)
    payload = json.loads(base64.urlsafe_b64decode(p))
    jwt_exp = payload.get('exp', 0)
    jwt_remaining = (jwt_exp - time.time()) / 3600
    print(f"JWT expiry: {jwt_remaining:.1f}h remaining")
except Exception as e:
    print(f"Token check error: {e}")

# Check .env
try:
    env_vars = {}
    for line in open('.env'):
        line = line.strip()
        if '=' in line and not line.startswith('#'):
            k, v = line.split('=', 1)
            env_vars[k] = v
    for key in ['TRADOVATE_USER', 'TRADOVATE_PASS', 'TRADOVATE_ACCESS_TOKEN', 'TELEGRAM_TOKEN', 'TELEGRAM_CHAT_ID']:
        val = env_vars.get(key, '')
        print(f".env {key}: {'SET' if val else 'MISSING'} ({len(val)} chars)")
except Exception as e:
    print(f".env check error: {e}")

# Check systemd drop-in
try:
    content = open('/etc/systemd/system/futures-bot.service.d/env.conf').read()
    # Count properly quoted lines
    lines = [l for l in content.splitlines() if l.startswith('Environment=')]
    properly_quoted = sum(1 for l in lines if l.endswith('"'))
    print(f"Systemd drop-in: {len(lines)} vars, {properly_quoted} properly quoted")
    if properly_quoted < len(lines):
        print("  WARNING: Some Environment lines have broken quoting!")
except Exception as e:
    print(f"Drop-in check error: {e}")
PYEOF
echo ""

echo "=== 4. TRADOVATE API TEST ==="
python3 << 'PYEOF'
import json, urllib.request, urllib.error

token = json.load(open('configs/.tradovate_token.json'))['access_token']
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

# Test account list
try:
    req = urllib.request.Request('https://demo.tradovateapi.com/v1/account/list', headers=headers)
    resp = urllib.request.urlopen(req, timeout=10)
    accounts = json.loads(resp.read())
    for acc in accounts:
        print(f"Account: {acc.get('name', '?')} (ID: {acc.get('id', '?')})")
        print(f"  Active: {acc.get('active', '?')}")
except Exception as e:
    print(f"Account API error: {e}")

# Test balance
try:
    req = urllib.request.Request('https://demo.tradovateapi.com/v1/cashBalance/getCashBalanceSnapshot?accountId=45373493', headers=headers)
    resp = urllib.request.urlopen(req, timeout=10)
    bal = json.loads(resp.read())
    print(f"Balance: ${bal.get('totalCashValue', bal.get('cashBalance', '?'))}")
    print(f"  Realized PnL: ${bal.get('realizedPnL', '?')}")
    print(f"  Unrealized PnL: ${bal.get('openPnL', bal.get('unrealizedPnL', '?'))}")
except Exception as e:
    print(f"Balance API error: {e}")

# Test positions
try:
    req = urllib.request.Request('https://demo.tradovateapi.com/v1/position/list', headers=headers)
    resp = urllib.request.urlopen(req, timeout=10)
    positions = json.loads(resp.read())
    open_pos = [p for p in positions if p.get('netPos', 0) != 0]
    print(f"Open positions: {len(open_pos)}")
    for p in open_pos:
        print(f"  {p.get('contractId')}: {p.get('netPos')} @ {p.get('netPrice', '?')}")
except Exception as e:
    print(f"Position API error: {e}")

# Test orders
try:
    req = urllib.request.Request('https://demo.tradovateapi.com/v1/order/list', headers=headers)
    resp = urllib.request.urlopen(req, timeout=10)
    orders = json.loads(resp.read())
    working = [o for o in orders if o.get('ordStatus') == 'Working']
    print(f"Working orders: {len(working)}")
except Exception as e:
    print(f"Orders API error: {e}")
PYEOF
echo ""

echo "=== 5. CONFIGURATION ==="
python3 << 'PYEOF'
import json

cfg = json.load(open('configs/bot_config.json'))
print(f"Symbols: {cfg.get('symbols', [])}")
print(f"Timeframe: {cfg.get('timeframe', '?')}")
print(f"Live mode: {cfg.get('live', '?')}")

g = cfg.get('guardian', {})
print(f"Guardian: balance=${g.get('initial_balance')}, maxDD=${g.get('max_drawdown')}, target=${g.get('profit_target')}")
print(f"  Daily limits: loss=${g.get('max_daily_loss')}, profit=${g.get('max_daily_profit')}, trades={g.get('max_daily_trades')}")

r = cfg.get('risk', {})
print(f"Risk: max/trade=${r.get('max_risk_per_trade')}, max_pct={r.get('max_risk_pct')}")

events = json.load(open('configs/restricted_events.json'))
upcoming = [e for e in events.get('events', []) if e['date'] >= '2026-03-29']
print(f"Restricted events: {len(events.get('events', []))} total, {len(upcoming)} upcoming")
if upcoming:
    print(f"  Next: {upcoming[0]['date']} {upcoming[0]['time']} - {upcoming[0]['name']}")
PYEOF
echo ""

echo "=== 6. NETWORK ==="
curl -s -o /dev/null -w "Tradovate REST API: HTTP %{http_code} (%{time_total}s)\n" https://demo.tradovateapi.com/v1 --max-time 5
curl -s -o /dev/null -w "Tradovate MD API:   HTTP %{http_code} (%{time_total}s)\n" https://md-demo.tradovateapi.com/v1 --max-time 5
curl -s -o /dev/null -w "Telegram API:       HTTP %{http_code} (%{time_total}s)\n" https://api.telegram.org --max-time 5
echo ""

echo "=== 7. TELEGRAM TEST ==="
python3 << 'PYEOF'
import os, urllib.request, urllib.error, json
# Read from .env
env = {}
for line in open('.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        env[k] = v
token = env.get('TELEGRAM_TOKEN', '')
chat_id = env.get('TELEGRAM_CHAT_ID', '')
if token and chat_id:
    try:
        req = urllib.request.Request(f'https://api.telegram.org/bot{token}/getMe')
        resp = urllib.request.urlopen(req, timeout=5)
        data = json.loads(resp.read())
        bot_name = data.get('result', {}).get('username', 'unknown')
        print(f"Telegram bot: @{bot_name} (connected)")
    except Exception as e:
        print(f"Telegram error: {e}")
else:
    print("Telegram: MISSING token or chat_id")
PYEOF
echo ""

echo "=== 8. PYTHON & DEPENDENCIES ==="
python3 --version
pip3 list 2>/dev/null | grep -E "aiohttp|websockets|requests"
echo ""

echo "=== 9. RECENT BOT LOGS (last 40 lines) ==="
journalctl -u futures-bot --no-pager -n 40 --since "10 min ago"
echo ""

echo "=== 10. ERROR SCAN (last 100 log lines) ==="
journalctl -u futures-bot --no-pager -n 100 | grep -i -E "error|exception|fail|critical|traceback" | tail -10
echo "(showing last 10 error lines, if any)"
echo ""

echo "============================================================"
echo "  DIAGNOSTIC COMPLETE"
echo "============================================================"
