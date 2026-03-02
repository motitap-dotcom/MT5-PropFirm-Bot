"""
WhatsApp Notification Service - שירות התראות וואטסאפ משותף
כל הבוטים על השרת שולחים הודעות דרך השירות הזה.

שימוש:
  POST http://127.0.0.1:5050/send  {"message": "טקסט ההודעה"}
  GET  http://127.0.0.1:5050/health
"""

import os
import json
import logging
from datetime import datetime
from flask import Flask, request, jsonify
import requests as http_requests

# --- הגדרות ---
app = Flask(__name__)

LOG_FILE = "/root/whatsapp-service/whatsapp.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

# משתני סביבה (נטענים מ-.env)
WHATSAPP_TOKEN = os.environ.get("WHATSAPP_TOKEN", "")
WHATSAPP_PHONE_ID = os.environ.get("WHATSAPP_PHONE_ID", "")
MY_PHONE_NUMBER = os.environ.get("MY_PHONE_NUMBER", "")

GRAPH_API_URL = f"https://graph.facebook.com/v21.0/{WHATSAPP_PHONE_ID}/messages"


def send_whatsapp_message(message: str, to_number: str = None) -> dict:
    """שולח הודעת וואטסאפ למספר שלי"""
    target = to_number or MY_PHONE_NUMBER
    if not target:
        return {"ok": False, "error": "no phone number configured"}

    if not WHATSAPP_TOKEN or not WHATSAPP_PHONE_ID:
        return {"ok": False, "error": "WhatsApp credentials not configured"}

    headers = {
        "Authorization": f"Bearer {WHATSAPP_TOKEN}",
        "Content-Type": "application/json"
    }

    payload = {
        "messaging_product": "whatsapp",
        "to": target,
        "type": "text",
        "text": {"body": message}
    }

    try:
        resp = http_requests.post(GRAPH_API_URL, headers=headers, json=payload, timeout=10)
        result = resp.json()

        if resp.status_code == 200:
            msg_id = result.get("messages", [{}])[0].get("id", "unknown")
            log.info(f"Message sent OK | to={target} | id={msg_id}")
            return {"ok": True, "message_id": msg_id}
        else:
            error = result.get("error", {}).get("message", "unknown error")
            log.error(f"WhatsApp API error: {resp.status_code} | {error}")
            return {"ok": False, "error": error, "status_code": resp.status_code}

    except http_requests.exceptions.Timeout:
        log.error("WhatsApp API timeout")
        return {"ok": False, "error": "timeout"}
    except Exception as e:
        log.error(f"Send failed: {e}")
        return {"ok": False, "error": str(e)}


# --- API Endpoints ---

@app.route("/send", methods=["POST"])
def api_send():
    """שליחת הודעה - כל הבוטים קוראים לכאן"""
    data = request.get_json(silent=True) or {}
    message = data.get("message", "").strip()

    if not message:
        return jsonify({"ok": False, "error": "missing 'message' field"}), 400

    # הוספת שם הבוט להודעה אם צוין
    bot_name = data.get("bot_name", "")
    if bot_name:
        message = f"[{bot_name}] {message}"

    result = send_whatsapp_message(message)
    status_code = 200 if result["ok"] else 500
    return jsonify(result), status_code


@app.route("/health", methods=["GET"])
def api_health():
    """בדיקת תקינות"""
    return jsonify({
        "status": "ok",
        "service": "whatsapp-notification",
        "time": datetime.utcnow().isoformat(),
        "configured": bool(WHATSAPP_TOKEN and WHATSAPP_PHONE_ID and MY_PHONE_NUMBER)
    })


@app.route("/test", methods=["POST"])
def api_test():
    """שליחת הודעת טסט"""
    result = send_whatsapp_message(f"Test message from WhatsApp Service\n{datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}")
    status_code = 200 if result["ok"] else 500
    return jsonify(result), status_code


if __name__ == "__main__":
    log.info("WhatsApp Notification Service starting...")
    log.info(f"Phone ID configured: {bool(WHATSAPP_PHONE_ID)}")
    log.info(f"Token configured: {bool(WHATSAPP_TOKEN)}")
    log.info(f"My number configured: {bool(MY_PHONE_NUMBER)}")
    app.run(host="127.0.0.1", port=5050)
