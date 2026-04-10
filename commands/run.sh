#!/bin/bash
# Trigger: v184 - FULL end-to-end diagnostic
cd /root/MT5-PropFirm-Bot
echo "=== FULL DIAGNOSTIC v184 $(date -u '+%Y-%m-%d %H:%M UTC') ==="

python3 << 'PYEOF'
import json, sys, asyncio
sys.path.insert(0, '/root/MT5-PropFirm-Bot')
from pathlib import Path

# 1. Token check
print("=== 1. TOKEN ===")
tf = Path("configs/.tradovate_token.json")
if tf.exists():
    t = json.loads(tf.read_text())
    print(f"Has access_token: {bool(t.get('access_token'))}")
    print(f"Has md_token: {bool(t.get('md_access_token'))}")
    print(f"Expiry: {t.get('expiry', 'none')}")
    import time
    exp = t.get('expiry', 0)
    remaining = (exp - time.time()) / 60 if exp else -999
    print(f"Remaining: {remaining:.0f} min")
else:
    print("NO TOKEN FILE")

# 2. REST API test
print("\n=== 2. REST API ===")
import requests
token = json.loads(tf.read_text()).get('access_token', '') if tf.exists() else ''
h = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
try:
    r = requests.get("https://demo.tradovateapi.com/v1/account/list", headers=h, timeout=10)
    print(f"Account API: {r.status_code}")
    if r.status_code == 200:
        accs = r.json()
        print(f"Account: {accs[0].get('name')} id={accs[0].get('id')}" if accs else "No accounts")
    else:
        print(f"Error: {r.text[:100]}")
except Exception as e:
    print(f"Request failed: {e}")

# 3. WebSocket test
print("\n=== 3. WEBSOCKET ===")
import websockets

async def test_ws():
    md_token = json.loads(tf.read_text()).get('md_access_token', token) if tf.exists() else token
    try:
        ws = await websockets.connect("wss://md-demo.tradovateapi.com/v1/websocket")
        msg = await asyncio.wait_for(ws.recv(), timeout=5)
        print(f"Connected: {msg}")

        await ws.send(f"authorize\n1\n\n{md_token}")
        resp = await asyncio.wait_for(ws.recv(), timeout=5)
        print(f"Auth: {resp[:100]}")

        # Subscribe to chart
        chart_req = json.dumps({"symbol": "MESM6", "chartDescription": {"underlyingType": "MinuteBar", "elementSize": 5, "elementSizeUnit": "UnderlyingUnits", "withHistogram": False}, "timeRange": {"asMuchAsElements": 3}})
        await ws.send(f"md/getChart\n2\n\n{chart_req}")

        bars_found = False
        for _ in range(20):
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=1)
                if msg == "h":
                    await ws.send("[]")
                elif msg.startswith("a"):
                    data = json.loads(msg[1:])
                    for frame in (data if isinstance(data, list) else [data]):
                        if isinstance(frame, dict):
                            if frame.get("e") == "chart":
                                bars = frame.get("d", {}).get("charts", [{}])[0].get("bars", [])
                                if bars:
                                    print(f"Got {len(bars)} bars!")
                                    print(f"Latest: {bars[-1].get('timestamp')} C={bars[-1].get('close')} upVol={bars[-1].get('upVolume')}")
                                    bars_found = True
                            elif "s" in frame and frame.get("s") == 200:
                                print(f"Subscription OK: {json.dumps(frame)[:100]}")
            except asyncio.TimeoutError:
                continue

        if not bars_found:
            print("NO BARS received!")
        await ws.close()
    except Exception as e:
        print(f"WebSocket error: {e}")

asyncio.run(test_ws())

# 4. Bot process check
print("\n=== 4. BOT PROCESS ===")
import subprocess
result = subprocess.run(["systemctl", "is-active", "futures-bot"], capture_output=True, text=True)
print(f"Service: {result.stdout.strip()}")
result = subprocess.run(["systemctl", "show", "futures-bot", "--property=MainPID", "--value"], capture_output=True, text=True)
print(f"PID: {result.stdout.strip()}")

# Check if code has our fixes
print(f"domcontentloaded: {'YES' if 'domcontentloaded' in open('futures_bot/core/tradovate_client.py').read() else 'NO'}")
print(f"upVolume fix: {'YES' if 'upVolume' in open('futures_bot/bot.py').read() else 'NO'}")
print(f"dist_sd: {'YES' if 'dist_sd' in open('futures_bot/strategies/vwap_mean_reversion.py').read() else 'NO'}")

PYEOF
