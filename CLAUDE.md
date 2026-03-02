# PropFirmBot - הוראות ל-Claude

## חוקים קבועים (לא משתנים!)

1. **תמיד לדבר בעברית** - כל תשובה, כל הסבר, הכל בעברית
2. **כל תקשורת עם השרת/VPS רק דרך GitHub Actions (Push & Listen)** - אף פעם לא SSH ישיר, אף פעם לא להגיד "תריצי SSH", אף פעם לא להדביק פקודות SSH
3. **שם המשתמש: נועה (Noa)** - לא מפתחת, צריכה הוראות פשוטות וברורות בעברית
4. **מחשב מקומי: Windows עם PowerShell**
5. **VPS: Contabo, IP 77.237.234.2, Ubuntu Linux**
6. **טלגרם Bot Token:** `8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g`
7. **טלגרם Chat ID:** `7013213983`

---

## שיטת Push & Listen - איך זה עובד (חובה!)

זו השיטה היחידה לתקשורת עם השרת. אין דרך אחרת. לא SSH, לא פקודות ידניות.

### התהליך:
1. **לערוך קובץ בריפו** (קוד, config, סקריפט, או קובץ trigger)
2. **git commit + git push** לבראנץ' הנכון
3. **GitHub Actions workflow רץ אוטומטית** על השרת (מתחבר ב-SSH מ-GitHub, לא מאיתנו)
4. **התוצאות נכתבות חזרה לריפו** (commit מה-workflow)
5. **git pull כדי לקרוא את התוצאות** (קבצי report)

### איך להפעיל בדיקה:
```
1. לערוך trigger-check.txt (לשנות תאריך/שעה)
2. git add trigger-check.txt
3. git commit -m "trigger vps check"
4. git push
5. לחכות ל-workflow שירוץ (~1-2 דקות)
6. git pull
7. לקרוא את vps_report.txt
```

### איך לעשות deploy:
```
1. לערוך קבצים בתיקיות EA/ או configs/
2. git add + commit + push
3. workflow deploy-ea רץ אוטומטית
4. git pull ולקרוא deploy_report.txt
```

### איך לתקן/לאתחל MT5:
```
1. לערוך סקריפט תיקון בתיקיית scripts/
2. git add + commit + push
3. workflow vps-fix רץ אוטומטית
4. git pull ולקרוא vps_fix_report.txt
```

---

## פעולות נפוצות - מה לעשות בכל מצב

| הבקשה | הפעולה |
|--------|--------|
| "תבדוק אם הבוט פעיל" | לערוך `trigger-check.txt` → push → workflow בודק → pull ולקרוא `vps_report.txt` |
| "תתקן משהו על השרת" | לערוך סקריפט תיקון ב-`scripts/` → push → workflow מריץ → pull ולקרוא `vps_fix_report.txt` |
| "תעשה deploy" | לערוך קבצים ב-`EA/` או `configs/` → push → deploy workflow → pull ולקרוא `deploy_report.txt` |
| "מה המצב?" | לבדוק קבצי תוצאות בריפו (`vps_report.txt`, `deploy_report.txt`) → אם ישנים, להפעיל trigger check |
| "תעדכן קוד" | לערוך קבצי EA → push → deploy workflow מעדכן ומקמפל |

---

## חשוב - אל תגיד "אני לא יכול לבדוק"!

- אם מבקשים ממך לבדוק את השרת → **תשתמש ב-workflow** (תערוך trigger-check.txt ותעשה push)
- אם אין workflow מתאים → **תיצור אחד** בתיקיית `.github/workflows/`
- אם `trigger-check.txt` לא קיים → **תיצור אותו**
- אם סקריפט בדיקה לא קיים → **תיצור אותו** בתיקיית `scripts/`
- **תמיד תנסה לפעול, לא רק להגיד "אי אפשר"**
- אף פעם לא להציע לנועה להריץ פקודות SSH בעצמה - הכל דרך Push & Listen

---

## Workflows קיימים

### 1. `deploy-ea.yml` - Deploy EA to VPS
- **טריגר:** push לתיקיות `EA/**` או `configs/**`
- **מה עושה:** מעתיק קבצי EA וקונפיג לשרת, מקמפל את ה-EA, שולח הודעה בטלגרם
- **קובץ תוצאה:** `deploy_report.txt`

### 2. `vps-check.yml` - VPS Status Check
- **טריגר:** push ל-`trigger-check.txt`, סקריפטים ב-`scripts/`, או ה-workflow עצמו
- **מה עושה:** מעלה סקריפט בדיקה לשרת ומריץ אותו, מחזיר דוח סטטוס
- **קובץ תוצאה:** `vps_report.txt`
- **סקריפט שרץ:** `scripts/verify_ea.sh`

### 3. `vps-fix.yml` - VPS Fix and Restart MT5
- **טריגר:** push לסקריפטי תיקון ב-`scripts/` או ה-workflow עצמו
- **מה עושה:** מעלה סקריפט תיקון לשרת ומריץ אותו (restart MT5, תיקוני Wine וכו')
- **קובץ תוצאה:** `vps_fix_report.txt`
- **סקריפט שרץ:** `scripts/install_mt5_linux.sh`

### הערות על Workflows:
- כל ה-workflows עובדים על בראנץ' `claude/build-cfd-trading-bot-fl0ld`
- משתמשים ב-GitHub Secrets: `VPS_IP`, `VPS_PASSWORD`, `VPS_USER`, `TELEGRAM_TOKEN`, `TELEGRAM_CHAT_ID`
- כל workflow כותב את התוצאות חזרה לריפו ב-commit

---

## פרטי הפרויקט

### מהו הפרויקט
בוט מסחר אוטומטי (EA - Expert Advisor) ל-MetaTrader 5 שרץ על VPS של Contabo. הבוט סוחר בחשבון PropFirm של FundedNext.

### פרטי חשבון
- **Prop firm:** FundedNext
- **סוג חשבון:** Stellar Instant (ממומן ישירות - בלי שלב challenge)
- **מספר חשבון:** 11797849
- **שרת:** FundedNext-Server
- **סיסמה:** gazDE62##
- **גודל חשבון:** $2,000
- **חלוקת רווחים:** 70% (עד 80%)

### חוקי מסחר של FundedNext Stellar Instant (קריטי!)
- **אין** הגבלת drawdown יומי (0%)
- **6% trailing total drawdown** (מנקודת השיא של ה-equity, לא מהיתרה ההתחלתית)
- **אין** יעד רווח
- **אין** מינימום ימי מסחר
- מסחר EA: **מותר**
- מסחר חדשות: **מותר** (מקס 40% רווח מיום בודד)
- החזקה בסופ"ש: **מותרת**
- equity מינימלי: $1,880 ($2,000 - 6%)
- חוק עקביות: מקס 40% מהרווח הכולל ביום בודד

### מודולי EA (11 קבצים)
1. `PropFirmBot.mq5` - EA ראשי
2. `SignalEngine.mqh` - איתותי מסחר (מולטי-טיימפריים)
3. `RiskManager.mqh` - גודל פוזיציות וסיכון
4. `TradeManager.mqh` - ביצוע עסקאות
5. `Guardian.mqh` - הגנת drawdown (5 שכבות בטיחות)
6. `Dashboard.mqh` - תצוגה על הגרף
7. `TradeJournal.mqh` - יומן עסקאות
8. `Notifications.mqh` - התראות טלגרם/Push/Email
9. `NewsFilter.mqh` - סינון אירועי חדשות
10. `TradeAnalyzer.mqh` - אנליטיקת ביצועים
11. `AccountStateManager.mqh` - ניהול שלבים (Challenge/Funded/Scaling)

### הגדרות סיכון
- 0.5% לעסקה
- Soft DD: 3.5%
- Critical DD: 5.0%
- Hard DD: 6.0% (trailing)

---

## סטטוס עדכני (עודכן 2026-03-02)

- MT5 רץ על VPS עם PropFirmBot EA פעיל
- חשבון FundedNext מחובר (11797849)
- EA מחובר לגרף EURUSD M15
- AutoTrading דולק (ירוק)
- Wine + VNC עובדים
- הבוט LIVE

### מה הושלם:
- [x] כל קבצי EA נוצרו ונפרסו
- [x] EA קומפל (PropFirmBot.ex5)
- [x] EA מחובר לגרף
- [x] AutoTrading פעיל
- [x] VPS מוגדר עם Wine + MT5
- [x] GitHub Actions workflows מוגדרים

### מה עוד לא נבדק:
- [ ] אימות שהתראות טלגרם עובדות מה-EA החי
- [ ] הגדרת watchdog monitoring
- [ ] אימות שהבוט באמת מבצע עסקאות

---

## How to Resume Work (איך להמשיך עבודה מחלון חדש)

### המצב:
- MT5 רץ על VPS ב-77.237.234.2
- ריפו על VPS: `/root/MT5-PropFirm-Bot`
- MT5 מותקן ב: `/root/.wine/drive_c/Program Files/MetaTrader 5/`
- קבצי EA ב: `.../MQL5/Experts/PropFirmBot/`
- קבצי Config ב: `.../MQL5/Files/PropFirmBot/`
- VNC: port 5900 (ללא סיסמה)

### הבראנץ'ים:
- **בראנץ' עבודה ראשי:** `claude/build-cfd-trading-bot-fl0ld`
- **Workflows עובדים על:** אותו בראנץ'

### לבדוק סטטוס שרת:
1. לערוך `trigger-check.txt` (לעדכן תאריך)
2. `git commit + push`
3. לחכות ל-workflow
4. `git pull` ולקרוא `vps_report.txt`

### לעדכן קוד:
1. לערוך קבצים ב-`EA/` או `configs/`
2. `git commit + push`
3. Deploy workflow רץ אוטומטית

### כלי נועה:
- VNC: RealVNC על Windows → `77.237.234.2:5900`
- Terminal: PowerShell → (אין צורך ב-SSH, הכל דרך Git + GitHub Actions)
