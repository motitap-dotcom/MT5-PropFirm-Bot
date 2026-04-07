#!/bin/bash
# Trigger: v120 - Force fresh browser auth for TradeDay (TD_Motitap)
cd /root/MT5-PropFirm-Bot
source .env

echo "=== TradeDay Browser Auth v120 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "User: $TRADOVATE_USER"

# Backup and remove Tradovate-Bot's saved token to force fresh auth
cp /root/tradovate-bot/.tradovate_token.json /root/tradovate-bot/.tradovate_token.json.bak 2>/dev/null
rm -f /root/tradovate-bot/.tradovate_token.json

# Override env vars for TradeDay account
export TRADOVATE_USERNAME="$TRADOVATE_USER"
export TRADOVATE_PASSWORD="$TRADOVATE_PASS"
export TRADOVATE_ACCESS_TOKEN=""
export TRADOVATE_ENV="demo"
export TRADOVATE_ORGANIZATION=""
export TRADOVATE_APP_ID=""
export TRADOVATE_CID="0"
export TRADOVATE_SECRET=""
export TRADOVATE_DEVICE_ID="futures-bot-td"

cd /root/tradovate-bot
/root/tradovate-bot/venv/bin/python3 << 'PYEOF'
import sys, os, json, importlib
sys.path.insert(0, "/root/tradovate-bot")

# Force reload config with new env vars
import config
importlib.reload(config)

print(f"Config username: {config.TRADOVATE_USERNAME}")
print(f"Config env: {config.TRADOVATE_ENV}")

from tradovate_api import TradovateAPI
api = TradovateAPI()
print(f"Authenticating...")
success = api.authenticate()
print(f"Result: {success}")

if success and api.access_token:
    # Get accounts
    try:
        accounts = api._get("/account/list")
        print(f"\nAccounts found: {len(accounts)}")
        for a in accounts:
            print(f"  {a.get('name','')} id={a.get('id','')} active={a.get('active','')}")

        # Find TradeDay account
        td_account = None
        for a in accounts:
            name = a.get("name", "")
            if "ELTDER" in name or "TD" in name.upper() or "TRADEDAY" in name.upper():
                td_account = a
                break

        if not td_account and accounts:
            td_account = accounts[0]
            print(f"\nNo TradeDay-specific account found, using first: {td_account.get('name')}")

        token_data = {
            "accessToken": api.access_token,
            "mdAccessToken": getattr(api, "md_access_token", api.access_token),
            "userId": getattr(api, "user_id", 0),
            "expirationTime": getattr(api, "expiration_time", ""),
            "accountSpec": td_account.get("name", "") if td_account else "",
            "accountId": td_account.get("id", 0) if td_account else 0,
        }

        token_path = "/root/MT5-PropFirm-Bot/configs/.tradovate_token.json"
        with open(token_path, "w") as f:
            json.dump(token_data, f, indent=2)
        print(f"\nToken saved to {token_path}")
        print(f"Account: {token_data['accountSpec']}")
    except Exception as e:
        print(f"Error getting accounts: {e}")
else:
    print("Auth FAILED")

PYEOF

# Restore Tradovate-Bot's token
cp /root/tradovate-bot/.tradovate_token.json.bak /root/tradovate-bot/.tradovate_token.json 2>/dev/null
