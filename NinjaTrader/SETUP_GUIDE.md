# מדריך התקנה - NinjaTrader על Windows VPS

## פרטי שרת
- **IP:** 217.77.2.74
- **OS:** Windows Server
- **Provider:** Contabo
- **חיבור:** RDP (Remote Desktop)

## פרטי התחרות
- **שם:** $20K March Market Madness
- **תאריכים:** שני 02/03/2026 16:30 - שבת 07/03/2026 00:00
- **יתרת פתיחה:** $50,000 (סימולציה)
- **מכשירים:** ES, NQ, CL (+ 3 נוספים)
- **מקסימום פוזיציה:** 2 חוזים לכל מכשיר
- **חשבון תחרות:** CHMMMKV5060

---

## שלב 1: התחברות לשרת

### מ-Windows:
1. לחצי **Win + R**
2. הקלידי: `mstsc`
3. בשדה Computer הכניסי: **217.77.2.74**
4. הכניסי שם משתמש וסיסמה (מ-Contabo)
5. לחצי **Connect**

### אם יש בעיית אבטחה:
- לחצי **Yes** / **Connect Anyway** בחלון האזהרה

---

## שלב 2: הרצת סקריפט ההתקנה

### ברגע שנכנסת לשרת:
1. לחצי ימני על **Start** (כפתור Windows)
2. בחרי **Windows PowerShell (Admin)** או **Terminal (Admin)**
3. העתיקי והדביקי את הפקודה הבאה:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Download and run setup script
$url = "https://raw.githubusercontent.com/motitap-dotcom/MT5-PropFirm-Bot/claude/ninjatrader-trading-bot-PxnQr/NinjaTrader/scripts/setup-windows-vps.ps1"
$script = "$env:TEMP\setup-nt.ps1"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $script -UseBasicParsing
& $script
```

4. הסקריפט יעשה הכל אוטומטית:
   - יתקין Git
   - יוריד את הקוד מ-GitHub
   - יוריד NinjaTrader 8
   - יעתיק את האסטרטגיות

---

## שלב 3: התקנת NinjaTrader 8

אם הסקריפט פותח את ה-installer:
1. לחצי **Next**
2. קבלי את תנאי הרישיון
3. השאירי את נתיב ההתקנה ברירת מחדל
4. לחצי **Install**
5. חכי שיסיים
6. לחצי **Finish**

אם ה-installer לא נפתח אוטומטית:
1. פתחי דפדפן בשרת
2. גלשי ל: https://ninjatrader.com/GetNinjaTrader
3. הורידי והתקיני ידנית

---

## שלב 4: הגדרת NinjaTrader

### פתיחה ראשונה:
1. פתחי **NinjaTrader 8** (אייקון על שולחן העבודה)
2. בחרי **Free** או **Sim** license (לתחרות)
3. התחברי עם חשבון NinjaTrader שלך

### חיבור לתחרות:
1. **Connections** > **Configure...**
2. מצאי את חיבור התחרות (NinjaTrader Continuum / CQG)
3. הכניסי פרטי חשבון התחרות
4. לחצי **Connect**

---

## שלב 5: קומפילציית האסטרטגיות

1. ב-NinjaTrader: **New** > **NinjaScript Editor**
2. בצד שמאל תראי את **MarchMadnessBot** ו-**MadnessScalper**
3. לחצי **F5** (Compile)
4. ודאי הודעה ירוקה: **"Compile successful"**

אם יש שגיאות - שלחי צילום מסך!

---

## שלב 6: הפעלת MarchMadnessBot

### הכנת הצ'ארט:
1. **New** > **Chart**
2. Instrument: **ES 03-26** (E-Mini S&P 500)
3. Period: **5 Minute**
4. לחצי **OK**

### הוספת האסטרטגיה:
1. לחצי ימני על הצ'ארט > **Strategies**
2. מצאי **MarchMadnessBot** > לחצי **Add**
3. **חשוב!** בהגדרות:
   - Account: **CHMMMKV5060** (חשבון התחרות)
   - Max Contracts Per Instrument: **2**
   - שאר ההגדרות - ברירת מחדל
4. לחצי **OK**
5. **הפעילי:** כפתור ירוק למעלה (Enable)

### שמות מכשירים:
- ES: `ES 03-26`
- NQ: `NQ 03-26`
- CL: `CL 04-26`

---

## שלב 7 (אופציונלי): MadnessScalper

1. פתחי צ'ארט **נוסף**: NQ 03-26, 2 Minutes
2. הוסיפי **MadnessScalper**
3. Account: CHMMMKV5060
4. Contracts: **2**

---

## עדכון אסטרטגיות (כשיש שינויים)

פתחי PowerShell בשרת והריצי:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
& "C:\NinjaTrader-Bot\MT5-PropFirm-Bot\NinjaTrader\scripts\deploy-strategies.ps1"
```

אחרי זה קמפלי מחדש ב-NinjaScript Editor (F5).

---

## 2 הבוטים שלנו

### MarchMadnessBot (ראשי - מומנטום)
- סוחר **ES, NQ, CL** בו-זמנית מצ'ארט אחד
- EMA + RSI + MACD + ATR
- מזהה מגמות חזקות ופריצות (breakouts)
- Trailing stop דינמי
- 5 דקות + אישור 15 דקות

### MadnessScalper (סקאלפינג)
- סוחר מכשיר **אחד** בכל פעם
- כניסות/יציאות מהירות
- 2 דקות + אישור 5 דקות
- סטופ הדוק ויעד מהיר

---

## פרמטרים

### רגיל (ברירת מחדל):
- Max Contracts: 2
- ATR Stop: 1.8
- ATR Target: 3.5
- Min Momentum Score: 3
- Session Drawdown: $2,500

### אגרסיבי (ליום האחרון):
- Min Momentum Score: 2
- ATR Target: 5.0
- Session Drawdown: $5,000
- Cooldown: 5 דקות

---

## טיפים
1. **סמכי על הבוט** - אל תכבי באמצע
2. **כסף סימולציה** - אל תפחדי מהפסדים
3. **שעות פיק:** 8:30-11:30 + 13:00-15:30 (CT)
4. **ביום האחרון** - אפשר מצב אגרסיבי
5. **השאירי את השרת דלוק** - הבוט רץ 24/7!

---

## אם יש בעיה
1. בדקי **Log** ב-NinjaTrader (New > Log)
2. בדקי חשבון נכון נבחר
3. בדקי שמות מכשירים
4. שלחי צילום מסך ואני אעזור!
