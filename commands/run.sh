#!/bin/bash
# Trigger: verify-fix-v1
cd /root/MT5-PropFirm-Bot
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "Bot status: $(systemctl is-active futures-bot)"
echo ""
journalctl -u futures-bot --no-pager -n 25 --since "3 min ago"
echo ""
python3 -c "
import json, time
d=json.load(open('configs/.tradovate_token.json'))
remaining=(d['expiry']-time.time())/3600
print(f'Token: {remaining:.1f}h remaining ({\"VALID\" if remaining>0 else \"EXPIRED\"})')
"
echo "DONE"
