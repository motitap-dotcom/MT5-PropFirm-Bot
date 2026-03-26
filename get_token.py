"""
Tradovate Token Helper
Run this ONCE from a machine with a browser to solve the initial CAPTCHA.
After that, the bot auto-renews the token forever.

Usage:
    python3 get_token.py

Steps:
    1. Sends auth request to Tradovate
    2. If CAPTCHA required: opens browser for you to solve it
    3. Saves token to configs/.tradovate_token.json
    4. Also prints the token so you can set it in .env
"""

import json
import uuid
import time
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("Installing requests...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "requests"])
    import requests

# Configuration
DEMO_URL = "https://demo.tradovateapi.com/v1"
LIVE_URL = "https://live.tradovateapi.com/v1"
TOKEN_FILE = Path("configs/.tradovate_token.json")


def get_token(username: str, password: str, live: bool = False):
    base_url = LIVE_URL if live else DEMO_URL
    device_id = str(uuid.uuid4())

    payload = {
        "name": username,
        "password": password,
        "appId": "tradovate_trader(web)",
        "appVersion": "3.260220.0",
        "deviceId": device_id,
        "cid": 8,
        "sec": "",
        "organization": "",
    }

    print(f"\nConnecting to {'LIVE' if live else 'DEMO'} Tradovate...")
    print(f"Username: {username}")
    print(f"URL: {base_url}")
    print()

    resp = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload)
    data = resp.json()

    # Direct success
    if "accessToken" in data:
        save_token(data)
        return data["accessToken"]

    # CAPTCHA or wait required
    if "p-ticket" in data:
        p_ticket = data["p-ticket"]
        p_time = data.get("p-time", 15)
        p_captcha = data.get("p-captcha", False)

        if p_captcha:
            print("=" * 60)
            print("CAPTCHA REQUIRED")
            print("=" * 60)
            print()
            print("Option 1: Open Tradovate web trader in a browser,")
            print("          log in, then come back and press Enter.")
            print()
            print("Option 2: Use browser DevTools to get the token:")
            print("  1. Go to trader.tradovate.com")
            print("  2. Open DevTools (F12) -> Network tab")
            print("  3. Log in")
            print("  4. Find 'accesstokenrequest' in Network tab")
            print("  5. Copy the accessToken from the response")
            print()

            token = input("Paste your accessToken here (or press Enter to retry): ").strip()

            if token:
                save_manual_token(token)
                return token
            else:
                print(f"\nWaiting {p_time}s and retrying...")
                time.sleep(p_time)

                # Retry with p-ticket
                payload["p-ticket"] = p_ticket
                resp = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload)
                data = resp.json()

                if "accessToken" in data:
                    save_token(data)
                    return data["accessToken"]
        else:
            # Just wait
            print(f"Waiting {p_time}s...")
            time.sleep(p_time)

            payload["p-ticket"] = p_ticket
            resp = requests.post(f"{base_url}/auth/accesstokenrequest", json=payload)
            data = resp.json()

            if "accessToken" in data:
                save_token(data)
                return data["accessToken"]

    print(f"\nAuthentication failed: {data}")
    return None


def save_token(data: dict):
    """Save token response to file."""
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    token_data = {
        "access_token": data["accessToken"],
        "md_access_token": data.get("mdAccessToken", data["accessToken"]),
        "expiry": time.time() + 86400,  # 24h
        "saved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    TOKEN_FILE.write_text(json.dumps(token_data, indent=2))

    print()
    print("=" * 60)
    print("TOKEN SAVED SUCCESSFULLY!")
    print("=" * 60)
    print(f"File: {TOKEN_FILE}")
    print(f"Token: {data['accessToken'][:20]}...")
    print()
    print("You can also add this to .env:")
    print(f"TRADOVATE_ACCESS_TOKEN={data['accessToken']}")
    print()
    print("The bot will auto-renew this token from now on.")


def save_manual_token(token: str):
    """Save a manually obtained token."""
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    token_data = {
        "access_token": token,
        "md_access_token": token,
        "expiry": time.time() + 86400,
        "saved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    TOKEN_FILE.write_text(json.dumps(token_data, indent=2))
    print(f"\nToken saved to {TOKEN_FILE}")
    print("The bot will auto-renew this token from now on.")


if __name__ == "__main__":
    print("=" * 60)
    print("Tradovate Token Helper")
    print("=" * 60)

    username = input("Username [TD_Motitap]: ").strip() or "TD_Motitap"
    password = input("Password: ").strip()

    if not password:
        print("Password required!")
        sys.exit(1)

    env = input("Environment (demo/live) [demo]: ").strip().lower() or "demo"
    live = env == "live"

    token = get_token(username, password, live)

    if token:
        print("\nDone! You can now start the bot.")
    else:
        print("\nFailed to get token. See errors above.")
