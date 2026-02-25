#!/bin/bash
# ====================================
# PropFirmBot - Full Status Check
# ====================================

echo ""
echo "================================================"
echo "  PropFirmBot - Status Check $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "================================================"

# 1. MT5 Running?
echo ""
echo "--- [1] MT5 Process ---"
MT5_PID=$(ps aux | grep terminal64 | grep -v grep | awk '{print $2}' | tail -1)
if [ -n "$MT5_PID" ]; then
  echo "✅ MT5 RUNNING (PID: $MT5_PID)"
  MT5_UPTIME=$(ps -p $MT5_PID -o etime= 2>/dev/null | tr -d ' ')
  echo "   Uptime: $MT5_UPTIME"
else
  echo "❌ MT5 NOT RUNNING!"
fi

# 2. VNC Running?
echo ""
echo "--- [2] VNC Status ---"
if pgrep x11vnc > /dev/null; then
  echo "✅ VNC running (port 5900)"
else
  echo "⚠️  VNC not running"
fi

# 3. Network Connection
echo ""
echo "--- [3] Network / FundedNext Connection ---"
CONN=$(ss -tn | grep ':443' | head -5)
if [ -n "$CONN" ]; then
  echo "✅ Active connections:"
  echo "$CONN" | while read line; do echo "   $line"; done
else
  echo "⚠️  No outbound HTTPS connections"
fi

# 4. Latest EA Log
echo ""
echo "--- [4] EA Log (last 30 lines) ---"
EA_LOG=$(find /root/.wine -name "PropFirmBot*.log" 2>/dev/null | sort | tail -1)
if [ -n "$EA_LOG" ]; then
  LOG_SIZE=$(wc -c < "$EA_LOG")
  LOG_DATE=$(date -r "$EA_LOG" '+%Y-%m-%d %H:%M:%S')
  echo "Log file: $EA_LOG"
  echo "Size: $LOG_SIZE bytes | Last modified: $LOG_DATE"
  echo ""
  tail -30 "$EA_LOG"
else
  echo "⚠️  No EA log file found"
  # Try alternative location
  ALT=$(find /root/.wine -name "*.log" 2>/dev/null | xargs grep -l "PropFirmBot" 2>/dev/null | tail -1)
  if [ -n "$ALT" ]; then
    echo "Found alternative: $ALT"
    tail -20 "$ALT"
  fi
fi

# 5. Status JSON
echo ""
echo "--- [5] Status JSON (real-time data) ---"
STATUS_JSON=$(find /root/.wine -name "status.json" 2>/dev/null | head -1)
if [ -n "$STATUS_JSON" ]; then
  echo "✅ Found: $STATUS_JSON"
  cat "$STATUS_JSON"
else
  echo "⚠️  No status.json found"
fi

# 6. Trade Journal
echo ""
echo "--- [6] Trade Journal (last 10 trades) ---"
JOURNAL=$(find /root/.wine -name "PropFirmBot_Journal*.csv" 2>/dev/null | sort | tail -1)
if [ -n "$JOURNAL" ]; then
  TRADE_COUNT=$(wc -l < "$JOURNAL")
  echo "Journal: $JOURNAL"
  echo "Total lines: $TRADE_COUNT"
  echo ""
  tail -10 "$JOURNAL"
else
  echo "⚠️  No trade journal found"
fi

# 7. Watchdog
echo ""
echo "--- [7] Watchdog ---"
if pgrep -f watchdog > /dev/null; then
  echo "✅ Watchdog running"
elif [ -f /root/watchdog.sh ]; then
  echo "⚠️  Watchdog script exists but NOT running!"
  echo "   Run: nohup bash /root/watchdog.sh &"
else
  echo "⚠️  No watchdog"
fi

# 8. Disk & Memory
echo ""
echo "--- [8] System Resources ---"
echo "Memory:"
free -h | grep -E "Mem|Swap"
echo "Disk:"
df -h / | tail -1

# 9. Summary
echo ""
echo "================================================"
echo "  SUMMARY"
echo "================================================"

ISSUES=0

if [ -z "$MT5_PID" ]; then
  echo "❌ MT5 is DOWN - needs restart!"
  ISSUES=$((ISSUES+1))
else
  echo "✅ MT5 is running"
fi

if [ -z "$EA_LOG" ]; then
  echo "⚠️  EA log not found - check if EA is attached"
  ISSUES=$((ISSUES+1))
else
  # Check if EA log has recent activity (last 2 hours)
  RECENT=$(find /root/.wine -name "PropFirmBot*.log" -newer /tmp/2h_ago 2>/dev/null)
  if [ -n "$RECENT" ]; then
    echo "✅ EA is active (recent log activity)"
  else
    echo "⚠️  EA log not updated recently (EA might be stuck)"
  fi
fi

if [ $ISSUES -eq 0 ]; then
  echo ""
  echo "🟢 BOT STATUS: OK - Running normally"
else
  echo ""
  echo "🔴 BOT STATUS: $ISSUES issue(s) found!"
fi

echo "================================================"
echo ""
