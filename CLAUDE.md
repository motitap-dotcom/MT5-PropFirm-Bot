# PropFirmBot - Project Memory

## User Info
- Name: Noa (נועה)
- Language: Hebrew (עברית) - always respond in Hebrew
- Experience level: Not a developer - needs simple, step-by-step instructions
- Local machine: Windows (has PowerShell)

## Account Details
- Prop firm: FundedNext
- Account type: Stellar Instant (direct funded - NO challenge phase)
- Account number: 11797849
- Server: FundedNext-Server
- Password: gazDE62##
- Account size: $2,000
- Profit split: 70% (up to 80%)

## FundedNext Stellar Instant Rules (CRITICAL)
- NO daily drawdown limit (0%)
- 6% TRAILING total drawdown (from equity high water mark, NOT from initial balance)
- NO profit target
- NO minimum trading days
- EA trading: ALLOWED
- News trading: ALLOWED (max 40% profit from single day)
- Weekend holding: ALLOWED
- Min equity at start: $1,880 ($2,000 - 6%)
- Consistency rule: max 40% of total profit in a single day

## Telegram Bot
- Token: 8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
- Chat ID: 7013213983
- Bot is configured and working

## VPS Details
- Provider: Contabo
- IP: 77.237.234.2
- OS: LINUX (Ubuntu) - NOT Windows!
- SSH root password: Moti0417!
- Contabo panel password: qA4P9f3ra5bw
- Connection method: SSH (not RDP!)
- Connect: ssh root@77.237.234.2

## What's Been Done (ALL COMPLETE)
- [x] All EA files created (PropFirmBot.mq5 + 10 .mqh modules)
- [x] Telegram bot configured with token and chat ID
- [x] All configs updated for Stellar Instant rules (trailing DD, no daily DD)
- [x] Guardian.mqh modified for trailing drawdown (equity high water mark)
- [x] Risk params set: 0.5% per trade, soft DD 3.5%, critical 5.0%, hard 6.0%
- [x] Linux VPS setup scripts ready (Wine + MT5 + monitoring)
- [x] Deploy script updated with all 11 EA files
- [x] VPS setup complete - Wine + MT5 installed on Contabo VPS
- [x] MT5 running on VPS (accessible via VNC)
- [x] FundedNext account connected in MT5 (account 11797849, FundedNext-Server)
- [x] EA compiled and loaded on EURUSD M15
- [x] AutoTrading enabled
- [x] Bot is LIVE and TRADING (first trades: 2026-03-04)
- [x] Watchdog cron installed (every 15 min, auto-restart + Telegram alerts)
- [x] GitHub Actions workflows for remote deploy and monitoring

## VPS Current State (Updated 2026-03-04)
- MT5 is RUNNING with PropFirmBot EA ACTIVE
- FundedNext account CONNECTED (account 11797849)
- EA on EURUSD M15, scanning 4 symbols: EURUSD, GBPUSD, USDJPY, XAUUSD
- Balance: ~$1,998 | Equity: ~$2,006 | DD: 0.00%
- 2 open positions (USDJPY BUY + EURUSD SELL) - in profit
- Guardian: ACTIVE | Phase: FUNDED | Risk: 70%
- Watchdog cron: every 15 min (auto-restart + Telegram DD alerts)

## Critical Code Changes Made
1. **Guardian.mqh**: Added trailing drawdown - calculates DD from equity high water mark instead of initial balance when `m_trailing_dd=true`. Skips daily DD checks when daily DD limit is 0.
2. **PropFirmBot.mq5**: Default inputs set for Stellar Instant (PHASE_FUNDED, 0 daily DD, 6.0 total DD, Telegram credentials)
3. **RiskManager.mqh**: Fixed challenge_mode default (was true, now false for funded accounts)
4. **SignalEngine.mqh**: Added SMC and EMA diagnostic logging
5. **All config JSONs**: Updated for 6% trailing DD, no daily limit, funded instant phase

## EA Modules (11 files)
1. PropFirmBot.mq5 - Main EA
2. SignalEngine.mqh - Trading signals (multi-timeframe)
3. RiskManager.mqh - Position sizing & risk
4. TradeManager.mqh - Trade execution
5. Guardian.mqh - Drawdown protection (5 safety layers)
6. Dashboard.mqh - On-chart display
7. TradeJournal.mqh - Trade logging
8. Notifications.mqh - Telegram/Push/Email alerts
9. NewsFilter.mqh - News event filtering
10. TradeAnalyzer.mqh - Performance analytics
11. AccountStateManager.mqh - Phase management (Challenge/Funded/Scaling)

## Working Method
- Claude CAN deploy to VPS via GitHub Actions workflows (SSH through sshpass)
- Workflows: vps-fix.yml (quick deploy), vps-check.yml (diagnostics), deploy-ea.yml (EA deploy)
- Noa can also SSH directly from Windows PowerShell
- VNC for MT5 GUI: RealVNC client on Windows → 77.237.234.2:5900

## GitHub Actions Workflows (IMPORTANT for new sessions)
- **vps-fix.yml**: Quick deploy/fix - triggered by pushing changes to this file
- **vps-check.yml**: Full diagnostics - triggered by pushing scripts/verify_ea.sh or trigger-check.txt
- **deploy-ea.yml**: EA deploy - triggered by pushing EA/** or configs/**
- All workflows use `sshpass` for SSH, separate short commands (not one long one)
- All use `set +e` and `if: always()` on commit step for reliability
- Secrets needed: VPS_IP, VPS_PASSWORD, VPS_USER (already configured in repo)

## Noa's Tools
- VNC client: RealVNC (on Windows)
- Terminal: PowerShell (Windows) → SSH to VPS
- SSH: ssh root@77.237.234.2 (password: Moti0417!)

## How to Resume Work
- MT5 is running on VPS at 77.237.234.2
- VNC for MT5 GUI: connect to 77.237.234.2:5900 (no password, via RealVNC)
- Repo on VPS: /root/MT5-PropFirm-Bot (branch: claude/fix-bot-server-connection-JbPec)
- MT5 installed at: /root/.wine/drive_c/Program Files/MetaTrader 5/
- EA files at: .../MQL5/Experts/PropFirmBot/ (all 11 files + .ex5 compiled)
- Config files at: .../MQL5/Files/PropFirmBot/ (6 JSON files)
- VNC server: x11vnc on display :99, port 5900
- Start VNC: Xvfb :99 -screen 0 1280x1024x24 & x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
- Watchdog: /root/MT5-PropFirm-Bot/scripts/watchdog.sh (cron every 15 min)
- Watchdog log: /var/log/propfirmbot_watchdog.log

## Known Limitations
- MetaEditor CANNOT compile MQL5 on Wine/Linux - .ex5 must be compiled on Windows or kept from previous compilation
- If EA code changes, the old .ex5 still works (current v3.10) - compilation requires Windows MT5
- SSH from Claude sandbox is blocked (outbound port 22) - use GitHub Actions workflows instead
