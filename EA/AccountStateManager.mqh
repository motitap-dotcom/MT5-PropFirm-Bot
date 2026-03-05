//+------------------------------------------------------------------+
//|                                        AccountStateManager.mqh   |
//|                     ACCOUNT STATE & CHALLENGE PHASE MANAGER       |
//|                     Tracks Challenge -> Funded -> Scaling          |
//+------------------------------------------------------------------+
//|  The bot must know what phase it's in and adjust rules:           |
//|  CHALLENGE:  Aggressive target, strict DD, auto-stop at target   |
//|  FUNDED:     No profit target, protect capital, consistent PnL   |
//|  SCALING:    Higher balance, adjusted lot sizing                  |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "1.00"

enum ENUM_ACCOUNT_PHASE
{
   PHASE_CHALLENGE     = 0,   // Challenge phase - reach profit target
   PHASE_FUNDED        = 1,   // Funded account - protect & grow
   PHASE_SCALING       = 2    // Scaled up balance
};

//+------------------------------------------------------------------+
class CAccountStateManager
{
private:
   ENUM_ACCOUNT_PHASE m_phase;

   // Challenge rules
   double   m_challenge_account_size;
   double   m_challenge_profit_target;
   double   m_challenge_daily_dd;
   double   m_challenge_total_dd;
   int      m_challenge_min_days;
   bool     m_challenge_auto_stop;

   // Funded rules
   double   m_funded_account_size;
   double   m_funded_daily_dd;
   double   m_funded_total_dd;
   double   m_funded_profit_split;
   double   m_funded_min_withdrawal;
   bool     m_funded_has_target;
   double   m_funded_target;

   // Scaling rules
   double   m_scaling_account_size;
   double   m_scaling_daily_dd;
   double   m_scaling_total_dd;

   // Current state tracking
   int      m_trading_days;
   datetime m_last_trading_day;
   double   m_phase_start_balance;

   // Risk adjustment per phase
   double   m_risk_multiplier;       // 1.0 for challenge, 0.7 for funded
   int      m_max_positions;
   int      m_max_daily_trades;

   // File persistence
   string   m_state_file;
   void     SaveState();
   void     LoadState();

public:
            CAccountStateManager();
           ~CAccountStateManager() {}

   // Setup
   void     InitChallenge(double account_size, double profit_target,
                            double daily_dd, double total_dd, int min_days);
   void     InitFunded(double account_size, double daily_dd, double total_dd,
                         double profit_split = 80.0, bool has_target = false,
                         double target = 0);
   void     InitScaling(double account_size, double daily_dd, double total_dd);

   // Phase transitions
   void     SwitchToFunded(double funded_balance);
   void     SwitchToScaling(double scaled_balance);
   void     SwitchToChallenge();  // Reset back to challenge

   // Getters
   ENUM_ACCOUNT_PHASE GetPhase()         { return m_phase; }
   string   GetPhaseString();
   double   GetAccountSize();
   double   GetDailyDDLimit();
   double   GetTotalDDLimit();
   double   GetProfitTarget();
   bool     HasProfitTarget();
   double   GetRiskMultiplier()          { return m_risk_multiplier; }
   int      GetMaxPositions()            { return m_max_positions; }
   int      GetMaxDailyTrades()          { return m_max_daily_trades; }
   int      GetTradingDays()             { return m_trading_days; }
   int      GetMinTradingDays()          { return m_challenge_min_days; }
   bool     MinTradingDaysMet();

   // Trading day tracking
   void     OnNewTradingDay();
   void     RecordTradingActivity();

   // Status
   string   GetFullStatus();
   string   GetRulesForCurrentPhase();
};

//+------------------------------------------------------------------+
CAccountStateManager::CAccountStateManager()
{
   m_phase = PHASE_CHALLENGE;
   m_challenge_account_size  = 2000;
   m_challenge_profit_target = 10.0;
   m_challenge_daily_dd      = 5.0;
   m_challenge_total_dd      = 10.0;
   m_challenge_min_days      = 5;
   m_challenge_auto_stop     = true;

   m_funded_account_size     = 2000;
   m_funded_daily_dd         = 5.0;
   m_funded_total_dd         = 10.0;
   m_funded_profit_split     = 80.0;
   m_funded_min_withdrawal   = 50.0;
   m_funded_has_target       = false;
   m_funded_target           = 0;

   m_scaling_account_size    = 0;
   m_scaling_daily_dd        = 5.0;
   m_scaling_total_dd        = 10.0;

   m_trading_days            = 0;
   m_last_trading_day        = 0;
   m_phase_start_balance     = 0;
   m_risk_multiplier         = 1.0;
   m_max_positions           = 2;
   m_max_daily_trades        = 8;

   m_state_file = "PropFirmBot_AccountState.dat";
   LoadState();
}

//+------------------------------------------------------------------+
void CAccountStateManager::InitChallenge(double account_size, double profit_target,
                                           double daily_dd, double total_dd, int min_days)
{
   m_challenge_account_size  = account_size;
   m_challenge_profit_target = profit_target;
   m_challenge_daily_dd      = daily_dd;
   m_challenge_total_dd      = total_dd;
   m_challenge_min_days      = min_days;

   if(m_phase == PHASE_CHALLENGE)
   {
      m_risk_multiplier  = 1.0;
      m_max_positions    = 2;
      m_max_daily_trades = 8;
      m_phase_start_balance = account_size;
   }

   PrintFormat("[AccountState] Challenge configured: $%.0f | Target %.1f%% | DD %.1f%%/%.1f%% | MinDays %d",
               account_size, profit_target, daily_dd, total_dd, min_days);
}

//+------------------------------------------------------------------+
void CAccountStateManager::InitFunded(double account_size, double daily_dd, double total_dd,
                                        double profit_split, bool has_target, double target)
{
   m_funded_account_size   = account_size;
   m_funded_daily_dd       = daily_dd;
   m_funded_total_dd       = total_dd;
   m_funded_profit_split   = profit_split;
   m_funded_has_target     = has_target;
   m_funded_target         = target;

   PrintFormat("[AccountState] Funded rules: $%.0f | DD %.1f%%/%.1f%% | Split %.0f%%",
               account_size, daily_dd, total_dd, profit_split);
}

//+------------------------------------------------------------------+
void CAccountStateManager::InitScaling(double account_size, double daily_dd, double total_dd)
{
   m_scaling_account_size = account_size;
   m_scaling_daily_dd     = daily_dd;
   m_scaling_total_dd     = total_dd;
}

//+------------------------------------------------------------------+
void CAccountStateManager::SwitchToFunded(double funded_balance)
{
   m_phase = PHASE_FUNDED;
   m_funded_account_size  = funded_balance;
   m_phase_start_balance  = funded_balance;
   m_trading_days         = 0;

   // Funded mode: use full risk (Stellar Instant - no challenge, direct funded)
   m_risk_multiplier  = 1.0;    // Full risk - already conservative at 0.5%
   m_max_positions    = 3;
   m_max_daily_trades = 8;

   SaveState();

   PrintFormat("[AccountState] >>> SWITCHED TO FUNDED <<< Balance=$%.2f", funded_balance);
   PrintFormat("[AccountState] Risk reduced to %.0f%% | MaxPos=%d | MaxTrades=%d",
               m_risk_multiplier * 100, m_max_positions, m_max_daily_trades);
}

//+------------------------------------------------------------------+
void CAccountStateManager::SwitchToScaling(double scaled_balance)
{
   m_phase = PHASE_SCALING;
   m_scaling_account_size = scaled_balance;
   m_phase_start_balance  = scaled_balance;

   m_risk_multiplier  = 0.6;    // Even more conservative at scale
   m_max_positions    = 3;      // Can open more positions
   m_max_daily_trades = 6;

   SaveState();

   PrintFormat("[AccountState] >>> SWITCHED TO SCALING <<< Balance=$%.2f", scaled_balance);
}

//+------------------------------------------------------------------+
void CAccountStateManager::SwitchToChallenge()
{
   m_phase = PHASE_CHALLENGE;
   m_trading_days = 0;
   m_risk_multiplier  = 1.0;
   m_max_positions    = 2;
   m_max_daily_trades = 8;
   m_phase_start_balance = m_challenge_account_size;

   SaveState();
   PrintFormat("[AccountState] >>> RESET TO CHALLENGE MODE <<<");
}

//+------------------------------------------------------------------+
string CAccountStateManager::GetPhaseString()
{
   switch(m_phase)
   {
      case PHASE_CHALLENGE: return "CHALLENGE";
      case PHASE_FUNDED:    return "FUNDED";
      case PHASE_SCALING:   return "SCALING";
      default:              return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
double CAccountStateManager::GetAccountSize()
{
   switch(m_phase)
   {
      case PHASE_CHALLENGE: return m_challenge_account_size;
      case PHASE_FUNDED:    return m_funded_account_size;
      case PHASE_SCALING:   return m_scaling_account_size;
      default:              return m_challenge_account_size;
   }
}

//+------------------------------------------------------------------+
double CAccountStateManager::GetDailyDDLimit()
{
   switch(m_phase)
   {
      case PHASE_CHALLENGE: return m_challenge_daily_dd;
      case PHASE_FUNDED:    return m_funded_daily_dd;
      case PHASE_SCALING:   return m_scaling_daily_dd;
      default:              return 5.0;
   }
}

//+------------------------------------------------------------------+
double CAccountStateManager::GetTotalDDLimit()
{
   switch(m_phase)
   {
      case PHASE_CHALLENGE: return m_challenge_total_dd;
      case PHASE_FUNDED:    return m_funded_total_dd;
      case PHASE_SCALING:   return m_scaling_total_dd;
      default:              return 10.0;
   }
}

//+------------------------------------------------------------------+
double CAccountStateManager::GetProfitTarget()
{
   switch(m_phase)
   {
      case PHASE_CHALLENGE: return m_challenge_profit_target;
      case PHASE_FUNDED:    return m_funded_has_target ? m_funded_target : 0;
      case PHASE_SCALING:   return 0;
      default:              return 0;
   }
}

//+------------------------------------------------------------------+
bool CAccountStateManager::HasProfitTarget()
{
   switch(m_phase)
   {
      case PHASE_CHALLENGE: return true;
      case PHASE_FUNDED:    return m_funded_has_target;
      case PHASE_SCALING:   return false;
      default:              return false;
   }
}

//+------------------------------------------------------------------+
bool CAccountStateManager::MinTradingDaysMet()
{
   if(m_phase != PHASE_CHALLENGE) return true;
   return m_trading_days >= m_challenge_min_days;
}

//+------------------------------------------------------------------+
void CAccountStateManager::OnNewTradingDay()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today > m_last_trading_day)
   {
      m_last_trading_day = today;
      // Trading day only counts if we actually trade (tracked by RecordTradingActivity)
   }
}

//+------------------------------------------------------------------+
void CAccountStateManager::RecordTradingActivity()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today > m_last_trading_day)
   {
      m_trading_days++;
      m_last_trading_day = today;
      SaveState();
      PrintFormat("[AccountState] Trading day %d recorded (%d/%d required)",
                  m_trading_days,
                  m_trading_days,
                  m_phase == PHASE_CHALLENGE ? m_challenge_min_days : 0);
   }
}

//+------------------------------------------------------------------+
string CAccountStateManager::GetFullStatus()
{
   return StringFormat(
      "Phase: %s | Balance: $%.0f\n"
      "DD Limits: Daily %.1f%% / Total %.1f%%\n"
      "Target: %s\n"
      "Risk: %.0f%% | Positions: %d/%d | Trades/day: %d\n"
      "Trading days: %d%s",
      GetPhaseString(), GetAccountSize(),
      GetDailyDDLimit(), GetTotalDDLimit(),
      HasProfitTarget() ? StringFormat("%.1f%%", GetProfitTarget()) : "None (funded)",
      m_risk_multiplier * 100, 0, m_max_positions, m_max_daily_trades,
      m_trading_days,
      m_phase == PHASE_CHALLENGE
         ? StringFormat(" / %d min required", m_challenge_min_days) : "");
}

//+------------------------------------------------------------------+
string CAccountStateManager::GetRulesForCurrentPhase()
{
   switch(m_phase)
   {
      case PHASE_CHALLENGE:
         return StringFormat(
            "=== CHALLENGE MODE ===\n"
            "Account: $%.0f | Target: +%.1f%% ($%.0f)\n"
            "Max Daily DD: %.1f%% ($%.0f)\n"
            "Max Total DD: %.1f%% ($%.0f)\n"
            "Min Trading Days: %d\n"
            "Auto-stop at target: %s",
            m_challenge_account_size,
            m_challenge_profit_target,
            m_challenge_account_size * m_challenge_profit_target / 100,
            m_challenge_daily_dd,
            m_challenge_account_size * m_challenge_daily_dd / 100,
            m_challenge_total_dd,
            m_challenge_account_size * m_challenge_total_dd / 100,
            m_challenge_min_days,
            m_challenge_auto_stop ? "YES" : "NO");

      case PHASE_FUNDED:
         return StringFormat(
            "=== FUNDED ACCOUNT ===\n"
            "Account: $%.0f | Profit Split: %.0f%%\n"
            "Max Daily DD: %.1f%% ($%.0f)\n"
            "Max Total DD: %.1f%% ($%.0f)\n"
            "Target: %s\n"
            "Risk Level: CONSERVATIVE (%.0f%%)",
            m_funded_account_size, m_funded_profit_split,
            m_funded_daily_dd,
            m_funded_account_size * m_funded_daily_dd / 100,
            m_funded_total_dd,
            m_funded_account_size * m_funded_total_dd / 100,
            m_funded_has_target ? StringFormat("%.1f%%", m_funded_target) : "NO TARGET",
            m_risk_multiplier * 100);

      default:
         return "Unknown phase";
   }
}

//+------------------------------------------------------------------+
void CAccountStateManager::SaveState()
{
   int handle = FileOpen(m_state_file, FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(handle == INVALID_HANDLE) return;

   FileWriteInteger(handle, (int)m_phase);
   FileWriteInteger(handle, m_trading_days);
   FileWriteDouble(handle, m_phase_start_balance);
   FileWriteDouble(handle, m_risk_multiplier);
   FileWriteInteger(handle, m_max_positions);
   FileWriteInteger(handle, m_max_daily_trades);
   FileWriteDouble(handle, m_funded_account_size);
   FileWriteDouble(handle, m_funded_daily_dd);
   FileWriteDouble(handle, m_funded_total_dd);

   FileClose(handle);
}

//+------------------------------------------------------------------+
void CAccountStateManager::LoadState()
{
   if(!FileIsExist(m_state_file, FILE_COMMON)) return;

   int handle = FileOpen(m_state_file, FILE_READ|FILE_BIN|FILE_COMMON);
   if(handle == INVALID_HANDLE) return;

   m_phase              = (ENUM_ACCOUNT_PHASE)FileReadInteger(handle);
   m_trading_days       = FileReadInteger(handle);
   m_phase_start_balance= FileReadDouble(handle);
   m_risk_multiplier    = FileReadDouble(handle);
   m_max_positions      = FileReadInteger(handle);
   m_max_daily_trades   = FileReadInteger(handle);
   m_funded_account_size= FileReadDouble(handle);
   m_funded_daily_dd    = FileReadDouble(handle);
   m_funded_total_dd    = FileReadDouble(handle);

   FileClose(handle);

   PrintFormat("[AccountState] Loaded state: Phase=%s TradingDays=%d RiskMult=%.2f",
               GetPhaseString(), m_trading_days, m_risk_multiplier);
}
//+------------------------------------------------------------------+
