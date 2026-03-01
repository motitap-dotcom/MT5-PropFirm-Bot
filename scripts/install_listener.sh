#!/bin/bash
#=============================================================================
# PropFirmBot - Install Telegram Listener as Service
# מתקין את המאזין כ-systemd service שרץ ברקע תמיד
# הפעלה: bash install_listener.sh
#=============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Installing Telegram Listener Service${NC}"
echo -e "${CYAN}========================================${NC}"

SCRIPT_DIR="/root/MT5-PropFirm-Bot/scripts"

# Make scripts executable
chmod +x "$SCRIPT_DIR/telegram_listener.sh"
chmod +x "$SCRIPT_DIR/verify_bot_live.sh"
chmod +x "$SCRIPT_DIR/send_status_telegram.sh"

# Create systemd service
cat > /etc/systemd/system/propfirmbot-listener.service << EOF
[Unit]
Description=PropFirmBot Telegram Command Listener
After=network.target mt5.service
Wants=mt5.service

[Service]
Type=simple
User=root
ExecStart=/bin/bash $SCRIPT_DIR/telegram_listener.sh
Restart=always
RestartSec=10
StandardOutput=append:/root/PropFirmBot/logs/telegram_listener_service.log
StandardError=append:/root/PropFirmBot/logs/telegram_listener_service.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable propfirmbot-listener.service
systemctl start propfirmbot-listener.service

echo ""
echo -e "${GREEN}[OK] Telegram Listener installed and started!${NC}"
echo ""
echo -e "${CYAN}Commands:${NC}"
echo -e "  Status:  ${YELLOW}systemctl status propfirmbot-listener${NC}"
echo -e "  Logs:    ${YELLOW}journalctl -u propfirmbot-listener -f${NC}"
echo -e "  Restart: ${YELLOW}systemctl restart propfirmbot-listener${NC}"
echo -e "  Stop:    ${YELLOW}systemctl stop propfirmbot-listener${NC}"
echo ""

# Add cron for quick status every 4 hours
CRON_TMP=$(mktemp)
crontab -l 2>/dev/null > "$CRON_TMP" || true
sed -i '/send_status_telegram/d' "$CRON_TMP"
echo "0 */4 * * * /bin/bash $SCRIPT_DIR/send_status_telegram.sh  # PropFirmBot status every 4h" >> "$CRON_TMP"
crontab "$CRON_TMP"
rm "$CRON_TMP"

echo -e "${GREEN}[OK] Auto status report every 4 hours configured${NC}"
echo ""
echo -e "${CYAN}Now open Telegram and type /help to test!${NC}"
