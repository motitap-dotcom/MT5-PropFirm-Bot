#!/bin/bash
# Trigger: v154-ws-debug
cd /root/MT5-PropFirm-Bot
echo "=== v154 WS Debug $(date -u '+%Y-%m-%d %H:%M UTC') ==="

python3 << 'PYEOF'
import json, asyncio, os, sys
sys.path.insert(0, '.')
import websockets

async def test():
    from futures_bot.core.tradovate_client import TradovateClient, TOKEN_FILE

    # Load token
    token_data = json.loads(TOKEN_FILE.read_text())
    token = token_data.get("md_access_token") or token_data.get("access_token")
    print(f"Using token: {token[:20]}...")

    # Connect to MD WebSocket
    ws_url = "wss://md-demo.tradovateapi.com/v1/websocket"
    print(f"Connecting to {ws_url}...")

    ws = await websockets.connect(ws_url)

    # Get open frame
    msg = await ws.recv()
    print(f"Open frame: {repr(msg)}")

    # Auth
    auth_msg = f"authorize\n1\n\n{token}"
    await ws.send(auth_msg)
    msg = await ws.recv()
    print(f"Auth response: {repr(msg[:500])}")

    # Request chart data
    req_id = 42
    payload = json.dumps({
        "symbol": "MESM6",
        "chartDescription": {
            "underlyingType": "MinuteBar",
            "elementSize": 5,
            "elementSizeUnit": "UnderlyingUnits",
            "withHistogram": False,
        },
        "timeRange": {
            "asMuchAsElements": 5,
        },
    })

    chart_msg = f"md/getChart\n{req_id}\n\n{payload}"
    print(f"\nSending: {chart_msg[:100]}...")
    await ws.send(chart_msg)

    # Listen for responses
    print("\n--- Raw WS messages (10s) ---")
    try:
        for i in range(20):
            msg = await asyncio.wait_for(ws.recv(), timeout=2)
            print(f"MSG[{i}]: {repr(msg[:500])}")
            if msg == "h":
                await ws.send("[]")
    except asyncio.TimeoutError:
        print("(timeout - no more messages)")
    except Exception as e:
        print(f"Error: {e}")

    await ws.close()
    print("\nDone")

asyncio.run(test())
PYEOF

echo "=== END ==="
