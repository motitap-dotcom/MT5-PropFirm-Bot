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

## What's Been Done
- [x] All EA files created (PropFirmBot.mq5 + 10 .mqh modules)
- [x] Telegram bot configured with token and chat ID
- [x] All configs updated for Stellar Instant rules (trailing DD, no daily DD)
- [x] Guardian.mqh modified for trailing drawdown (equity high water mark)
- [x] Risk params set: 0.5% per trade, soft DD 3.5%, critical 5.0%, hard 6.0%
- [x] Linux VPS setup scripts ready (Wine + MT5 + monitoring)
- [x] Deploy script updated with all 11 EA files
- [x] All code pushed to branch claude/build-cfd-trading-bot-fl0ld
- [x] VPS setup complete - Wine + MT5 installed on Contabo VPS
- [x] MT5 running on VPS (accessible via VNC)
- [x] FundedNext account connected in MT5 (account 11797849, FundedNext-Server)
- [x] MT5 shows connected and working on VPS

## What's NOT Done Yet (CURRENT STAGE)
- [ ] Deploy EA files to MT5 data folder on VPS
- [ ] Compile EA in MT5 (MetaEditor)
- [ ] Attach EA to EURUSD chart and enable AutoTrading
- [ ] Verify Telegram notifications work from live EA
- [ ] Set up VPS monitoring (watchdog)

## VPS Current State (Updated 2026-02-22)
- MT5 is INSTALLED and RUNNING on VPS
- FundedNext account is LOGGED IN and CONNECTED
- Wine is installed, VNC is accessible
- EA files need to be copied to MT5 data folder and compiled

## Critical Code Changes Made
1. **Guardian.mqh**: Added trailing drawdown - calculates DD from equity high water mark instead of initial balance when `m_trailing_dd=true`. Skips daily DD checks when daily DD limit is 0.
2. **PropFirmBot.mq5**: Default inputs set for Stellar Instant (PHASE_FUNDED, 0 daily DD, 6.0 total DD, Telegram credentials)
3. **All config JSONs**: Updated for 6% trailing DD, no daily limit, funded instant phase

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
- Claude connects directly to VPS via SSH and does everything remotely
- User (Noa) does NOT need to run commands - Claude handles it all
- Noa only needs to confirm/approve actions when asked

## How to Resume Work
- MT5 is running on VPS at 77.237.234.2
- SSH: ssh root@77.237.234.2 (password: Moti0417!)
- VNC for MT5 GUI: connect to 77.237.234.2:5900
- Repo on VPS: /root/MT5-PropFirm-Bot (branch: claude/build-cfd-trading-bot-fl0ld)
- MT5 data folder: find via Wine paths (~/.wine/drive_c/)
