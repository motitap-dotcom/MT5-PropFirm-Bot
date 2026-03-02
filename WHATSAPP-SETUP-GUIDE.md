# מעבר מטלגרם לוואטסאפ - מדריך מלא

## מה הולך לקרות
במקום שכל בוט ישלח הודעות לטלגרם, כולם ישלחו לוואטסאפ.
שירות אחד משותף על השרת מטפל בכל ההודעות.

---

## חלק 1: הרשמה ב-Meta (פעם אחת בלבד)

### שלב 1 - יצירת חשבון מפתחים
1. כנסי ל: https://developers.facebook.com
2. לחצי "Get Started" (או "התחל")
3. היכנסי עם חשבון הפייסבוק שלך
4. אשרי את תנאי השימוש

### שלב 2 - יצירת אפליקציה
1. לחצי "Create App" (צור אפליקציה)
2. בחרי "Other" (אחר)
3. בחרי סוג "Business"
4. תני שם (למשל: "MyBots")
5. לחצי "Create App"

### שלב 3 - הוספת WhatsApp
1. בעמוד האפליקציה, מצאי "WhatsApp" ולחצי "Set Up"
2. תגיעי לדף עם כל הפרטים שלך

### שלב 4 - שמירת הפרטים החשובים
בדף ה-WhatsApp תמצאי:
- **Phone Number ID** - מספר ארוך (כמו: 123456789012345)
- **WhatsApp Business Account ID** - מספר ארוך נוסף
- **Temporary Access Token** - טוקן ארוך (תקף 24 שעות!)

⚠️ **חשוב:** הטוקן הזמני תקף רק 24 שעות!
צריך ליצור טוקן קבוע (ראי שלב 5).

### שלב 5 - יצירת טוקן קבוע (Permanent Token)
1. בדף האפליקציה, לכי ל "System Users" (דרך Business Settings)
   - כנסי ל: https://business.facebook.com/settings/system-users
2. לחצי "Add" ותני שם (כמו "bot-sender")
3. בחרי תפקיד "Admin"
4. לחצי "Generate New Token"
5. בחרי את האפליקציה שיצרת
6. סמני את ההרשאה: `whatsapp_business_messaging`
7. לחצי "Generate Token"
8. **העתיקי ושמרי את הטוקן!** (הוא מופיע רק פעם אחת)

### שלב 6 - הוספת מספר הטלפון שלך כנמען
1. בדף ה-WhatsApp של האפליקציה
2. מצאי "To" ולחצי "Manage phone number list"
3. הוסיפי את המספר שלך (עם קידומת +972)
4. תקבלי קוד אימות בוואטסאפ - הכניסי אותו

---

## חלק 2: הגדרת השרת (פעם אחת בלבד)

### מה צריך להתקין על השרת
```bash
pip3 install flask requests gunicorn
```

### קובץ השירות: /root/whatsapp-service/app.py
שירות פשוט שכל הבוטים משתמשים בו לשלוח הודעות.

### קובץ הגדרות: /root/whatsapp-service/.env
```
WHATSAPP_TOKEN=הטוקן_הקבוע_שיצרת
WHATSAPP_PHONE_ID=ה_Phone_Number_ID_שלך
MY_PHONE_NUMBER=972XXXXXXXXX
```

### הרצה ברקע
```bash
cd /root/whatsapp-service
gunicorn -w 1 -b 127.0.0.1:5050 app:app --daemon
```

---

## חלק 3: איך כל בוט שולח הודעה

כל בוט צריך רק לשלוח HTTP request לשירות המקומי:

### מ-Python:
```python
import requests
requests.post("http://127.0.0.1:5050/send", json={"message": "הבוט פתח עסקה!"})
```

### מ-Bash/Shell:
```bash
curl -s -X POST http://127.0.0.1:5050/send -H "Content-Type: application/json" -d '{"message": "הבוט פתח עסקה!"}'
```

### מ-MQL5 (EA):
במקום לשלוח ל-Telegram API, שולחים ל-WhatsApp API דרך השירות המקומי.
(צריך לשנות את Notifications.mqh בכל EA)

---

## חלק 4: מה צריך לשנות בכל בוט

בכל בוט שעובד עם טלגרם, צריך להחליף:
- את ה-URL של ה-API (מ-telegram ל-localhost:5050)
- את פורמט ההודעה (פשוט text רגיל)
- להסיר את Telegram Token ו-Chat ID מההגדרות

---

## סיכום הפרטים שצריך לשמור

| פרט | ערך |
|------|------|
| WhatsApp Token (קבוע) | _למלא_ |
| Phone Number ID | _למלא_ |
| WhatsApp Business Account ID | _למלא_ |
| המספר שלי | +972XXXXXXXXX |
| כתובת השירות על השרת | http://127.0.0.1:5050 |

---

## פתרון בעיות נפוצות

### "הטוקן פג תוקף"
- אם השתמשת בטוקן הזמני - הוא תקף רק 24 שעות
- צרי טוקן קבוע (שלב 5 למעלה)

### "ההודעה לא מגיעה"
- וודאי שהמספר שלך מאומת (שלב 6)
- וודאי שהשירות רץ: `curl http://127.0.0.1:5050/health`

### "השירות לא עולה"
- בדקי לוגים: `cat /root/whatsapp-service/whatsapp.log`
- הפעילי מחדש: `cd /root/whatsapp-service && gunicorn -w 1 -b 127.0.0.1:5050 app:app --daemon`
