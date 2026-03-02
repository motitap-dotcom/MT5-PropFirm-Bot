#!/bin/bash
# ===========================================
# Setup WhatsApp Notification Service on VPS
# ===========================================
# This script is run by GitHub Actions on the VPS.
# It installs and starts the shared WhatsApp service.

set -e

SERVICE_DIR="/root/whatsapp-service"
REPO_DIR="/root/MT5-PropFirm-Bot"
LOG_FILE="$SERVICE_DIR/whatsapp.log"

echo "=== WhatsApp Service Setup ==="
echo "Time: $(date -u '+%Y-%m-%d %H:%M UTC')"

# --- 1. Create service directory ---
echo ""
echo "--- 1. Creating service directory ---"
mkdir -p "$SERVICE_DIR"

# --- 2. Copy files from repo ---
echo "--- 2. Copying files from repo ---"
cp "$REPO_DIR/whatsapp-service/app.py" "$SERVICE_DIR/app.py"
cp "$REPO_DIR/whatsapp-service/requirements.txt" "$SERVICE_DIR/requirements.txt"
echo "Files copied OK"

# --- 3. Create .env if not exists ---
echo "--- 3. Checking .env ---"
if [ -f "$SERVICE_DIR/.env" ]; then
    echo ".env already exists - keeping current values"
else
    echo "Creating .env from template..."
    cp "$REPO_DIR/whatsapp-service/.env.template" "$SERVICE_DIR/.env"
    echo "WARNING: .env created from template - credentials need to be filled in!"
fi

# --- 4. Install Python dependencies ---
echo "--- 4. Installing dependencies ---"
pip3 install -r "$SERVICE_DIR/requirements.txt" -q 2>&1 || {
    echo "pip3 failed, trying with apt..."
    apt-get update -qq
    apt-get install -y -qq python3-pip python3-flask > /dev/null 2>&1
    pip3 install -r "$SERVICE_DIR/requirements.txt" -q 2>&1
}
echo "Dependencies installed OK"

# --- 5. Create systemd service ---
echo "--- 5. Setting up systemd service ---"
cat > /etc/systemd/system/whatsapp-service.service << 'SYSTEMD'
[Unit]
Description=WhatsApp Notification Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/whatsapp-service
EnvironmentFile=/root/whatsapp-service/.env
ExecStart=/usr/local/bin/gunicorn -w 1 -b 127.0.0.1:5050 app:app --access-logfile - --error-logfile /root/whatsapp-service/whatsapp.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD

# --- 6. Start/Restart service ---
echo "--- 6. Starting service ---"
systemctl daemon-reload
systemctl enable whatsapp-service
systemctl restart whatsapp-service
sleep 2

# --- 7. Verify ---
echo "--- 7. Verifying ---"
if systemctl is-active --quiet whatsapp-service; then
    echo "SERVICE STATUS: RUNNING"
    # Test health endpoint
    HEALTH=$(curl -s http://127.0.0.1:5050/health 2>/dev/null || echo "failed")
    echo "Health check: $HEALTH"
else
    echo "SERVICE STATUS: FAILED"
    echo "--- Service logs ---"
    journalctl -u whatsapp-service --no-pager -n 20
fi

echo ""
echo "=== Setup Complete ==="
echo "Service: whatsapp-service"
echo "Port: 5050"
echo "Log: $LOG_FILE"
echo "Send test: curl -X POST http://127.0.0.1:5050/test"
