#!/bin/bash
echo "=== TradeDay Futures Bot - Status Check (READ-ONLY) ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Service state ---"
echo "Active: $(systemctl is-active futures-bot 2>/dev/null)"
echo "Enabled: $(systemctl is-enabled futures-bot 2>/dev/null)"
echo "Failed: $(systemctl is-failed futures-bot 2>/dev/null)"
echo ""

echo "--- Current service file ---"
cat /etc/systemd/system/futures-bot.service 2>/dev/null || echo "NOT FOUND"
echo ""

echo "--- /opt/futures_bot_stable/ exists? ---"
ls -la /opt/futures_bot_stable/ 2>/dev/null | head -20 || echo "DIRECTORY GONE"
echo ""

echo "--- /usr/local/sbin/futures-bot-wrapper.sh exists? ---"
ls -la /usr/local/sbin/futures-bot-wrapper.sh 2>/dev/null || echo "WRAPPER GONE"
cat /usr/local/sbin/futures-bot-wrapper.sh 2>/dev/null | head -20
echo ""

echo "--- /root/MT5-PropFirm-Bot/futures_bot/bot.py exists? ---"
ls -la /root/MT5-PropFirm-Bot/futures_bot/bot.py 2>/dev/null || echo "MISSING"
echo ""

echo "--- Recent systemd events for futures-bot (last 2h) ---"
journalctl -u futures-bot --no-pager --since "2 hours ago" 2>/dev/null | tail -30
echo ""

echo "--- Any bot process running anywhere? ---"
ps -ef | grep -iE "futures_bot|bot\.py" | grep -v grep | head -10
echo ""

echo "--- Token file ---"
ls -la /root/MT5-PropFirm-Bot/configs/.tradovate_token.json 2>/dev/null || echo "MISSING"
echo ""

echo "--- Git state on VPS ---"
cd /root/MT5-PropFirm-Bot
echo "Branch: $(git branch --show-current 2>/dev/null)"
echo "HEAD: $(git log -1 --oneline 2>/dev/null)"
echo ""

echo "=== Check Complete ==="
