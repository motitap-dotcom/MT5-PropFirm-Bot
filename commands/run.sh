#!/bin/bash
# Trigger: v155 - test WebSocket chart data
cd /root/MT5-PropFirm-Bot
echo "=== WEBSOCKET CHART TEST v155 $(date -u '+%Y-%m-%d %H:%M UTC') ==="

python3 << 'PYEOF'
import json, asyncio, sys
sys.path.insert(0, '/root/MT5-PropFirm-Bot')
from pathlib import Path
import websockets

async def test_ws_chart():
    # Load token
    token_data = json.loads(Path("configs/.tradovate_token.json").read_text())
    md_token = token_data.get("md_access_token") or token_data.get("access_token")
    print(f"MD token loaded: {bool(md_token)}")

    # Connect to MD WebSocket
    ws_url = "wss://md-demo.tradovateapi.com/v1/websocket"
    ws = await websockets.connect(ws_url)

    # Wait for open frame
    msg = await ws.recv()
    print(f"Open frame: {msg}")

    # Authenticate
    auth_msg = f"authorize\n1\n\n{md_token}"
    await ws.send(auth_msg)
    response = await ws.recv()
    print(f"Auth response: {response[:200]}")

    # Subscribe to chart data for MESM6
    chart_req = {
        "symbol": "MESM6",
        "chartDescription": {
            "underlyingType": "MinuteBar",
            "elementSize": 5,
            "elementSizeUnit": "UnderlyingUnits",
            "withHistogram": False,
        },
        "timeRange": {
            "asMuchAsElements": 10,
        },
    }
    req_id = 2
    chart_msg = f"md/getChart\n{req_id}\n\n{json.dumps(chart_req)}"
    await ws.send(chart_msg)
    print(f"\nSent md/getChart for MESM6...")

    # Also try md/subscribeQuote
    req_id2 = 3
    quote_msg = f"md/subscribeQuote\n{req_id2}\n\n{json.dumps({'symbol': 'MESM6'})}"
    await ws.send(quote_msg)
    print(f"Sent md/subscribeQuote for MESM6...")

    # Listen for responses (up to 15 seconds)
    bars_found = False
    for i in range(30):
        try:
            msg = await asyncio.wait_for(ws.recv(), timeout=0.5)
            if msg == "h":
                await ws.send("[]")
                continue
            if msg.startswith("a"):
                data = json.loads(msg[1:])
                for frame in (data if isinstance(data, list) else [data]):
                    if isinstance(frame, dict):
                        event = frame.get("e", "")
                        s = frame.get("s", "")
                        d = frame.get("d", {})
                        if "bars" in d or "bars" in frame:
                            bars = d.get("bars", frame.get("bars", []))
                            print(f"\nGot {len(bars)} bars! Event={event}")
                            if bars:
                                print(f"  First: {bars[0]}")
                                print(f"  Last: {bars[-1]}")
                                bars_found = True
                        elif "charts" in d or "id" in d:
                            print(f"Chart response: {json.dumps(frame)[:300]}")
                        elif event == "md" or "entries" in d:
                            print(f"Quote data: {json.dumps(frame)[:300]}")
                            bars_found = True
                        else:
                            print(f"Frame: {json.dumps(frame)[:300]}")
            else:
                print(f"Other: {msg[:200]}")
        except asyncio.TimeoutError:
            continue

    if not bars_found:
        print("\nNo bars/quotes received via WebSocket")

    await ws.close()

asyncio.run(test_ws_chart())
PYEOF
