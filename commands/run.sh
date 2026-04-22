#!/bin/bash
cd /root/MT5-PropFirm-Bot
PID=$(systemctl show futures-bot --property=MainPID --value)
echo "=== $(date -u '+%H:%M UTC') PID=$PID ==="
echo ""
echo "--- process state ---"
ps -o pid,stat,etime,pcpu,pmem,cmd -p "$PID" 2>&1
echo ""
echo "--- open connections (tradovate?) ---"
ss -tnp 2>/dev/null | grep -E "$PID|tradovate" | head -10
echo ""
echo "--- py-spy-style check: what the process is doing (via /proc) ---"
cat /proc/$PID/status 2>/dev/null | grep -E "^State|^Threads|^VmRSS"
echo ""
echo "--- wchan for each thread (what syscall is it blocked on) ---"
for tid in $(ls /proc/$PID/task/ 2>/dev/null); do
  wc=$(cat /proc/$PID/task/$tid/wchan 2>/dev/null)
  echo "  tid=$tid wchan=$wc"
done | head -15
echo ""
echo "--- strace 3 seconds ---"
timeout 3 strace -p $PID -f -e trace=network,read,write,select,poll,epoll_wait 2>&1 | head -30
echo ""
echo "--- bot log last 5 lines ---"
tail -5 logs/bot.log
