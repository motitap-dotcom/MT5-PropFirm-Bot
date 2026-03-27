#!/bin/bash
# Trigger: v30 - critical bug fixes from full review
echo "=== Bot Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

cd /root/MT5-PropFirm-Bot

# Read .env and set up env vars via Python (avoids bash ! issue)
python3 << 'PYEOF'
import os, subprocess

# Load .env file into environment
env = {}
if os.path.exists('.env'):
    with open('.env') as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, v = line.split('=', 1)
                env[k] = v
                os.environ[k] = v
    print(f".env loaded ({len(env)} vars, token={len(env.get('TRADOVATE_ACCESS_TOKEN',''))} chars)")
else:
    print("WARNING: No .env file!")

# Show config
import json
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
import time
try:
    with open('configs/.tradovate_token.json') as f:
        t = json.load(f)
    remaining = t.get('expiry', 0) - time.time()
    print(f"\nToken: {t.get('environment','?')} org={t.get('organization','?')}")
    print(f"Expires in: {remaining/3600:.1f} hours")
    if remaining < 0:
        print("TOKEN EXPIRED!")
except:
    print("\nNo saved token file")
PYEOF

echo ""
echo "--- Restarting bot ---"

# Write systemd env override to pass env vars
python3 -c "
import os
if os.path.exists('.env'):
    with open('.env') as f:
        content = f.read()
    # Write systemd override
    os.makedirs('/etc/systemd/system/futures-bot.service.d', exist_ok=True)
    with open('/etc/systemd/system/futures-bot.service.d/env.conf', 'w') as f:
        f.write('[Service]\n')
        for line in content.strip().split('\n'):
            if '=' in line and not line.startswith('#'):
                f.write(f'Environment=\"{line.strip()}\"\n')
    print('Systemd env override written')
"

systemctl daemon-reload
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl start futures-bot
sleep 5

echo ""
echo "--- Service ---"
systemctl is-active futures-bot

echo ""
echo "--- Logs (last 20) ---"
tail -20 logs/bot.log 2>/dev/null || journalctl -u futures-bot --no-pager -n 20

echo ""
echo "=== Done ==="
