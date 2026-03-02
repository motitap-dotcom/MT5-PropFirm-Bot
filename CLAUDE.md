# PropFirmBot - הוראות עבודה ל-Claude

## חוקים קבועים (לא משתנים!)

### 1. שפה
- **תמיד לדבר בעברית** - כל תשובה, כל הסבר, כל הודעה
- שם המשתמש: **נועה** (לא מפתחת - צריכה הוראות פשוטות וברורות)

### 2. תקשורת עם השרת - Push & Listen בלבד!
- **אסור בתכלית האיסור** להשתמש ב-SSH ישיר לשרת
- **אסור** להגיד "תריצי את הפקודה הזאת על השרת"
- **אסור** לתת פקודות SSH לנועה להריץ
- כל פעולה על השרת עוברת **רק** דרך GitHub Actions (Push & Listen)

### 3. פרטי סביבה
- מחשב מקומי: **Windows** עם PowerShell
- VPS: **Contabo**, IP `77.237.234.2`, Ubuntu Linux
- טלגרם Bot Token: `8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g`
- טלגרם Chat ID: `7013213983`

---

## שיטת Push & Listen - איך זה עובד

כשצריך לבדוק/לתקן/לעדכן משהו על השרת, התהליך הוא:

```
1. לערוך קובץ בריפו (קוד, config, או קובץ trigger)
2. git commit + git push
3. GitHub Actions workflow רץ אוטומטית על השרת
4. התוצאות נכתבות חזרה לריפו (commit מהשרת)
5. git pull כדי לקרוא את התוצאות
```

### פעולות נפוצות - מה לעשות בכל מצב:

| בקשה | פעולה |
|-------|-------|
| "תבדוק אם הבוט פעיל" | לערוך `trigger-check.txt` עם תאריך/שעה → push → `vps-check` workflow רץ ומחזיר תוצאה ב-`vps_report.txt` |
| "תתקן משהו על השרת" | לערוך את הסקריפט הרלוונטי ב-`scripts/` → push → `vps-fix` workflow מריץ את התיקון → תוצאה ב-`vps_fix_report.txt` |
| "תעשה deploy" | לערוך קבצי EA ב-`EA/` או configs ב-`configs/` → push → `deploy-ea` workflow מעדכן על השרת → תוצאה ב-`deploy_report.txt` |
| "מה המצב?" | לבדוק אם יש קבצי תוצאות עדכניים (vps_report.txt וכו') → אם לא, להפעיל trigger check |

### חשוב - אל תגיד "אני לא יכול לבדוק"!
- אם מבקשים לבדוק את השרת → **תשתמש ב-workflow**
- אם אין workflow מתאים → **תיצור אחד**
- אם `trigger-check.txt` לא קיים → **תיצור אותו**
- **תמיד תנסה לפעול**, לא רק להגיד "אי אפשר"

---

## GitHub Actions Workflows קיימים

### 1. `vps-check.yml` - בדיקת סטטוס VPS
- **טריגר**: push ל-`trigger-check.txt` או `scripts/` (check scripts)
- **מה עושה**: מעלה סקריפט בדיקה לשרת, מריץ, מחזיר תוצאות
- **קובץ תוצאה**: `vps_report.txt`
- **שימוש**: כל פעם שרוצים לדעת אם MT5/EA/VPS פעילים

### 2. `deploy-ea.yml` - דיפלוי EA לשרת
- **טריגר**: push לקבצים ב-`EA/` או `configs/`
- **מה עושה**: מעתיק קבצי EA ו-config לשרת, מקמפל, מדווח
- **קובץ תוצאה**: `deploy_report.txt`
- **שימוש**: עדכון קוד הבוט או הגדרות

### 3. `vps-fix.yml` - תיקון והפעלה מחדש של MT5
- **טריגר**: push ל-`scripts/fix_and_restart.sh` או סקריפטים דומים
- **מה עושה**: מריץ סקריפט תיקון/התקנה על השרת
- **קובץ תוצאה**: `vps_fix_report.txt`
- **שימוש**: כשמשהו לא עובד וצריך restart או תיקון

---

## פרטי הפרויקט

### חשבון מסחר
- חברת Prop Firm: **FundedNext**
- סוג חשבון: **Stellar Instant** (ממומן ישיר - בלי שלב challenge)
- מספר חשבון: `11797849`
- שרת: `FundedNext-Server`
- גודל חשבון: **$2,000**
- חלוקת רווחים: 70% (עד 80%)

### חוקי מסחר (קריטי!)
- **אין** הגבלת drawdown יומי (0%)
- **6% trailing total drawdown** (מנקודת השיא של האקוויטי, לא מהבלאנס ההתחלתי)
- **אין** יעד רווח
- **אין** מינימום ימי מסחר
- מסחר עם EA: **מותר**
- מסחר בחדשות: **מותר** (מקס 40% רווח מיום בודד)
- החזקה בסופ"ש: **מותרת**
- אקוויטי מינימלי: $1,880 ($2,000 - 6%)
- כלל עקביות: מקסימום 40% מסך הרווח ביום בודד

### מודולי EA (11 קבצים)
1. `PropFirmBot.mq5` - EA ראשי
2. `SignalEngine.mqh` - סיגנלים (multi-timeframe)
3. `RiskManager.mqh` - ניהול סיכונים וגודל פוזיציה
4. `TradeManager.mqh` - ביצוע עסקאות
5. `Guardian.mqh` - הגנת drawdown (5 שכבות בטיחות)
6. `Dashboard.mqh` - תצוגה על הצ'ארט
7. `TradeJournal.mqh` - לוג עסקאות
8. `Notifications.mqh` - התראות טלגרם/Push/Email
9. `NewsFilter.mqh` - סינון חדשות
10. `TradeAnalyzer.mqh` - אנליטיקת ביצועים
11. `AccountStateManager.mqh` - ניהול שלבי חשבון

---

## סטטוס עדכני (עדכון אחרון: 2026-03-02)

### מצב VPS
- MT5 רץ על השרת עם PropFirmBot EA פעיל
- חשבון FundedNext מחובר (11797849)
- EA מחובר לצ'ארט EURUSD M15
- AutoTrading דולק (ירוק)
- Wine + VNC עובדים

### מה הושלם
- [x] כל קבצי EA נוצרו ונפרסו
- [x] EA קומפל (PropFirmBot.ex5)
- [x] EA מחובר לצ'ארט
- [x] AutoTrading פעיל
- [x] חשבון FundedNext מחובר

### מה נשאר
- [ ] לוודא שהתראות טלגרם עובדות מה-EA
- [ ] להקים watchdog/monitoring על השרת

---

## How to Resume Work (איך להמשיך עבודה בחלון חדש)

### שלב 1: הבנת המצב
- הפרויקט הוא בוט מסחר MT5 שרץ על VPS של Contabo
- כל התקשורת עם השרת דרך **GitHub Actions בלבד** (Push & Listen)
- הבראנץ' הראשי של העבודה: `claude/build-cfd-trading-bot-fl0ld`

### שלב 2: בדיקת סטטוס
כדי לבדוק מה המצב הנוכחי:
1. לערוך את `trigger-check.txt` (להוסיף שורה עם תאריך/שעה)
2. commit + push
3. לחכות שה-workflow ירוץ
4. `git pull` ולקרוא את `vps_report.txt`

### שלב 3: מבנה הריפו
```
MT5-PropFirm-Bot/
├── CLAUDE.md              ← אתה כאן (הוראות עבודה)
├── EA/                    ← קבצי MQL5 של הבוט
│   ├── PropFirmBot.mq5
│   └── *.mqh (10 modules)
├── configs/               ← קבצי הגדרות JSON
├── scripts/               ← סקריפטים לשרת
├── .github/workflows/     ← GitHub Actions
│   ├── vps-check.yml      ← בדיקת סטטוס
│   ├── deploy-ea.yml      ← דיפלוי EA
│   └── vps-fix.yml        ← תיקון שרת
├── trigger-check.txt      ← טריגר לבדיקת סטטוס
├── vps_report.txt         ← תוצאות בדיקה אחרונה
├── deploy_report.txt      ← תוצאות דיפלוי אחרון
└── vps_fix_report.txt     ← תוצאות תיקון אחרון
```

### שלב 4: נתיבים על השרת (לידיעה)
- MT5: `/root/.wine/drive_c/Program Files/MetaTrader 5/`
- EA: `.../MQL5/Experts/PropFirmBot/`
- Configs: `.../MQL5/Files/PropFirmBot/`
- Repo: `/root/MT5-PropFirm-Bot`

### שלב 5: כללי זהב
1. **עברית** - תמיד
2. **Push & Listen** - אף פעם SSH ישיר
3. **פשוט** - נועה לא מפתחת
4. **פעולה** - אל תגיד "אי אפשר", תמצא דרך
