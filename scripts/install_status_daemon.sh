#!/bin/bash
#=============================================================================
# Install MT5 Status Daemon
# Reads EA status + journal, writes /var/bots/mt5_status.json every 5 sec
# Run: bash /root/MT5-PropFirm-Bot/scripts/install_status_daemon.sh
#=============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_SRC="/root/MT5-PropFirm-Bot/scripts/mt5_status_daemon.py"
SERVICE_NAME="mt5-status-daemon"

echo -e "${YELLOW}[1/3] Creating systemd service...${NC}"

cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=MT5 Status JSON Daemon
After=network.target mt5.service
Wants=mt5.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${SCRIPT_SRC}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}[OK]${NC}"

echo -e "${YELLOW}[2/3] Enabling and starting service...${NC}"
mkdir -p /var/bots
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service 2>/dev/null
systemctl restart ${SERVICE_NAME}.service
echo -e "${GREEN}[OK]${NC}"

echo -e "${YELLOW}[3/3] Verifying...${NC}"
sleep 6
if [ -f /var/bots/mt5_status.json ]; then
    echo -e "${GREEN}[OK] /var/bots/mt5_status.json created successfully${NC}"
    echo ""
    echo "Content preview:"
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
else
    echo -e "${RED}[WARN] File not created yet - check: journalctl -u ${SERVICE_NAME} -f${NC}"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo "  Status: systemctl status ${SERVICE_NAME}"
echo "  Logs:   journalctl -u ${SERVICE_NAME} -f"
echo "  Output: cat /var/bots/mt5_status.json"
