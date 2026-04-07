#!/bin/bash
# Trigger: v142
cd /root/MT5-PropFirm-Bot
echo "=== v142 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
journalctl -u futures-bot --no-pager -n 20 --since "5 min ago" 2>&1
