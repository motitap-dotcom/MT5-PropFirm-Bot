#!/bin/bash
# =============================================================
# Setup .env file on VPS with all credentials
# Run this ON the VPS to create the .env file
# =============================================================

ENV_FILE="/root/.env"

echo "Creating $ENV_FILE..."

cat > "$ENV_FILE" << 'ENVEOF'
# PropFirmBot Environment Configuration
# Created: $(date '+%Y-%m-%d %H:%M UTC')

# Telegram Bot
TELEGRAM_TOKEN=8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
TELEGRAM_CHAT_ID=7013213983

# MT5 Account
MT5_ACCOUNT=11797849
MT5_SERVER=FundedNext-Server

# VPS Info
VPS_IP=77.237.234.2
ENVEOF

chmod 600 "$ENV_FILE"
echo "Done! .env created at $ENV_FILE with secure permissions (600)"
echo ""
echo "Contents (masked):"
grep -v '^#\|^$' "$ENV_FILE" | while IFS='=' read -r key val; do
    key=$(echo "$key" | tr -d ' ')
    [ -n "$key" ] && echo "  $key = ${val:0:6}..."
done
