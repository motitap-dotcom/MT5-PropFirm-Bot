#!/bin/bash
# Trigger: quick-check-v1
cd /root/MT5-PropFirm-Bot
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

TOKEN="eyJraWQiOiIyOCIsImFsZyI6IkVkRFNBIn0.eyJzdWIiOiI3MTg1OTg3IiwiZXhwIjoxNzc0NzYzOTI0LCJqdGkiOiItNjQzMzM4MDM3OTgwNTc2MzQ5My0tNTc2MDk1NTU1NzA2OTQ0NDA1MSIsInBocyI6LTE0OTM4NzI5MDQsImVtYWlsIjoibW90aXRhcEBnbWFpbC5jb20ifQ.iEun7rwIXNNxvmnEXQ8H1NRHuFo8NN_83U8a7XvPb4cJsfmCmJi1Gwm1duMZG-bePlyIM0pUa7tShTP06Xx3Aw"

# Save token file
python3 -c "
import json, time, base64
token='${TOKEN}'
p=token.split('.')[1]
p+='='*(4-len(p)%4)
exp=json.loads(base64.urlsafe_b64decode(p)).get('exp',time.time()+86400)
json.dump({'access_token':token,'md_access_token':token,'expiry':exp,'saved_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())},open('configs/.tradovate_token.json','w'),indent=2)
print(f'Token saved, expires in {(exp-time.time())/3600:.1f}h')
"

# Update .env
sed -i "s|TRADOVATE_ACCESS_TOKEN=.*|TRADOVATE_ACCESS_TOKEN=${TOKEN}|" .env
echo "Updated .env"

# Fix systemd drop-in
source .env
cat > /etc/systemd/system/futures-bot.service.d/env.conf << EOFCONF
[Service]
Environment="TRADOVATE_USER=${TRADOVATE_USER}"
Environment="TRADOVATE_PASS=${TRADOVATE_PASS}"
Environment="TRADOVATE_ACCESS_TOKEN=${TOKEN}"
Environment="TELEGRAM_TOKEN=${TELEGRAM_TOKEN}"
Environment="TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}"
EOFCONF
echo "Fixed systemd drop-in"

# Pull latest code
git fetch origin claude/fix-bot-functionality-h1Sb3
git reset --hard origin/claude/fix-bot-functionality-h1Sb3
mkdir -p logs status

# Restart
systemctl daemon-reload
systemctl restart futures-bot
sleep 5
echo "Bot status: $(systemctl is-active futures-bot)"
journalctl -u futures-bot --no-pager -n 20 --since "10 sec ago"
echo "DONE"
