# PropFirmBot - הוראות לעבודה עם Claude

## חוקים קבועים (לא משתנים!)

1. **תמיד לדבר בעברית** - כל התקשורת עם נועה בעברית בלבד
2. **תקשורת עם השרת רק דרך GitHub Actions (Push & Listen)** - אף פעם לא SSH ישיר, אף פעם לא לתת פקודות SSH לנועה, אף פעם לא להגיד "אני לא יכול להתחבר לשרת"
3. **שם המשתמש: נועה** - לא מפתחת, צריכה הוראות פשוטות וברורות
4. **מחשב מקומי:** Windows עם PowerShell
5. **VPS:** Contabo, IP 77.237.234.2, Ubuntu Linux

## שיטת Push & Listen - כך עובדים עם השרת (חובה!)

כשצריך לבדוק/לתקן/לעדכן משהו על השרת, התהליך הוא **תמיד**:

1. לערוך קובץ בריפו (קוד, config, script, או קובץ trigger)
2. לעשות `git commit` + `git push`
3. GitHub Actions workflow רץ **אוטומטית** על השרת
4. התוצאות נכתבות חזרה לריפו (commit מהשרת)
5. לעשות `git pull` כדי לקרוא את התוצאות

### פעולות נפוצות - מה לעשות בכל מצב:

| בקשה מנועה | מה לעשות |
|---|---|
| "תבדוק אם הבוט פעיל" | לערוך `trigger-check.txt` עם תאריך/שעה → push → vps-check workflow רץ → תוצאה ב-`vps_report.txt` |
| "תתקן משהו על השרת" | לערוך את הסקריפט הרלוונטי ב-`scripts/` → push → vps-fix workflow רץ → תוצאה ב-`vps_fix_report.txt` |
| "תעשה deploy" | לערוך קבצי EA ב-`EA/` או configs ב-`configs/` → push → deploy-ea workflow רץ → תוצאה ב-`deploy_report.txt` |
| "מה המצב?" | לבדוק קבצי תוצאות (vps_report.txt, logs) בריפו → אם אין/ישנים, להפעיל trigger check |

### חשוב - אל תגיד "אני לא יכול לבדוק"!

- אם מבקשים לבדוק את השרת → **תשתמש ב-workflow**
- אם אין workflow מתאים → **תיצור אחד**
- אם `trigger-check.txt` לא קיים → **תיצור אותו**
- אם סקריפט בדיקה לא קיים → **תיצור אותו**
- **תמיד תנסה לפעול, לא רק להגיד "אי אפשר"**

## Workflows קיימים (.github/workflows/)

### 1. `vps-check.yml` - VPS Status Check
- **מתי רץ:** כש-push משנה את `trigger-check.txt`, סקריפטים ב-`scripts/`, או workflow_dispatch
- **מה עושה:** מעלה סקריפט בדיקה לשרת, מריץ אותו, שומר תוצאות
- **תוצאה:** `vps_report.txt` (נכתב חזרה לריפו)
- **טריגרים:** `trigger-check.txt`, `scripts/remote_check.sh`, `scripts/deep_check.sh`, `scripts/connection_check.sh`, `scripts/network_check.sh`, `scripts/quick_check.sh`, `scripts/verify_ea.sh`

### 2. `deploy-ea.yml` - Deploy EA to VPS
- **מתי רץ:** כש-push משנה קבצים ב-`EA/` או `configs/`
- **מה עושה:** מעתיק קבצי EA ו-config לשרת, מקמפל מחדש
- **תוצאה:** `deploy_report.txt` + הודעת טלגרם
- **טריגרים:** כל שינוי ב-`EA/**` או `configs/**`

### 3. `vps-fix.yml` - VPS Fix and Restart MT5
- **מתי רץ:** כש-push משנה סקריפטי תיקון
- **מה עושה:** מעלה סקריפט תיקון לשרת ומריץ אותו
- **תוצאה:** `vps_fix_report.txt`
- **טריגרים:** `scripts/fix_and_restart.sh`, `scripts/clean_restart.sh`, `scripts/upgrade_wine.sh`, `scripts/fix_wine_version.sh`, `scripts/force_wine11.sh`, `scripts/install_mt5_linux.sh`

## פרטי הפרויקט

### Prop Firm Account
- **חברה:** FundedNext
- **סוג חשבון:** Stellar Instant (funded ישיר - בלי challenge)
- **מספר חשבון:** 11797849
- **שרת:** FundedNext-Server
- **גודל חשבון:** $2,000
- **חלוקת רווחים:** 70% (עד 80%)

### חוקי מסחר קריטיים (FundedNext Stellar Instant)
- **אין** daily drawdown limit (0%)
- **6% TRAILING total drawdown** (מ-equity high water mark, לא מהבאלנס ההתחלתי!)
- **אין** profit target
- **אין** מינימום ימי מסחר
- EA trading: **מותר**
- News trading: **מותר** (מקסימום 40% רווח מיום בודד)
- Weekend holding: **מותר**
- Min equity: $1,880 ($2,000 - 6%)
- Consistency rule: מקסימום 40% מסך הרווח ביום אחד

### Telegram Bot
- Token: `8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g`
- Chat ID: `7013213983`

### EA Modules (11 קבצים)
1. `PropFirmBot.mq5` - Main EA
2. `SignalEngine.mqh` - Trading signals (multi-timeframe)
3. `RiskManager.mqh` - Position sizing & risk
4. `TradeManager.mqh` - Trade execution
5. `Guardian.mqh` - Drawdown protection (5 safety layers, trailing DD)
6. `Dashboard.mqh` - On-chart display
7. `TradeJournal.mqh` - Trade logging
8. `Notifications.mqh` - Telegram/Push/Email alerts
9. `NewsFilter.mqh` - News event filtering
10. `TradeAnalyzer.mqh` - Performance analytics
11. `AccountStateManager.mqh` - Phase management

### שינויים קריטיים בקוד
1. **Guardian.mqh**: Trailing drawdown - מחשב DD מ-equity high water mark (לא מהבאלנס ההתחלתי) כש-`m_trailing_dd=true`. מדלג על בדיקות daily DD כשהגבול הוא 0.
2. **PropFirmBot.mq5**: Default inputs מוגדרים ל-Stellar Instant (PHASE_FUNDED, 0 daily DD, 6.0 total DD, Telegram credentials)
3. **Config JSONs**: מעודכנים ל-6% trailing DD, ללא daily limit, funded instant phase

## סטטוס עדכני (Updated 2026-03-02)

- MT5 רץ על VPS עם PropFirmBot EA פעיל
- חשבון FundedNext מחובר (11797849)
- EA מחובר ל-EURUSD M15 chart
- AutoTrading דולק (ירוק)
- Wine + VNC עובדים
- הבוט חי וסוחר

### מה בוצע:
- [x] כל קבצי EA נוצרו וקומפלו
- [x] Telegram bot מוגדר
- [x] Configs מעודכנים לחוקי Stellar Instant
- [x] VPS מוגדר עם Wine + MT5
- [x] EA מקומפל ומחובר לגרף
- [x] AutoTrading פעיל

### מה נשאר:
- [ ] לוודא שהודעות Telegram מגיעות מה-EA
- [ ] להגדיר VPS monitoring (watchdog)

## How to Resume Work (לחלון חדש)

### מבנה הפרויקט:
- **ריפו:** `/home/user/MT5-PropFirm-Bot`
- **קבצי EA:** `EA/` (כל 11 הקבצים)
- **Configs:** `configs/` (קבצי JSON)
- **Scripts:** `scripts/` (סקריפטים לשרת)
- **Workflows:** `.github/workflows/` (3 workflows)
- **Trigger file:** `trigger-check.txt`

### על השרת (VPS):
- **MT5 path:** `/root/.wine/drive_c/Program Files/MetaTrader 5/`
- **EA files:** `.../MQL5/Experts/PropFirmBot/`
- **Config files:** `.../MQL5/Files/PropFirmBot/`
- **VNC:** port 5900 על display :99

### איך לבדוק סטטוס:
1. לערוך `trigger-check.txt` (להוסיף תאריך חדש)
2. `git add trigger-check.txt && git commit -m "check status" && git push`
3. לחכות שה-workflow ירוץ (1-2 דקות)
4. `git pull` ולקרוא את `vps_report.txt`

### איך לעשות deploy:
1. לערוך קבצים ב-`EA/` או `configs/`
2. `git add . && git commit -m "update EA" && git push`
3. workflow deploy-ea רץ אוטומטית
4. `git pull` ולקרוא את `deploy_report.txt`

### איך לתקן בעיה בשרת:
1. לערוך/ליצור סקריפט תיקון ב-`scripts/`
2. `git add . && git commit -m "fix: description" && git push`
3. workflow vps-fix רץ אוטומטית
4. `git pull` ולקרוא את `vps_fix_report.txt`

### נועה רואה את MT5 דרך:
- **RealVNC** (על Windows) → `77.237.234.2:5900` (בלי סיסמה)
