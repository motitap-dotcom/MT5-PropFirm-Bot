#!/bin/bash
# Trigger: post-deploy-check-v1
cd /root/MT5-PropFirm-Bot
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""
echo "Bot status: $(systemctl is-active futures-bot)"
echo ""
echo "=== Last 30 log lines ==="
journalctl -u futures-bot --no-pager -n 30 --since "5 min ago"
echo ""
echo "=== Token file ==="
python3 -c "
import json, time
d=json.load(open('configs/.tradovate_token.json'))
remaining=(d['expiry']-time.time())/3600
print(f'Token expires in: {remaining:.1f}h ({\"VALID\" if remaining>0 else \"EXPIRED\"})')
print(f'Saved at: {d.get(\"saved_at\",\"unknown\")}')
"
echo "DONE"
