#!/bin/bash
# Trigger: v152-api-test
cd /root/MT5-PropFirm-Bot
echo "=== v152 API Test $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""

# Test the Tradovate API directly
python3 << 'PYEOF'
import json, asyncio, sys
sys.path.insert(0, '.')

async def test():
    from futures_bot.core.tradovate_client import TradovateClient
    import os

    client = TradovateClient(
        username=os.environ.get("TRADOVATE_USER", ""),
        password=os.environ.get("TRADOVATE_PASS", ""),
        live=False,
        organization=""
    )

    try:
        await client.connect()
        print(f"Connected: account={client.account_id}")

        # Test balance
        balance = await client.get_account_balance()
        print(f"Balance: {json.dumps(balance, indent=2)}")

        # Test contract lookup
        for sym in ["MESM6", "MES", "MNQM6"]:
            try:
                result = await client.find_contract(sym)
                print(f"find_contract({sym}): {json.dumps(result, indent=2)[:200]}")
            except Exception as e:
                print(f"find_contract({sym}): ERROR - {e}")

        # Test suggest (front month)
        for sym in ["MES", "MNQ"]:
            try:
                result = await client.suggest_contract(sym)
                print(f"suggest({sym}): {json.dumps(result, indent=2)[:200]}")
            except Exception as e:
                print(f"suggest({sym}): ERROR - {e}")

        # Test historical bars
        for sym in ["MESM6", "MES"]:
            try:
                bars = await client.get_historical_bars(sym, "5min", count=5)
                print(f"bars({sym}): got {len(bars)} bars")
                if bars:
                    print(f"  Last bar: {json.dumps(bars[-1], indent=2)[:200]}")
                else:
                    # Try raw call to see full response
                    raw = await client._post("/md/getChart", {
                        "symbol": sym,
                        "chartDescription": {
                            "underlyingType": "MinuteBar",
                            "elementSize": 5,
                            "elementSizeUnit": "UnderlyingUnits",
                            "withHistogram": False,
                        },
                        "timeRange": {"asMuchAsElements": 5},
                    })
                    print(f"  Raw response: {json.dumps(raw, indent=2)[:300]}")
            except Exception as e:
                print(f"bars({sym}): ERROR - {e}")

        # Check positions
        positions = await client.get_positions()
        print(f"Positions: {len(positions)} open")

        await client.disconnect()
    except Exception as e:
        print(f"FATAL: {e}")
        import traceback
        traceback.print_exc()

asyncio.run(test())
PYEOF

echo ""
echo "=== END ==="
