#!/bin/bash
# Trigger: v117 - Use Tradovate-Bot's auth code to get TradeDay token
cd /root/MT5-PropFirm-Bot
source .env

echo "=== Browser Auth via Tradovate-Bot v117 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "User: $TRADOVATE_USER"

# Use Tradovate-Bot's venv + code to authenticate our TradeDay account
cd /root/tradovate-bot
/root/tradovate-bot/venv/bin/python3 << PYEOF
import sys, os, json
sys.path.insert(0, "/root/tradovate-bot")

# Override config for our TradeDay account
os.environ["TRADOVATE_USERNAME"] = "$TRADOVATE_USER"
os.environ["TRADOVATE_PASSWORD"] = "$TRADOVATE_PASS"
os.environ["TRADOVATE_ENV"] = "demo"
os.environ["TRADOVATE_ORGANIZATION"] = ""
os.environ["TRADOVATE_APP_ID"] = ""
os.environ["TRADOVATE_CID"] = "0"
os.environ["TRADOVATE_SECRET"] = ""
os.environ["TRADOVATE_ACCESS_TOKEN"] = ""
os.environ["TRADOVATE_DEVICE_ID"] = "futures-bot-td"

import importlib
import config
importlib.reload(config)

from tradovate_api import TradovateAPI

api = TradovateAPI()
print(f"Authenticating {config.TRADOVATE_USERNAME}...")
success = api.authenticate()
print(f"Auth result: {success}")

if success and api.access_token:
    token_data = {
        "accessToken": api.access_token,
        "mdAccessToken": getattr(api, "md_access_token", api.access_token),
        "userId": getattr(api, "user_id", 0),
        "expirationTime": getattr(api, "expiration_time", ""),
    }
    # Also get account info
    try:
        accounts = api._get("/account/list")
        if accounts:
            token_data["accountSpec"] = accounts[0].get("name", "")
            token_data["accountId"] = accounts[0].get("id", 0)
            print(f"Account: {token_data['accountSpec']}")
    except:
        pass

    # Save to OUR bot's token file
    token_path = "/root/MT5-PropFirm-Bot/configs/.tradovate_token.json"
    with open(token_path, "w") as f:
        json.dump(token_data, f, indent=2)
    print(f"Token saved to {token_path}!")
    print(f"Expires: {token_data.get('expirationTime', '?')}")
else:
    print("Authentication FAILED")
    print(f"Token: {api.access_token is not None}")
PYEOF
