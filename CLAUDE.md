# PropFirmBot - Project Memory

## ⚠️ MANDATORY WORKFLOW - READ FIRST ⚠️

**כל אינטראקציה עם ה-VPS חייבת לעבור דרך הריפו בלבד!**

Claude **לא יכול** להתחבר ישירות ל-VPS (פורט 22 חסום מה-sandbox).
הדרך היחידה לנהל את הבוט, לבדוק סטטוס, להריץ פקודות, לעדכן קוד - היא:

### שיטת העבודה (Push & Listen):
```
Claude עושה שינוי בריפו → Push ל-GitHub → GitHub Actions מריץ על VPS → תוצאה חוזרת לריפו
```

### פקודות זמינות (GitHub Actions Workflows):

| פעולה | איך להפעיל | קובץ תוצאה |
|-------|------------|-------------|
| **בדיקת סטטוס VPS** | לערוך `commands/check_status.sh` ולדחוף | `commands/output.txt` |
| **הרצת פקודה על VPS** | לכתוב פקודה ב-`commands/run.sh` ולדחוף | `commands/output.txt` |
| **עדכון קוד EA** | לערוך קבצים ב-`EA/` או `configs/` ולדחוף | `deploy_report.txt` |
| **תיקון ואתחול MT5** | לערוך `scripts/fix_and_restart.sh` ולדחוף | `vps_fix_report.txt` |

### זרימת עבודה לכל בקשה:

1. **בקשת סטטוס**: כתוב סקריפט ב-`commands/run.sh` → push → המתן לתוצאה ב-`commands/output.txt`
2. **שינוי קוד**: ערוך קבצי EA/configs → push → GitHub Actions מעדכן ומקמפל על VPS
3. **תיקון בעיה**: כתוב סקריפט תיקון ב-`commands/run.sh` → push → בדוק תוצאה
4. **קבלת לוגים**: כתוב פקודת לוג ב-`commands/run.sh` → push → קרא תוצאה

### חשוב מאוד:
- **אף פעם** אל תנסה SSH ישירות - זה לא יעבוד
- **אף פעם** אל תבקש מנועה להריץ פקודות ידנית - תשתמש ב-workflow
- **תמיד** תעבוד דרך push → GitHub Actions → תוצאה בריפו
- אחרי push, תמתין כ-30-60 שניות ואז תעשה `git pull` לקרוא את התוצאה
- הענף הפעיל ל-workflows: נקבע אוטומטית לפי `${{ github.ref }}`

---

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
- [x] GitHub Actions workflows configured (deploy, check, fix, run commands)

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
- ALL VPS operations go through: push to repo → GitHub Actions → VPS execution → results in repo
- Available workflows: vps-command (run anything), deploy-ea (update code), vps-check (status), vps-fix (restart)
- After pushing, wait ~30-60 seconds then git pull to read results
- Noa can also SSH manually from PowerShell if needed: ssh root@77.237.234.2

## Noa's Tools
- VNC client: RealVNC (on Windows)
- Terminal: PowerShell (Windows) → SSH to VPS
- SSH: ssh root@77.237.234.2 (password: Moti0417!)

## How to Resume Work
- MT5 is running on VPS at 77.237.234.2
- VNC for MT5 GUI: connect to 77.237.234.2:5900 (no password, via RealVNC)
- Repo on VPS: /root/MT5-PropFirm-Bot (branch: claude/build-cfd-trading-bot-fl0ld)
- MT5 installed at: /root/.wine/drive_c/Program Files/MetaTrader 5/
- EA files at: .../MQL5/Experts/PropFirmBot/ (all 11 files + .ex5 compiled)
- Config files at: .../MQL5/Files/PropFirmBot/ (6 JSON files)
- VNC server: x11vnc on display :99, port 5900
- Start VNC: Xvfb :99 -screen 0 1280x1024x24 & x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
