//+------------------------------------------------------------------+
//|                                             Notifications.mqh    |
//|                     TELEGRAM & PUSH NOTIFICATION SYSTEM           |
//|                     Real-time alerts for all bot events           |
//+------------------------------------------------------------------+
//|  Sends alerts via:                                                |
//|  1) Telegram Bot API (WebRequest)                                |
//|  2) MT5 Push Notifications (mobile)                              |
//|  3) Email (via MT5 built-in)                                     |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "1.00"

enum ENUM_NOTIFY_LEVEL
{
   NOTIFY_INFO      = 0,   // Informational
   NOTIFY_WARNING   = 1,   // Warning
   NOTIFY_CRITICAL  = 2,   // Critical - immediate attention
   NOTIFY_TRADE     = 3    // Trade event
};

//+------------------------------------------------------------------+
class CNotifications
{
private:
   // Telegram settings
   bool     m_telegram_enabled;
   string   m_telegram_token;
   string   m_telegram_chat_id;
   string   m_telegram_base_url;

   // Push notification
   bool     m_push_enabled;

   // Email
   bool     m_email_enabled;

   // Throttle: don't spam
   datetime m_last_info_time;
   datetime m_last_warning_time;
   int      m_info_cooldown;      // Seconds between info messages
   int      m_warning_cooldown;   // Seconds between warning messages

   // Format helpers
   string   FormatTradeOpen(string symbol, string direction, double lot,
                             double entry, double sl, double tp, double rr);
   string   FormatTradeClose(string symbol, string direction, double pnl,
                              double pnl_pips, string reason);
   string   FormatDailyReport(double balance, double equity, double daily_pnl,
                               int wins, int losses, double daily_dd, double total_dd);

   bool     SendTelegram(string message);
   void     SendPush(string message);
   void     SendEmail(string subject, string body);

public:
            CNotifications();
           ~CNotifications() {}

   // Setup
   void     Init(string telegram_token = "", string telegram_chat_id = "");
   void     EnableTelegram(bool on)  { m_telegram_enabled = on; }
   void     EnablePush(bool on)      { m_push_enabled = on; }
   void     EnableEmail(bool on)     { m_email_enabled = on; }

   // Send notifications
   void     Send(string message, ENUM_NOTIFY_LEVEL level = NOTIFY_INFO);

   // Pre-formatted notifications
   void     NotifyTradeOpen(string symbol, string direction, double lot,
                             double entry, double sl, double tp, double rr);
   void     NotifyTradeClose(string symbol, string direction, double pnl,
                              double pnl_pips, string reason);
   void     NotifyStateChange(string old_state, string new_state, string reason);
   void     NotifyDailyReport(double balance, double equity, double daily_pnl,
                               int wins, int losses, double daily_dd, double total_dd);
   void     NotifyEmergency(string message);
   void     NotifyTargetReached(double profit_pct, double profit_amount);
   void     NotifyPhaseChange(string phase, string details);

   // Test
   bool     TestTelegram();
};

//+------------------------------------------------------------------+
CNotifications::CNotifications()
{
   m_telegram_enabled   = false;
   m_telegram_token     = "";
   m_telegram_chat_id   = "";
   m_telegram_base_url  = "https://api.telegram.org/bot";
   m_push_enabled       = false;
   m_email_enabled      = false;
   m_last_info_time     = 0;
   m_last_warning_time  = 0;
   m_info_cooldown      = 60;     // 1 min between info
   m_warning_cooldown   = 30;     // 30s between warnings
}

//+------------------------------------------------------------------+
void CNotifications::Init(string telegram_token, string telegram_chat_id)
{
   m_telegram_token   = telegram_token;
   m_telegram_chat_id = telegram_chat_id;

   if(m_telegram_token != "" && m_telegram_chat_id != "")
   {
      m_telegram_enabled = true;
      PrintFormat("[Notify] Telegram enabled: ChatID=%s", m_telegram_chat_id);
   }

   // Enable push if MT5 supports it
   if(TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
   {
      m_push_enabled = true;
      Print("[Notify] MT5 Push notifications enabled");
   }
}

//+------------------------------------------------------------------+
bool CNotifications::SendTelegram(string message)
{
   if(!m_telegram_enabled) return false;
   if(m_telegram_token == "" || m_telegram_chat_id == "") return false;

   string url = m_telegram_base_url + m_telegram_token + "/sendMessage";

   // URL encode the message
   StringReplace(message, "&", "%26");
   StringReplace(message, "#", "%23");

   string params = "chat_id=" + m_telegram_chat_id +
                   "&text=" + message +
                   "&parse_mode=HTML";

   char post_data[];
   char result[];
   string result_headers;

   StringToCharArray(params, post_data, 0, StringLen(params));

   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";

   int res = WebRequest("POST", url, headers, 5000, post_data, result, result_headers);

   if(res != 200)
   {
      PrintFormat("[Notify] Telegram failed: HTTP %d", res);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
void CNotifications::SendPush(string message)
{
   if(!m_push_enabled) return;

   // MT5 push limit: 255 chars
   if(StringLen(message) > 250)
      message = StringSubstr(message, 0, 247) + "...";

   SendNotification("PropFirmBot: " + message);
}

//+------------------------------------------------------------------+
void CNotifications::SendEmail(string subject, string body)
{
   if(!m_email_enabled) return;
   SendMail("PropFirmBot: " + subject, body);
}

//+------------------------------------------------------------------+
void CNotifications::Send(string message, ENUM_NOTIFY_LEVEL level)
{
   datetime now = TimeCurrent();

   // Throttle info messages
   if(level == NOTIFY_INFO && now - m_last_info_time < m_info_cooldown)
      return;
   if(level == NOTIFY_WARNING && now - m_last_warning_time < m_warning_cooldown)
      return;

   if(level == NOTIFY_INFO)    m_last_info_time = now;
   if(level == NOTIFY_WARNING) m_last_warning_time = now;

   // Add emoji prefix based on level
   string prefix = "";
   switch(level)
   {
      case NOTIFY_INFO:     prefix = "ℹ️ "; break;
      case NOTIFY_WARNING:  prefix = "⚠️ "; break;
      case NOTIFY_CRITICAL: prefix = "🚨 "; break;
      case NOTIFY_TRADE:    prefix = "📊 "; break;
   }

   string full_msg = prefix + message;

   // Send via all enabled channels
   SendTelegram(full_msg);

   // Push only for warnings and critical
   if(level >= NOTIFY_WARNING)
      SendPush(message);

   // Email only for critical
   if(level >= NOTIFY_CRITICAL)
      SendEmail("ALERT", message);
}

//+------------------------------------------------------------------+
string CNotifications::FormatTradeOpen(string symbol, string direction, double lot,
                                        double entry, double sl, double tp, double rr)
{
   return StringFormat(
      "<b>%s %s</b>\n"
      "Lot: %.2f | Entry: %.5f\n"
      "SL: %.5f | TP: %.5f\n"
      "R:R = 1:%.1f",
      direction, symbol, lot, entry, sl, tp, rr);
}

//+------------------------------------------------------------------+
string CNotifications::FormatTradeClose(string symbol, string direction, double pnl,
                                         double pnl_pips, string reason)
{
   string emoji = pnl >= 0 ? "✅" : "❌";
   return StringFormat(
      "%s <b>CLOSED %s %s</b>\n"
      "PnL: $%.2f (%.1f pips)\n"
      "Reason: %s",
      emoji, direction, symbol, pnl, pnl_pips, reason);
}

//+------------------------------------------------------------------+
string CNotifications::FormatDailyReport(double balance, double equity, double daily_pnl,
                                          int wins, int losses, double daily_dd, double total_dd)
{
   string pnl_emoji = daily_pnl >= 0 ? "📈" : "📉";
   double wr = (wins + losses) > 0 ? (double)wins / (wins + losses) * 100 : 0;

   return StringFormat(
      "%s <b>Daily Report</b>\n"
      "━━━━━━━━━━━━━━━\n"
      "Balance: $%.2f\n"
      "Equity: $%.2f\n"
      "Daily PnL: $%+.2f\n"
      "Trades: W%d L%d (%.0f%%)\n"
      "Daily DD: %.2f%% / 5%%\n"
      "Total DD: %.2f%% / 10%%",
      pnl_emoji, balance, equity, daily_pnl,
      wins, losses, wr,
      daily_dd, total_dd);
}

//+------------------------------------------------------------------+
void CNotifications::NotifyTradeOpen(string symbol, string direction, double lot,
                                      double entry, double sl, double tp, double rr)
{
   string msg = FormatTradeOpen(symbol, direction, lot, entry, sl, tp, rr);
   Send(msg, NOTIFY_TRADE);
}

//+------------------------------------------------------------------+
void CNotifications::NotifyTradeClose(string symbol, string direction, double pnl,
                                       double pnl_pips, string reason)
{
   string msg = FormatTradeClose(symbol, direction, pnl, pnl_pips, reason);
   ENUM_NOTIFY_LEVEL lvl = (pnl < -10) ? NOTIFY_WARNING : NOTIFY_TRADE;
   Send(msg, lvl);
}

//+------------------------------------------------------------------+
void CNotifications::NotifyStateChange(string old_state, string new_state, string reason)
{
   string msg = StringFormat(
      "🔄 <b>State Change</b>\n"
      "%s → %s\n"
      "Reason: %s",
      old_state, new_state, reason);

   ENUM_NOTIFY_LEVEL lvl = NOTIFY_WARNING;
   if(new_state == "EMERGENCY" || new_state == "SHUTDOWN")
      lvl = NOTIFY_CRITICAL;

   Send(msg, lvl);
}

//+------------------------------------------------------------------+
void CNotifications::NotifyDailyReport(double balance, double equity, double daily_pnl,
                                        int wins, int losses, double daily_dd, double total_dd)
{
   string msg = FormatDailyReport(balance, equity, daily_pnl, wins, losses, daily_dd, total_dd);
   Send(msg, NOTIFY_INFO);
}

//+------------------------------------------------------------------+
void CNotifications::NotifyEmergency(string message)
{
   string msg = StringFormat("🚨🚨🚨 <b>EMERGENCY</b> 🚨🚨🚨\n%s", message);
   Send(msg, NOTIFY_CRITICAL);
}

//+------------------------------------------------------------------+
void CNotifications::NotifyTargetReached(double profit_pct, double profit_amount)
{
   string msg = StringFormat(
      "🎯🎉 <b>TARGET REACHED!</b> 🎉🎯\n"
      "Profit: +%.2f%% ($%.2f)\n"
      "All trading stopped.\n"
      "CONGRATULATIONS!",
      profit_pct, profit_amount);

   Send(msg, NOTIFY_CRITICAL);
}

//+------------------------------------------------------------------+
void CNotifications::NotifyPhaseChange(string phase, string details)
{
   string msg = StringFormat(
      "🔀 <b>Phase Change: %s</b>\n%s",
      phase, details);

   Send(msg, NOTIFY_CRITICAL);
}

//+------------------------------------------------------------------+
bool CNotifications::TestTelegram()
{
   string msg = "🤖 PropFirmBot connected!\n"
                "Telegram notifications are working.";
   return SendTelegram(msg);
}
//+------------------------------------------------------------------+
