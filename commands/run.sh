#!/bin/bash
echo "=== Quick Status Check ==="
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
systemctl status futures-bot --no-pager 2>/dev/null || echo "Service not installed"
echo ""
cat /root/MT5-PropFirm-Bot/status/status.json 2>/dev/null || echo "No status file"
