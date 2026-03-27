#!/bin/bash
# Trigger: v44 - check if bot is trading
echo "=== Trading Status ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
cd /root/MT5-PropFirm-Bot
echo "--- Service ---"
systemctl is-active futures-bot
echo "--- Open Positions ---"
python3 << 'PYEOF'
import os, json
# Read .env
if os.path.exists('.env'):
    with open('.env') as f:
        for line in f:
            if '=' in line and not line.startswith('#'):
                k, v = line.strip().split('=', 1)
                os.environ[k] = v

token = os.environ.get('TRADOVATE_ACCESS_TOKEN', '')
if not token:
    # try saved token
    try:
        with open('configs/.tradovate_token.json') as f:
            d = json.load(f)
            token = d.get('access_token', '')
    except: pass

if token:
    import urllib.request
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    # Account balance
    req = urllib.request.Request("https://demo.tradovateapi.com/v1/account/list", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            accounts = json.loads(resp.read())
            for a in accounts:
                if 'ELTDER' in a.get('name', ''):
                    print(f"Account: {a['name']}")
                    print(f"Balance: ${a.get('balance', '?')}")
                    print(f"Net Liq: ${a.get('netLiq', '?')}")
    except Exception as e:
        print(f"Account error: {e}")

    # Positions
    req = urllib.request.Request("https://demo.tradovateapi.com/v1/position/list", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            positions = json.loads(resp.read())
            open_pos = [p for p in positions if p.get('netPos', 0) != 0]
            if open_pos:
                print(f"\nOpen positions: {len(open_pos)}")
                for p in open_pos:
                    print(f"  {p.get('contractId')} qty={p.get('netPos')} price={p.get('netPrice')}")
            else:
                print(f"\nNo open positions (total records: {len(positions)})")
    except Exception as e:
        print(f"Position error: {e}")

    # Recent orders
    req = urllib.request.Request("https://demo.tradovateapi.com/v1/order/list", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            orders = json.loads(resp.read())
            today_orders = [o for o in orders if '2026-03-27' in o.get('timestamp', '')]
            print(f"\nToday's orders: {len(today_orders)}")
            for o in today_orders[-5:]:
                print(f"  {o.get('action')} {o.get('contractId')} qty={o.get('qty')} status={o.get('ordStatus')} @ {o.get('timestamp','')[:19]}")
    except Exception as e:
        print(f"Orders error: {e}")
else:
    print("No token available!")
PYEOF

echo ""
echo "--- Last 15 log lines (non-error) ---"
grep -v "Traceback\|File \"/\|Exception:" logs/bot.log 2>/dev/null | tail -15
echo "=== Done ==="
