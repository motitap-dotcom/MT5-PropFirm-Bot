//+------------------------------------------------------------------+
//|                                                  Guardian.mqh     |
//|                     MASTER WATCHDOG & EMERGENCY PROTECTION        |
//|                     Sits ABOVE all other modules                  |
//+------------------------------------------------------------------+
//|  Multiple independent safety layers. Any single one can halt.    |
//|  5 levels: ACTIVE -> CAUTION -> HALTED -> EMERGENCY -> SHUTDOWN  |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "2.00"

#include <Trade\Trade.mqh>

enum ENUM_GUARDIAN_STATE
{
   GUARDIAN_ACTIVE    = 0,   // All systems go
   GUARDIAN_CAUTION   = 1,   // Approaching limits - reduced risk
   GUARDIAN_HALTED    = 2,   // No new trades - manage existing only
   GUARDIAN_EMERGENCY = 3,   // Close everything NOW
   GUARDIAN_SHUTDOWN  = 4    // Permanent stop - challenge over
};

enum ENUM_HALT_REASON
{
   HALT_NONE               = 0,
   HALT_DAILY_DD_SOFT      = 1,
   HALT_DAILY_DD_CRITICAL  = 2,
   HALT_TOTAL_DD_SOFT      = 3,
   HALT_TOTAL_DD_CRITICAL  = 4,
   HALT_CONSEC_LOSSES      = 5,
   HALT_MAX_DAILY_TRADES   = 6,
   HALT_EQUITY_SPIKE       = 7,
   HALT_CONNECTION_LOST    = 8,
   HALT_TARGET_REACHED     = 9,
   HALT_WEEKEND            = 10,
   HALT_MANUAL             = 11
};

//+------------------------------------------------------------------+
class CGuardian
{
private:
   ENUM_GUARDIAN_STATE m_state;
   ENUM_HALT_REASON   m_halt_reason;
   string             m_halt_message;

   // Account snapshots
   double   m_initial_balance;
   double   m_daily_open_balance;
   double   m_last_equity;
   double   m_equity_high_water;
   datetime m_daily_reset_time;
   datetime m_ea_start_time;

   // Hard limits (prop firm rules - NEVER breach)
   double   m_hard_daily_dd_pct;    // 0 = disabled (Stellar Instant)
   double   m_hard_total_dd_pct;    // 6% for Stellar Instant
   double   m_profit_target_pct;    // 0 = no target (Stellar Instant)
   bool     m_trailing_dd;          // true = DD measured from equity high water mark

   // Soft limits (our safety buffers)
   double   m_soft_daily_dd_pct;
   double   m_crit_daily_dd_pct;
   double   m_soft_total_dd_pct;    // 3.5% for 6% trailing
   double   m_crit_total_dd_pct;    // 5.0% for 6% trailing

   // Circuit breakers
   int      m_max_consec_losses;
   int      m_consec_losses;
   int      m_max_daily_trades;
   int      m_daily_trade_count;
   double   m_max_equity_drop_pct;  // Flash crash guard

   // Connection monitor
   datetime m_last_tick_time;
   int      m_tick_gap_limit_sec;
   int      m_conn_failures;
   bool     m_conn_healthy;

   // Daily stats
   long     m_magic;
   int      m_today_wins;
   int      m_today_losses;
   double   m_today_profit;
   double   m_today_loss;

   // Alerts
   datetime m_last_alert_time;

   void     DoAlert(string msg, bool critical = false);
   void     Log(string msg);
   void     ForceCloseAll(string reason);
   double   CalcDailyDD();
   double   CalcTotalDD();

public:
            CGuardian();
           ~CGuardian() {}

   bool     Init(double balance, double hard_daily, double hard_total,
                  double target, long magic);

   // MAIN: call every tick
   ENUM_GUARDIAN_STATE RunChecks();

   // Events
   void     OnTradeOpened();
   void     OnTradeClosed(double pnl);
   void     OnNewDay();
   void     OnTickReceived();
   void     ManualHalt(string reason);
   void     ManualResume();

   // Queries
   ENUM_GUARDIAN_STATE GetState()      { return m_state; }
   ENUM_HALT_REASON GetHaltReason()    { return m_halt_reason; }
   string   GetHaltMessage()           { return m_halt_message; }
   bool     CanTrade()                 { return m_state == GUARDIAN_ACTIVE || m_state == GUARDIAN_CAUTION; }
   bool     MustCloseAll()             { return m_state >= GUARDIAN_EMERGENCY; }
   bool     IsDead()                   { return m_state == GUARDIAN_SHUTDOWN; }
   bool     IsCaution()                { return m_state == GUARDIAN_CAUTION; }

   // Spread anomaly check
   bool     CheckSpreadAnomaly(string symbol);

   // Metrics
   double   DailyDD()                  { return CalcDailyDD(); }
   double   TotalDD()                  { return CalcTotalDD(); }
   double   ProfitPct();
   int      DailyTrades()              { return m_daily_trade_count; }
   int      ConsecLosses()             { return m_consec_losses; }
   int      TodayWins()                { return m_today_wins; }
   int      TodayLosses()              { return m_today_losses; }
   double   TodayProfit()              { return m_today_profit; }
   double   TodayLoss()                { return m_today_loss; }
   double   InitialBalance()           { return m_initial_balance; }
   double   DailyOpenBalance()         { return m_daily_open_balance; }
   bool     ConnectionOK()             { return m_conn_healthy; }
   string   FullStatus();
};

//+------------------------------------------------------------------+
CGuardian::CGuardian()
{
   m_state = GUARDIAN_ACTIVE;
   m_halt_reason = HALT_NONE;
   m_halt_message = "";
   m_initial_balance = 0;
   m_daily_open_balance = 0;
   m_last_equity = 0;
   m_equity_high_water = 0;
   m_daily_reset_time = 0;
   m_ea_start_time = 0;
   m_hard_daily_dd_pct = 0;
   m_hard_total_dd_pct = 6.0;
   m_profit_target_pct = 0;
   m_trailing_dd = true;
   m_soft_daily_dd_pct = 0;
   m_crit_daily_dd_pct = 0;
   m_soft_total_dd_pct = 4.5;
   m_crit_total_dd_pct = 5.4;
   m_max_consec_losses = 5;
   m_consec_losses = 0;
   m_max_daily_trades = 10;
   m_daily_trade_count = 0;
   m_max_equity_drop_pct = 2.0;
   m_last_tick_time = 0;
   m_tick_gap_limit_sec = 120;
   m_conn_failures = 0;
   m_conn_healthy = true;
   m_magic = 0;
   m_today_wins = 0;
   m_today_losses = 0;
   m_today_profit = 0;
   m_today_loss = 0;
   m_last_alert_time = 0;
}

//+------------------------------------------------------------------+
bool CGuardian::Init(double balance, double hard_daily, double hard_total,
                      double target, long magic)
{
   m_initial_balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   if(m_initial_balance <= 0) m_initial_balance = balance;  // Fallback to configured size
   m_daily_open_balance = m_initial_balance;
   m_last_equity        = AccountInfoDouble(ACCOUNT_EQUITY);
   if(m_last_equity <= 0) m_last_equity = m_initial_balance;  // Fallback
   m_equity_high_water  = m_last_equity;
   m_ea_start_time      = TimeCurrent();
   m_daily_reset_time   = iTime(_Symbol, PERIOD_D1, 0);
   m_magic              = magic;

   m_hard_daily_dd_pct  = hard_daily;
   m_hard_total_dd_pct  = hard_total;
   m_profit_target_pct  = target;

   // Detect trailing DD mode (when daily DD is 0 or disabled)
   m_trailing_dd = (hard_daily <= 0);

   // Auto-calculate safety buffers
   if(hard_daily > 0)
   {
      m_soft_daily_dd_pct  = hard_daily - 2.0;
      m_crit_daily_dd_pct  = hard_daily - 1.0;
   }
   else
   {
      // No daily DD limit (Stellar Instant)
      m_soft_daily_dd_pct  = 0;
      m_crit_daily_dd_pct  = 0;
   }

   if(m_trailing_dd)
   {
      // Trailing DD: buffers from equity high water mark
      // Soft = 75% of hard limit (~4.5% for 6%) - reduces risk, still trades
      // Crit = 90% of hard limit (~5.4% for 6%) - emergency close
      m_soft_total_dd_pct  = hard_total * 0.75;  // ~4.5% for 6%
      m_crit_total_dd_pct  = hard_total * 0.90;  // ~5.4% for 6%
   }
   else
   {
      m_soft_total_dd_pct  = hard_total - 3.0;
      m_crit_total_dd_pct  = hard_total - 1.0;
   }

   m_state = GUARDIAN_ACTIVE;

   Log(StringFormat("INIT | Bal=$%.2f | %s DD: %.1f%% | Soft: %.1f%% | Crit: %.1f%% | Daily: %s | Target: %.1f%%",
       m_initial_balance,
       m_trailing_dd ? "TRAILING" : "FIXED",
       hard_total,
       m_soft_total_dd_pct, m_crit_total_dd_pct,
       hard_daily > 0 ? StringFormat("%.1f%%", hard_daily) : "NONE",
       target));

   return true;
}

//+------------------------------------------------------------------+
double CGuardian::CalcDailyDD()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0 || m_daily_open_balance <= 0) return 0;  // Safety: bad equity = no DD
   double dd = m_daily_open_balance - eq;
   return (dd > 0) ? (dd / m_daily_open_balance) * 100.0 : 0;
}

//+------------------------------------------------------------------+
double CGuardian::CalcTotalDD()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0) return 0;  // Safety: bad equity = no DD (prevents false SHUTDOWN)

   if(m_trailing_dd)
   {
      // TRAILING DD: measured from equity high water mark
      if(m_equity_high_water <= 0) return 0;
      double dd = m_equity_high_water - eq;
      return (dd > 0) ? (dd / m_equity_high_water) * 100.0 : 0;
   }
   else
   {
      // FIXED DD: measured from initial balance
      if(m_initial_balance <= 0) return 0;
      double dd = m_initial_balance - eq;
      return (dd > 0) ? (dd / m_initial_balance) * 100.0 : 0;
   }
}

//+------------------------------------------------------------------+
double CGuardian::ProfitPct()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(m_initial_balance <= 0) return 0;
   return ((eq - m_initial_balance) / m_initial_balance) * 100.0;
}

//+------------------------------------------------------------------+
//| MAIN CHECK - called every tick                                    |
//+------------------------------------------------------------------+
ENUM_GUARDIAN_STATE CGuardian::RunChecks()
{
   if(m_state == GUARDIAN_SHUTDOWN) return m_state;

   OnTickReceived();

   // Day rollover
   datetime day = iTime(_Symbol, PERIOD_D1, 0);
   if(day > m_daily_reset_time) OnNewDay();

   // Update equity tracking
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   // SAFETY: If equity returns 0 (Wine/MT5 glitch), skip all DD checks
   // to prevent false SHUTDOWN. Use last known equity instead.
   if(eq <= 0)
   {
      static datetime last_eq_warn = 0;
      if(TimeCurrent() - last_eq_warn > 60)
      {
         Log("WARNING: Equity returned 0 - skipping DD checks (Wine glitch)");
         last_eq_warn = TimeCurrent();
      }
      return m_state;  // Keep current state, don't make decisions with bad data
   }

   if(eq > m_equity_high_water) m_equity_high_water = eq;

   double daily_dd = CalcDailyDD();
   double total_dd = CalcTotalDD();

   // ===== LAYER 1: ABSOLUTE HARD LIMITS (emergency) =====
   // Daily DD check (skip if no daily DD limit, e.g. Stellar Instant)
   if(m_hard_daily_dd_pct > 0 && daily_dd >= m_hard_daily_dd_pct - 0.5)
   {
      m_state = GUARDIAN_SHUTDOWN;
      m_halt_reason = HALT_DAILY_DD_CRITICAL;
      m_halt_message = StringFormat("FATAL: Daily DD %.2f%% near hard limit %.1f%%!", daily_dd, m_hard_daily_dd_pct);
      DoAlert(m_halt_message, true);
      ForceCloseAll("Hard daily DD");
      return m_state;
   }

   if(total_dd >= m_hard_total_dd_pct - 1.0)
   {
      m_state = GUARDIAN_SHUTDOWN;
      m_halt_reason = HALT_TOTAL_DD_CRITICAL;
      m_halt_message = StringFormat("FATAL: %s DD %.2f%% near hard limit %.1f%%!",
                       m_trailing_dd ? "Trailing" : "Total", total_dd, m_hard_total_dd_pct);
      DoAlert(m_halt_message, true);
      ForceCloseAll(m_trailing_dd ? "Hard trailing DD" : "Hard total DD");
      return m_state;
   }

   // ===== LAYER 2: PROFIT TARGET (skip if no target, e.g. Stellar Instant) =====
   if(m_profit_target_pct > 0 && ProfitPct() >= m_profit_target_pct)
   {
      m_state = GUARDIAN_SHUTDOWN;
      m_halt_reason = HALT_TARGET_REACHED;
      m_halt_message = StringFormat("TARGET REACHED! +%.2f%%", ProfitPct());
      DoAlert(m_halt_message, true);
      return m_state;
   }

   // ===== LAYER 3: CRITICAL LIMITS (close all, halt) =====
   // Daily DD critical (skip if disabled)
   if(m_crit_daily_dd_pct > 0 && daily_dd >= m_crit_daily_dd_pct)
   {
      m_state = GUARDIAN_EMERGENCY;
      m_halt_reason = HALT_DAILY_DD_CRITICAL;
      m_halt_message = StringFormat("Daily DD %.2f%% >= critical %.1f%%", daily_dd, m_crit_daily_dd_pct);
      DoAlert(m_halt_message, true);
      ForceCloseAll("Critical daily DD");
      return m_state;
   }

   if(total_dd >= m_crit_total_dd_pct)
   {
      m_state = GUARDIAN_EMERGENCY;
      m_halt_reason = HALT_TOTAL_DD_CRITICAL;
      m_halt_message = StringFormat("%s DD %.2f%% >= critical %.1f%%",
                       m_trailing_dd ? "Trailing" : "Total", total_dd, m_crit_total_dd_pct);
      DoAlert(m_halt_message, true);
      ForceCloseAll("Critical trailing DD");
      return m_state;
   }

   // Flash crash: equity dropped >2% in one tick
   if(m_last_equity > 0)
   {
      double spike = ((m_last_equity - eq) / m_last_equity) * 100.0;
      if(spike >= m_max_equity_drop_pct)
      {
         m_state = GUARDIAN_EMERGENCY;
         m_halt_reason = HALT_EQUITY_SPIKE;
         m_halt_message = StringFormat("Flash crash! Equity dropped %.2f%% in one tick", spike);
         DoAlert(m_halt_message, true);
         ForceCloseAll("Equity spike");
         m_last_equity = eq;
         return m_state;
      }
   }
   m_last_equity = eq;

   // ===== LAYER 4: SOFT LIMITS (halt new trades) =====
   if(m_soft_daily_dd_pct > 0 && daily_dd >= m_soft_daily_dd_pct)
   {
      m_state = GUARDIAN_HALTED;
      m_halt_reason = HALT_DAILY_DD_SOFT;
      m_halt_message = StringFormat("Daily DD %.2f%% >= soft %.1f%%", daily_dd, m_soft_daily_dd_pct);
      DoAlert(m_halt_message);
      return m_state;
   }

   if(total_dd >= m_soft_total_dd_pct)
   {
      m_state = GUARDIAN_HALTED;
      m_halt_reason = HALT_TOTAL_DD_SOFT;
      m_halt_message = StringFormat("%s DD %.2f%% >= soft %.1f%%",
                       m_trailing_dd ? "Trailing" : "Total", total_dd, m_soft_total_dd_pct);
      DoAlert(m_halt_message);
      return m_state;
   }

   if(m_consec_losses >= m_max_consec_losses)
   {
      m_state = GUARDIAN_HALTED;
      m_halt_reason = HALT_CONSEC_LOSSES;
      m_halt_message = StringFormat("%d consecutive losses - circuit breaker", m_consec_losses);
      DoAlert(m_halt_message);
      return m_state;
   }

   if(m_daily_trade_count >= m_max_daily_trades)
   {
      m_state = GUARDIAN_HALTED;
      m_halt_reason = HALT_MAX_DAILY_TRADES;
      m_halt_message = StringFormat("%d/%d daily trades used", m_daily_trade_count, m_max_daily_trades);
      return m_state;
   }

   // Weekend
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   if((dt.day_of_week == 5 && dt.hour >= 20) || dt.day_of_week > 5)
   {
      m_state = GUARDIAN_HALTED;
      m_halt_reason = HALT_WEEKEND;
      m_halt_message = "Weekend guard";
      return m_state;
   }

   // ===== LAYER 5: CAUTION (reduce risk) =====
   if((m_soft_daily_dd_pct > 0 && daily_dd >= m_soft_daily_dd_pct * 0.6) || total_dd >= m_soft_total_dd_pct * 0.6)
   {
      m_state = GUARDIAN_CAUTION;
      m_halt_message = "Approaching DD limits - reduced risk";
      return m_state;
   }

   if(!m_conn_healthy)
   {
      m_state = GUARDIAN_CAUTION;
      m_halt_reason = HALT_CONNECTION_LOST;
      m_halt_message = "Connection unstable";
      return m_state;
   }

   // ===== ALL CLEAR =====
   m_state = GUARDIAN_ACTIVE;
   m_halt_reason = HALT_NONE;
   m_halt_message = "";
   return m_state;
}

//+------------------------------------------------------------------+
void CGuardian::OnTradeOpened()
{
   m_daily_trade_count++;
   Log(StringFormat("Trade #%d opened | DailyDD=%.2f%% TotalDD=%.2f%%",
       m_daily_trade_count, CalcDailyDD(), CalcTotalDD()));
}

//+------------------------------------------------------------------+
void CGuardian::OnTradeClosed(double pnl)
{
   if(pnl > 0)
   {
      m_today_wins++;
      m_today_profit += pnl;
      m_consec_losses = 0;
      Log(StringFormat("WIN +$%.2f | W%d/L%d", pnl, m_today_wins, m_today_losses));
   }
   else
   {
      m_today_losses++;
      m_today_loss += MathAbs(pnl);
      m_consec_losses++;
      Log(StringFormat("LOSS -$%.2f | W%d/L%d | ConsecL=%d/%d",
          MathAbs(pnl), m_today_wins, m_today_losses, m_consec_losses, m_max_consec_losses));

      if(m_consec_losses >= m_max_consec_losses)
         DoAlert(StringFormat("CIRCUIT BREAKER: %d consecutive losses!", m_consec_losses), true);
   }
}

//+------------------------------------------------------------------+
void CGuardian::OnNewDay()
{
   m_daily_open_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_daily_reset_time = iTime(_Symbol, PERIOD_D1, 0);
   m_daily_trade_count = 0;
   m_today_wins = 0;
   m_today_losses = 0;
   m_today_profit = 0;
   m_today_loss = 0;

   // Re-enable if was soft-halted (not emergency/shutdown)
   if(m_state == GUARDIAN_HALTED &&
      m_halt_reason != HALT_TARGET_REACHED &&
      m_halt_reason != HALT_MANUAL)
   {
      m_state = GUARDIAN_ACTIVE;
      m_halt_reason = HALT_NONE;
      m_halt_message = "";
   }

   Log(StringFormat("=== NEW DAY === Bal=$%.2f PnL=$%.2f (%.2f%%)",
       m_daily_open_balance, m_daily_open_balance - m_initial_balance, ProfitPct()));
}

//+------------------------------------------------------------------+
void CGuardian::OnTickReceived()
{
   datetime now = TimeCurrent();
   if(m_last_tick_time > 0)
   {
      int gap = (int)(now - m_last_tick_time);
      if(gap > m_tick_gap_limit_sec)
      {
         m_conn_failures++;
         m_conn_healthy = false;
      }
      else
      {
         m_conn_healthy = true;
         m_conn_failures = 0;
      }
   }
   m_last_tick_time = now;
}

//+------------------------------------------------------------------+
void CGuardian::ManualHalt(string reason)
{
   m_state = GUARDIAN_HALTED;
   m_halt_reason = HALT_MANUAL;
   m_halt_message = "MANUAL: " + reason;
   Log(m_halt_message);
   DoAlert(m_halt_message, true);
}

//+------------------------------------------------------------------+
void CGuardian::ManualResume()
{
   if(m_state == GUARDIAN_SHUTDOWN) { Log("Cannot resume SHUTDOWN"); return; }
   m_state = GUARDIAN_ACTIVE;
   m_halt_reason = HALT_NONE;
   m_halt_message = "";
   m_consec_losses = 0;
   Log("MANUAL RESUME");
}

//+------------------------------------------------------------------+
void CGuardian::ForceCloseAll(string reason)
{
   CTrade trade;
   trade.SetExpertMagicNumber(m_magic);
   int closed = 0;

   for(int attempt = 0; attempt < 3; attempt++)
   {
      bool any_left = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

         if(trade.PositionClose(ticket))
         {
            closed++;
            Log(StringFormat("FORCE CLOSED #%d (%s)", ticket, reason));
         }
         else
         {
            any_left = true;
            Log(StringFormat("FAILED close #%d - retry %d", ticket, attempt + 1));
         }
      }
      if(!any_left) break;
      Sleep(500);
   }
   Log(StringFormat("ForceClose done: %d positions closed", closed));
}

//+------------------------------------------------------------------+
void CGuardian::DoAlert(string msg, bool critical)
{
   if(!critical && TimeCurrent() - m_last_alert_time < 60) return;
   m_last_alert_time = TimeCurrent();

   string full = (critical ? "[CRITICAL] " : "[ALERT] ") + "PropFirmBot: " + msg;
   Print(full);

   if(critical) PlaySound("alert2.wav");
   else         PlaySound("alert.wav");

   if(TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
      SendNotification(full);
}

//+------------------------------------------------------------------+
void CGuardian::Log(string msg)
{
   PrintFormat("[GUARDIAN %s] %s",
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS), msg);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool CGuardian::CheckSpreadAnomaly(string symbol)
{
   // Check if current spread is abnormally high (3x normal)
   double spread_points = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   double pip_size = (digits == 3 || digits == 5) ? point * 10 : point;
   double spread_pips = spread_points * point / pip_size;

   // Normal max spread thresholds
   double normal_max;
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      normal_max = 5.0;  // Gold
   else
      normal_max = 3.0;  // Majors

   // Anomaly = 3x normal
   if(spread_pips > normal_max * 3.0)
   {
      Log(StringFormat("SPREAD ANOMALY %s: %.1f pips (normal max %.1f)", symbol, spread_pips, normal_max));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
string CGuardian::FullStatus()
{
   string st;
   switch(m_state)
   {
      case GUARDIAN_ACTIVE:    st="ACTIVE";    break;
      case GUARDIAN_CAUTION:   st="CAUTION";   break;
      case GUARDIAN_HALTED:    st="HALTED";    break;
      case GUARDIAN_EMERGENCY: st="EMERGENCY"; break;
      case GUARDIAN_SHUTDOWN:  st="SHUTDOWN";  break;
      default:                st="???";        break;
   }

   string dd_type = m_trailing_dd ? "Trailing" : "Total";
   string daily_str = m_hard_daily_dd_pct > 0
      ? StringFormat("Daily DD: %.2f%% [soft %.1f%% | crit %.1f%% | HARD %.1f%%]",
                     CalcDailyDD(), m_soft_daily_dd_pct, m_crit_daily_dd_pct, m_hard_daily_dd_pct)
      : "Daily DD: N/A (no limit)";
   string target_str = m_profit_target_pct > 0
      ? StringFormat("%.1f%%", m_profit_target_pct)
      : "NONE";

   return StringFormat(
      "%s | Bal $%.2f | Eq $%.2f | HWM $%.2f\n"
      "%s\n"
      "%s DD: %.2f%% [soft %.1f%% | crit %.1f%% | HARD %.1f%%]\n"
      "Profit: %.2f%% / %s target\n"
      "Today: %d trades | W%d L%d | +$%.2f -$%.2f\n"
      "ConsecL: %d/%d | Conn: %s%s",
      st, AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY), m_equity_high_water,
      daily_str,
      dd_type, CalcTotalDD(), m_soft_total_dd_pct, m_crit_total_dd_pct, m_hard_total_dd_pct,
      ProfitPct(), target_str,
      m_daily_trade_count, m_today_wins, m_today_losses, m_today_profit, m_today_loss,
      m_consec_losses, m_max_consec_losses,
      m_conn_healthy ? "OK" : "BAD",
      m_halt_message != "" ? "\n>> " + m_halt_message : "");
}
//+------------------------------------------------------------------+
