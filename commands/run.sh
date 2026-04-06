#!/bin/bash
# Trigger: v104 - ONLY copy token, nothing else
cd /root/MT5-PropFirm-Bot
echo "=== v104 ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo ""
echo "Looking for token..."
ls -la /root/tradovate-bot/.tradovate_token.json 2>&1
ls -la /root/tradovate-bot/.tradovate_token* 2>&1
ls -la /root/tradovate-bot/configs/.tradovate_token* 2>&1
echo ""
if [ -f /root/tradovate-bot/.tradovate_token.json ]; then
    cp /root/tradovate-bot/.tradovate_token.json configs/.tradovate_token.json
    echo "COPIED!"
    cat configs/.tradovate_token.json | python3 -c "import sys,json; t=json.load(sys.stdin); print(f'Expires: {t.get(\"expirationTime\",\"?\")}')" 2>&1
elif [ -f /root/tradovate-bot/configs/.tradovate_token.json ]; then
    cp /root/tradovate-bot/configs/.tradovate_token.json configs/.tradovate_token.json
    echo "COPIED from configs/!"
else
    echo "No token file found in tradovate-bot"
    find /root/tradovate-bot -name "*token*" -type f 2>/dev/null | head -10
fi
