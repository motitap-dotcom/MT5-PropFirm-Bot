# PropFirmBot - הוראות לעבודה עם Claude

## חוקים קבועים (לא משתנים!)

### 1. שפה
- **תמיד לדבר בעברית** - כל תשובה, כל הסבר, הכל בעברית

### 2. תקשורת עם השרת - Push & Listen בלבד!
- **אסור SSH ישיר** - אף פעם, בשום מצב
- כל פעולה על השרת עוברת דרך **GitHub Actions** בלבד
- שיטת העבודה: Push קובץ לריפו -> Workflow רץ על השרת -> תוצאות חוזרות כ-commit

### 3. פרטי המשתמשת
- **שם**: נועה (Noa)
- **רמה**: לא מפתחת - צריכה הוראות פשוטות, ברורות, צעד אחרי צעד
- **מחשב מקומי**: Windows עם PowerShell

### 4. פרטי VPS
- **ספק**: Contabo
- **IP**: 77.237.234.2
- **מערכת הפעלה**: Ubuntu Linux
- **חיבור לצפייה**: VNC (RealVNC) - פורט 5900

### 5. טלגרם
- **Token**: 8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
- **Chat ID**: 7013213983

---

## שיטת Push & Listen - התהליך המלא

### איך זה עובד:
```
[Claude עורך קובץ] → [git commit + push] → [GitHub Actions רץ על השרת] → [תוצאות נכתבות לריפו] → [git pull לקריאת תוצאות]
```

### צעדים:
1. **לערוך** קובץ בריפו (קוד, config, סקריפט, או קובץ trigger)
2. **לעשות** `git commit` + `git push`
3. **GitHub Actions** workflow רץ אוטומטית על השרת
4. **התוצאות** נכתבות חזרה לריפו כ-commit מהשרת
5. **לעשות** `git pull` כדי לקרוא את התוצאות

### טריגרים - מה מפעיל כל workflow:
- **deploy-ea.yml** - מופעל כש-push משנה קבצים ב-`EA/**` או `configs/**`
- **vps-check.yml** - מופעל כש-push משנה את `trigger-check.txt` או סקריפטים ב-`scripts/`
- **vps-fix.yml** - מופעל כש-push משנה סקריפטי תיקון ב-`scripts/`

---

## פעולות נפוצות - מה לעשות בכל מצב

| הבקשה | מה לעשות |
|--------|-----------|
| "תבדוק אם הבוט פעיל" | לערוך `trigger-check.txt` עם תאריך/שעה -> push -> workflow בודק ומחזיר `vps_report.txt` |
| "תתקן משהו על השרת" | לערוך את הסקריפט הרלוונטי ב-`scripts/` -> push -> workflow מריץ ומחזיר `vps_fix_report.txt` |
| "תעשה deploy" | לערוך קבצי EA ב-`EA/` או configs ב-`configs/` -> push -> deploy workflow מעדכן ומחזיר `deploy_report.txt` |
| "מה המצב?" | לבדוק קבצי תוצאות בריפו (`vps_report.txt`, `deploy_report.txt`) -> אם ישנים, להפעיל trigger check |
| "תריץ סקריפט על השרת" | לשים את הסקריפט ב-`scripts/` -> לוודא שה-workflow מתאים -> push |

### חשוב - אל תגיד "אני לא יכול לבדוק"!
- אם מבקשים לבדוק את השרת - **תשתמש ב-workflow**
- אם אין workflow מתאים - **תיצור אחד**
- אם `trigger-check.txt` לא קיים - **תיצור אותו**
- **תמיד תנסה לפעול**, לא רק להגיד "אי אפשר"

---

## Workflows קיימים

### 1. `deploy-ea.yml` - Deploy EA to VPS
- **טריגר**: שינוי ב-`EA/**` או `configs/**`
- **מה עושה**: מעתיק קבצי EA ו-config לשרת, מקמפל, שולח הודעת טלגרם
- **תוצאה**: `deploy_report.txt`
- **Branch**: claude/build-cfd-trading-bot-fl0ld

### 2. `vps-check.yml` - VPS Status Check
- **טריגר**: שינוי ב-`trigger-check.txt` או סקריפטי בדיקה ב-`scripts/`
- **מה עושה**: מעתיק סקריפט בדיקה לשרת ומריץ אותו
- **תוצאה**: `vps_report.txt`
- **Branch**: claude/build-cfd-trading-bot-fl0ld

### 3. `vps-fix.yml` - VPS Fix and Restart MT5
- **טריגר**: שינוי בסקריפטי תיקון ב-`scripts/`
- **מה עושה**: מעתיק סקריפט תיקון לשרת ומריץ אותו
- **תוצאה**: `vps_fix_report.txt`
- **Branch**: claude/build-cfd-trading-bot-fl0ld

---

## פרטי הפרויקט - PropFirmBot

### חשבון מסחר
- **חברת Prop**: FundedNext
- **סוג חשבון**: Stellar Instant (funded ישיר - בלי שלב challenge)
- **מספר חשבון**: 11797849
- **שרת**: FundedNext-Server
- **גודל חשבון**: $2,000
- **חלוקת רווח**: 70% (עד 80%)

### חוקי מסחר - Stellar Instant (קריטי!)
- **אין** daily drawdown (0%)
- **6% trailing total drawdown** (מ-equity high water mark, לא מהיתרה ההתחלתית!)
- **אין** profit target
- **אין** מינימום ימי מסחר
- EA trading: **מותר**
- News trading: **מותר** (מקסימום 40% רווח מיום בודד)
- Weekend holding: **מותר**
- Min equity: $1,880 ($2,000 - 6%)
- Consistency rule: מקסימום 40% מסך הרווח ביום בודד

### פרמטרי סיכון של הבוט
- 0.5% סיכון לעסקה
- Soft DD: 3.5%
- Critical DD: 5.0%
- Hard DD: 6.0%

### מודולי EA (11 קבצים)
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

---

## סטטוס עדכני

### מצב נוכחי (עודכן 2026-03-02)
- MT5 **רץ** על השרת עם PropFirmBot EA **פעיל**
- חשבון FundedNext **מחובר** (11797849)
- EA מחובר לצ'ארט EURUSD M15
- AutoTrading **דולק** (ירוק)
- Wine + VNC **עובדים**
- הבוט **LIVE** ומוכן למסחר

### מה הושלם
- [x] כל קבצי ה-EA נוצרו וקומפלו
- [x] טלגרם בוט מוגדר
- [x] Configs מעודכנים לחוקי Stellar Instant
- [x] VPS מוגדר (Wine + MT5 + VNC)
- [x] EA deployed ומקומפל על השרת
- [x] EA מחובר לצ'ארט עם AutoTrading דולק
- [x] GitHub Actions workflows עובדים (deploy, check, fix)

### מה נשאר
- [ ] לוודא שהודעות טלגרם עובדות מה-EA החי
- [ ] להגדיר VPS monitoring (watchdog)

---

## How to Resume Work - איך להמשיך מחלון חדש

### מיקומים חשובים על השרת
- **ריפו**: `/root/MT5-PropFirm-Bot`
- **MT5**: `/root/.wine/drive_c/Program Files/MetaTrader 5/`
- **קבצי EA**: `.../MQL5/Experts/PropFirmBot/` (11 קבצים + .ex5)
- **Configs**: `.../MQL5/Files/PropFirmBot/` (6 JSON files)
- **VNC**: `x11vnc` על display :99, פורט 5900

### Branch ראשי לעבודה
- `claude/build-cfd-trading-bot-fl0ld` - הענף שבו כל ה-workflows רצים

### צעדים ראשונים בחלון חדש
1. לקרוא את הקובץ הזה (CLAUDE.md) להבנת הפרויקט
2. לבדוק סטטוס: לערוך `trigger-check.txt` -> push -> לקרוא `vps_report.txt`
3. אם צריך לתקן: להשתמש ב-workflows המתאימים
4. **לזכור**: הכל דרך Push & Listen, אף פעם לא SSH ישיר!

### כלים של נועה
- **VNC**: RealVNC על Windows -> מתחבר ל-77.237.234.2:5900
- **Terminal**: PowerShell על Windows
- נועה יכולה לצפות ב-MT5 דרך VNC ולראות את הצ'ארטים
