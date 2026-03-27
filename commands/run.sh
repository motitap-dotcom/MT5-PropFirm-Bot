#!/bin/bash
# Trigger: v35 - fix push + fresh env vars
echo "=== Bot Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

# STEP 1: Update .env with fresh env vars from workflow
python3 << 'PYEOF'
import os, json, time

token = os.environ.get('TRADOVATE_ACCESS_TOKEN', '').strip()
user = os.environ.get('TRADOVATE_USER', '').strip()
passwd = os.environ.get('TRADOVATE_PASS', '').strip()
tg_token = os.environ.get('TELEGRAM_TOKEN', '').strip()
tg_chat = os.environ.get('TELEGRAM_CHAT_ID', '').strip()

if token:
    with open('.env', 'w') as f:
        f.write(f'TRADOVATE_USER={user}\n')
        f.write(f'TRADOVATE_PASS={passwd}\n')
        f.write(f'TRADOVATE_ACCESS_TOKEN={token}\n')
        f.write(f'TELEGRAM_TOKEN={tg_token}\n')
        f.write(f'TELEGRAM_CHAT_ID={tg_chat}\n')
    print(f".env UPDATED (token={len(token)} chars)")
    # Also update saved token file
    os.makedirs('configs', exist_ok=True)
    with open('configs/.tradovate_token.json', 'w') as f:
        json.dump({"access_token": token, "md_access_token": token,
                    "expiry": time.time() + 86400, "environment": "demo",
                    "organization": "TradeDay"}, f, indent=2)
    print("Token file updated")
else:
    print(".env NOT updated (no env vars from workflow)")

# Show config
with open('configs/bot_config.json') as f:
    c = json.load(f)
print(f"\nSymbols: {c['symbols']}")
print(f"Organization: {c.get('organization','')}")
print(f"Max daily trades: {c['guardian']['max_daily_trades']}")
print(f"Max daily loss: ${c['guardian']['max_daily_loss']}")
print(f"Max daily profit: ${c['guardian']['max_daily_profit']}")
print(f"Max risk/trade: ${c['risk']['max_risk_per_trade']}")
print(f"Max contracts/trade: {c['risk']['max_contracts_per_trade']}")
print(f"Max positions: {c['risk']['max_positions']}")

# Token status
try:
    with open('configs/.tradovate_token.json') as f:
        t = json.load(f)
    remaining = t.get('expiry', 0) - time.time()
    print(f"\nToken expires in: {remaining/3600:.1f} hours")
except:
    print("\nNo saved token")
PYEOF

# STEP 2: Write systemd env override
echo ""
echo "--- Setting up systemd ---"
python3 -c "
import os
if os.path.exists('.env'):
    with open('.env') as f:
        content = f.read()
    os.makedirs('/etc/systemd/system/futures-bot.service.d', exist_ok=True)
    with open('/etc/systemd/system/futures-bot.service.d/env.conf', 'w') as f:
        f.write('[Service]\n')
        for line in content.strip().split('\n'):
            if '=' in line and not line.startswith('#'):
                f.write(f'Environment=\"{line.strip()}\"\n')
    print('Systemd env override written')
"

# STEP 3: Restart bot
echo ""
echo "--- Restarting bot ---"
systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 5

# STEP 4: Check status
echo ""
echo "--- Service ---"
systemctl is-active futures-bot

echo ""
echo "--- Logs (last 20) ---"
tail -20 logs/bot.log 2>/dev/null || journalctl -u futures-bot --no-pager -n 20

echo ""
echo "=== Done ==="
