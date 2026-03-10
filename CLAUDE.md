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

## Version History

### v4.0 - Trend + Momentum (2026-03-10) ← CURRENT VERSION
- **שינוי אסטרטגיה מלא**: עברנו מ-SMC (Smart Money Concepts) ל-Trend + Momentum
- **אסטרטגיה חדשה**:
  - H1 EMA50 קובע כיוון מגמה (trend filter)
  - M15 EMA 8/21 crossover לתזמון כניסה
  - RSI מאשר מומנטום (לא overbought/oversold)
  - MACD histogram מאשר כיוון מומנטום
  - ATR לגודל SL/TP דינמי
- **Guardian מעודכן**: soft DD 4.0%, critical 5.2%, max 6 הפסדים רצופים, max 12 עסקאות ביום
- **Risk מעודכן**: 0.5% לעסקה, max 3 פוזיציות, risk multiplier 0.85 ב-funded mode
- **ענף מקור**: `claude/redesign-bot-strategy-woBVq`

### v3.01 (2026-03-10)
- Bump version קטן, ניסיון deploy לשרת
- ענף: `claude/update-bot-deployment-Ej25j`

### v3.1 (2026-03-10)
- שינוי version number לטריגר deploy
- ענף: `claude/enable-github-actions-38lPd`

### v3.0 (2026-02-22) - הגרסה המקורית
- אסטרטגיית SMC (Smart Money Concepts) - Order Blocks, Fair Value Gaps
- Guardian עם trailing drawdown
- 11 מודולים מלאים
- ענף: `claude/build-cfd-trading-bot-fl0ld`

---

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
- [x] **v4.0 strategy redesign** - Trend + Momentum replaces SMC (2026-03-10)

## VPS Current State (Updated 2026-03-10 16:28 UTC)
- MT5: **RUNNING** with PropFirmBot EA v4.0
- FundedNext account: **CONNECTED** (account 11797849)
- EA: **ACTIVE** on EURUSD M15 chart, scanning EURUSD/GBPUSD/USDJPY/XAUUSD
- Balance: **$1,980.22** | DD: 0.00%
- Guardian: **ACTIVE** | Risk: 85%
- Watchdog: **ACTIVE** (cron every 2 minutes, auto-restart + Telegram alert)
- VNC: port 5900 (RealVNC, no password)

## ⚠️ PROVEN DEPLOY METHOD (MUST USE!) ⚠️

**MetaEditor on Wine does NOT reliably produce .ex5 files!**
**MT5 auto-compiles .mq5 files when loading from chart profile.**

### Deploy steps (tested and working 2026-03-10):
```bash
# 1. Pull latest code
cd /root/MT5-PropFirm-Bot && git fetch && git reset --hard origin/<branch>

# 2. Copy files to MT5
cp EA/*.mq5 EA/*.mqh "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/"
cp configs/*.json "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/"

# 3. Stop MT5
pkill -f terminal64.exe; sleep 3; pkill -9 -f terminal64.exe

# 4. Start MT5 (auto-compiles EA from chart profile)
export DISPLAY=:99 WINEPREFIX=/root/.wine
nohup setsid wine "/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" /portable >/dev/null 2>&1 &
disown -a

# 5. Wait 20s, then verify EA loaded
sleep 20
iconv -f UTF-16LE -t UTF-8 ".../MQL5/Logs/$(date +%Y%m%d).log" | grep PropFirmBot | tail -5
```

### Critical rules:
- **DO NOT use MetaEditor** for compilation - it compiles but .ex5 doesn't persist on Wine
- **DO NOT use `wineserver -w`** - it hangs forever waiting for Wine processes
- **ALWAYS use `nohup setsid ... & disown -a`** to start MT5 (prevents SSH hang)
- **ALWAYS use `pkill -f terminal64.exe`** before restart (release file locks)
- **Verify by reading EA log** (not by checking .ex5 file)
- The `commands/run.sh` file contains the working deploy script - use it as template

### Watchdog (auto-restart):
- Script: `/root/mt5_watchdog.sh`
- Runs every 2 minutes via cron
- Checks if MT5 is running, restarts if not
- Sends Telegram alert on restart
- Also ensures Xvfb and VNC are running
- Install: `(crontab -l; echo "*/2 * * * * /root/mt5_watchdog.sh") | crontab -`

## Critical Code Changes Made
1. **SignalEngine.mqh (v4.0)**: Complete rewrite - EMA 8/21 crossover + RSI + MACD + H1 EMA50 trend filter (replaced SMC strategy)
2. **Guardian.mqh**: Trailing drawdown from equity high water mark. v4.0: soft 4.0%, critical 5.2%, max 12 trades/day
3. **PropFirmBot.mq5 (v4.0)**: Trend + Momentum strategy, ATR-based SL/TP, simplified inputs
4. **RiskManager.mqh (v4.0)**: Updated risk params, 0.85 multiplier for funded, max 3 positions
5. **All config JSONs**: Updated for v4.0 strategy parameters

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
- Repo on VPS: /root/MT5-PropFirm-Bot (active branch set by deploy)
- MT5 installed at: /root/.wine/drive_c/Program Files/MetaTrader 5/
- EA files at: .../MQL5/Experts/PropFirmBot/ (12 source files, MT5 auto-compiles)
- Config files at: .../MQL5/Files/PropFirmBot/ (6 JSON files)
- EA logs at: .../MQL5/Logs/YYYYMMDD.log (UTF-16LE encoded, use iconv to read)
- VNC server: x11vnc on display :99, port 5900
- Start VNC: Xvfb :99 -screen 0 1280x1024x24 & x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
- Watchdog: /root/mt5_watchdog.sh (cron every 2 min, auto-restart + Telegram alert)
- Watchdog log: /root/mt5_watchdog.log
