#!/bin/bash
###############################################
# PropFirmBot Management API - One-Command Install
#
# Usage: bash /root/MT5-PropFirm-Bot/management/install.sh
#
# This installs the management API as a systemd service
# that starts automatically on boot and restarts on failure.
###############################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  PropFirmBot Management API Installer${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

REPO_DIR="/root/MT5-PropFirm-Bot"
SERVER_SCRIPT="$REPO_DIR/management/server.py"
SERVICE_NAME="propfirmbot-mgmt"
PORT=8888

# Check if server.py exists
if [ ! -f "$SERVER_SCRIPT" ]; then
    echo -e "${RED}[ERROR] server.py not found at $SERVER_SCRIPT${NC}"
    echo -e "${YELLOW}Run: cd /root/MT5-PropFirm-Bot && git pull${NC}"
    exit 1
fi

# Step 1: Open firewall port
echo -e "${YELLOW}[1/4] Opening port $PORT in firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow $PORT/tcp 2>/dev/null || true
    echo -e "${GREEN}  ✅ Port $PORT opened (ufw)${NC}"
elif command -v iptables &> /dev/null; then
    iptables -A INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || true
    echo -e "${GREEN}  ✅ Port $PORT opened (iptables)${NC}"
else
    echo -e "${YELLOW}  ⚠️  No firewall tool found, port may already be open${NC}"
fi

# Step 2: Create log directory
echo -e "${YELLOW}[2/4] Creating log directory...${NC}"
mkdir -p /var/log
touch /var/log/propfirmbot-mgmt.log
echo -e "${GREEN}  ✅ Log file ready${NC}"

# Step 3: Create systemd service
echo -e "${YELLOW}[3/4] Creating systemd service...${NC}"
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=PropFirmBot VPS Management API
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$REPO_DIR
ExecStart=/usr/bin/python3 $SERVER_SCRIPT
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=DISPLAY=:99

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}  ✅ Service file created${NC}"

# Step 4: Enable and start service
echo -e "${YELLOW}[4/4] Starting service...${NC}"
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl restart ${SERVICE_NAME}
sleep 2

# Verify
if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  ✅ Management API is RUNNING!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${CYAN}  Port: $PORT${NC}"
    echo -e "${CYAN}  URL:  http://77.237.234.2:$PORT/api/ping${NC}"
    echo -e "${CYAN}  Service: systemctl status $SERVICE_NAME${NC}"
    echo -e "${CYAN}  Logs: journalctl -u $SERVICE_NAME -f${NC}"
    echo ""
    echo -e "${YELLOW}  The API is now accessible remotely.${NC}"
    echo -e "${YELLOW}  Claude can manage everything from here! 🎉${NC}"
else
    echo -e "${RED}  ❌ Service failed to start!${NC}"
    echo -e "${YELLOW}  Check logs: journalctl -u $SERVICE_NAME -n 50${NC}"
    exit 1
fi
