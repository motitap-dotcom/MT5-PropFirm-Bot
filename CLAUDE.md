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

### VPS 1 - Linux (MT5 PropFirmBot)
- Provider: Contabo
- IP: 77.237.234.2
- OS: LINUX (Ubuntu)
- SSH root password: Moti0417!
- Contabo panel password: qA4P9f3ra5bw
- Connection method: SSH (not RDP!)
- Connect: ssh root@77.237.234.2
- Purpose: MT5 PropFirmBot for FundedNext

### VPS 2 - Windows (NinjaTrader Competition)
- Provider: Contabo
- IP: 217.77.2.74
- OS: Windows Server
- Connection method: RDP (Remote Desktop)
- Connect: mstsc → 217.77.2.74
- Purpose: NinjaTrader 8 for March Market Madness competition
- Competition account: CHMMMKV5060

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

## What's Been Completed (ALL DONE!)
- [x] Deploy EA files to MT5 data folder on VPS
- [x] EA compiled (PropFirmBot.ex5 - 196KB)
- [x] EA attached to EURUSD M15 chart
- [x] AutoTrading enabled (green button)
- [ ] Verify Telegram notifications work from live EA
- [ ] Set up VPS monitoring (watchdog)

## VPS Current State (Updated 2026-02-22)
- MT5 is RUNNING on VPS with PropFirmBot EA ACTIVE
- FundedNext account LOGGED IN and CONNECTED (account 11797849)
- EA attached to EURUSD M15 chart
- AutoTrading is ON (green)
- Wine + VNC working
- Bot is LIVE and trading

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
- Claude's environment CANNOT SSH to VPS (port 22 blocked from sandbox)
- Noa runs commands on VPS via SSH from her Windows PowerShell
- Noa views MT5 via VNC (RealVNC client on Windows)
- Claude prepares scripts/commands, Noa pastes them

## Noa's Tools
- VNC client: RealVNC (on Windows)
- Terminal: PowerShell (Windows) → SSH to VPS
- SSH: ssh root@77.237.234.2 (password: Moti0417!)

## NinjaTrader Competition Details
- Competition: $20K March Market Madness
- Dates: Mon 02/03/2026 - Sat 07/03/2026
- Starting balance: $50,000 (simulation)
- Max position: 2 contracts per instrument
- Competition account: CHMMMKV5060
- Instruments: ES 03-26, NQ 03-26, CL 04-26
- Bots: MarchMadnessBot (momentum) + MadnessScalper (scalping)
- Branch: claude/ninjatrader-trading-bot-PxnQr
- Files: NinjaTrader/Strategies/ (MarchMadnessBot.cs, MadnessScalper.cs)
- Setup scripts: NinjaTrader/scripts/ (setup-windows-vps.ps1, deploy-strategies.ps1)

## How to Resume Work

### MT5 (Linux VPS - 77.237.234.2):
- MT5 is running on VPS with PropFirmBot EA ACTIVE
- VNC for MT5 GUI: connect to 77.237.234.2:5900 (no password, via RealVNC)
- Repo on VPS: /root/MT5-PropFirm-Bot (branch: claude/build-cfd-trading-bot-fl0ld)
- MT5 installed at: /root/.wine/drive_c/Program Files/MetaTrader 5/
- EA files at: .../MQL5/Experts/PropFirmBot/ (all 11 files + .ex5 compiled)
- Config files at: .../MQL5/Files/PropFirmBot/ (6 JSON files)
- VNC server: x11vnc on display :99, port 5900
- Start VNC: Xvfb :99 -screen 0 1280x1024x24 & x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw

### NinjaTrader (Windows VPS - 217.77.2.74):
- Connect via RDP: mstsc → 217.77.2.74
- Repo: C:\NinjaTrader-Bot\MT5-PropFirm-Bot
- Strategies folder: Documents\NinjaTrader 8\bin\Custom\Strategies\
- Setup script: NinjaTrader\scripts\setup-windows-vps.ps1
- Deploy script: NinjaTrader\scripts\deploy-strategies.ps1
