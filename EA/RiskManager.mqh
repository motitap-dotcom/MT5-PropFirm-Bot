//+------------------------------------------------------------------+
//|                                              RiskManager.mqh      |
//|                        PropFirm Challenge Bot - Risk Management   |
//|                        Daily DD, Total DD, Position Sizing, etc.  |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Risk Manager Class                                                |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   // Account parameters
   double            m_initial_balance;       // Starting balance
   double            m_account_size;          // Challenge account size

   // Risk parameters
   double            m_risk_per_trade;        // Risk % per trade (e.g. 0.75)
   double            m_max_risk_per_trade;    // Hard max risk % (e.g. 1.0)
   int               m_max_open_positions;    // Max simultaneous positions

   // Drawdown guards
   double            m_daily_dd_guard_pct;    // Daily DD guard % (3% = stop before 5% limit)
   double            m_total_dd_guard_pct;    // Total DD guard % (7% = stop before 10% limit)
   double            m_daily_start_balance;   // Balance at start of day
   datetime          m_daily_reset_time;      // When daily tracking resets

   // Spread filter
   double            m_max_spread_major;      // Max spread for major pairs (pips)
   double            m_max_spread_xau;        // Max spread for XAUUSD (pips)

   // Session filter
   int               m_london_start_hour;     // London open hour UTC
   int               m_london_end_hour;       // London close hour UTC
   int               m_ny_start_hour;         // NY open hour UTC
   int               m_ny_end_hour;           // NY close hour UTC

   // Weekend guard
   int               m_weekend_close_day;     // Day to close (5 = Friday)
   int               m_weekend_close_hour;    // Hour to close UTC

   // Trailing / Breakeven (in pips)
   double            m_trailing_activation;   // Activate trailing after X pips profit
   double            m_trailing_distance;     // Trail distance in pips
   double            m_breakeven_activation;  // Move to BE after X pips profit
   double            m_breakeven_offset;      // Offset above BE in pips

   // Challenge mode
   double            m_profit_target_pct;     // Target profit %
   bool              m_challenge_mode;        // Auto-stop at target
   bool              m_target_reached;        // Flag: target reached

   // Magic number
   long              m_magic_number;

   // Internals
   double            GetPipSize(string symbol);
   double            GetPipValue(string symbol, double lot_size);

public:
                     CRiskManager();
                    ~CRiskManager();

   // Initialization
   void              Init(double account_size,
                          double risk_pct = 0.75,
                          double max_risk_pct = 1.0,
                          int max_positions = 2,
                          double daily_dd_guard = 3.0,
                          double total_dd_guard = 7.0,
                          long magic = 123456);

   void              SetSpreadFilter(double major_pips, double xau_pips);
   void              SetSessionFilter(int london_start, int london_end, int ny_start, int ny_end);
   void              SetWeekendGuard(int close_day, int close_hour);
   void              SetTrailingStop(double activation_pips, double distance_pips);
   void              SetBreakeven(double activation_pips, double offset_pips);
   void              SetChallengeMode(double profit_target_pct);

   // Daily reset
   void              CheckDailyReset();

   // Permission checks - call before opening trades
   bool              CanOpenTrade(string symbol);
   bool              IsSessionActive();
   bool              IsSpreadAcceptable(string symbol);
   bool              IsDailyDrawdownOK();
   bool              IsTotalDrawdownOK();
   bool              IsMaxPositionsOK();
   bool              IsWeekendCloseTime();
   bool              IsProfitTargetReached();

   // Position sizing
   double            CalculateLotSize(string symbol, double sl_distance_points);

   // Trade management
   void              ManageTrailingStop(string symbol, ulong ticket, ENUM_POSITION_TYPE pos_type);
   void              ManageBreakeven(string symbol, ulong ticket, ENUM_POSITION_TYPE pos_type, double open_price);

   // Getters
   double            GetDailyPnL();
   double            GetTotalPnL();
   double            GetDailyDrawdownRemaining();
   double            GetTotalDrawdownRemaining();
   bool              GetTargetReached() { return m_target_reached; }
   long              GetMagicNumber() { return m_magic_number; }

   // Logging
   string            GetStatusReport();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
   m_initial_balance    = 0;
   m_account_size       = 2000;
   m_risk_per_trade     = 0.75;
   m_max_risk_per_trade = 1.0;
   m_max_open_positions = 2;
   m_daily_dd_guard_pct = 3.0;
   m_total_dd_guard_pct = 7.0;
   m_daily_start_balance= 0;
   m_daily_reset_time   = 0;
   m_max_spread_major   = 3.0;
   m_max_spread_xau     = 5.0;
   m_london_start_hour  = 7;
   m_london_end_hour    = 11;
   m_ny_start_hour      = 12;
   m_ny_end_hour        = 16;
   m_weekend_close_day  = 5;
   m_weekend_close_hour = 20;
   m_trailing_activation= 30;
   m_trailing_distance  = 20;
   m_breakeven_activation=20;
   m_breakeven_offset   = 2;
   m_profit_target_pct  = 10.0;
   m_challenge_mode     = true;
   m_target_reached     = false;
   m_magic_number       = 123456;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager() {}

//+------------------------------------------------------------------+
//| Initialize risk manager                                           |
//+------------------------------------------------------------------+
void CRiskManager::Init(double account_size,
                         double risk_pct,
                         double max_risk_pct,
                         int max_positions,
                         double daily_dd_guard,
                         double total_dd_guard,
                         long magic)
{
   m_account_size       = account_size;
   m_initial_balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   if(m_initial_balance <= 0) m_initial_balance = account_size;  // Fallback to configured size
   m_risk_per_trade     = risk_pct;
   m_max_risk_per_trade = max_risk_pct;
   m_max_open_positions = max_positions;
   m_daily_dd_guard_pct = daily_dd_guard;
   m_total_dd_guard_pct = total_dd_guard;
   m_magic_number       = magic;

   m_daily_start_balance = m_initial_balance;
   m_daily_reset_time    = iTime(_Symbol, PERIOD_D1, 0);

   PrintFormat("[RiskMgr] Init: Balance=%.2f | Risk=%.2f%% | MaxPos=%d | DailyDD=%.1f%% | TotalDD=%.1f%%",
               m_initial_balance, m_risk_per_trade, m_max_open_positions,
               m_daily_dd_guard_pct, m_total_dd_guard_pct);
}

//+------------------------------------------------------------------+
//| Configure spread filter                                           |
//+------------------------------------------------------------------+
void CRiskManager::SetSpreadFilter(double major_pips, double xau_pips)
{
   m_max_spread_major = major_pips;
   m_max_spread_xau   = xau_pips;
}

//+------------------------------------------------------------------+
//| Configure session filter                                          |
//+------------------------------------------------------------------+
void CRiskManager::SetSessionFilter(int london_start, int london_end, int ny_start, int ny_end)
{
   m_london_start_hour = london_start;
   m_london_end_hour   = london_end;
   m_ny_start_hour     = ny_start;
   m_ny_end_hour       = ny_end;
}

//+------------------------------------------------------------------+
//| Configure weekend guard                                           |
//+------------------------------------------------------------------+
void CRiskManager::SetWeekendGuard(int close_day, int close_hour)
{
   m_weekend_close_day  = close_day;
   m_weekend_close_hour = close_hour;
}

//+------------------------------------------------------------------+
//| Configure trailing stop                                           |
//+------------------------------------------------------------------+
void CRiskManager::SetTrailingStop(double activation_pips, double distance_pips)
{
   m_trailing_activation = activation_pips;
   m_trailing_distance   = distance_pips;
}

//+------------------------------------------------------------------+
//| Configure breakeven                                               |
//+------------------------------------------------------------------+
void CRiskManager::SetBreakeven(double activation_pips, double offset_pips)
{
   m_breakeven_activation = activation_pips;
   m_breakeven_offset     = offset_pips;
}

//+------------------------------------------------------------------+
//| Enable challenge mode with profit target                          |
//+------------------------------------------------------------------+
void CRiskManager::SetChallengeMode(double profit_target_pct)
{
   m_profit_target_pct = profit_target_pct;
   m_challenge_mode    = true;
   m_target_reached    = false;
}

//+------------------------------------------------------------------+
//| Get pip size for symbol                                           |
//+------------------------------------------------------------------+
double CRiskManager::GetPipSize(string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
   else
      return SymbolInfoDouble(symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Get pip value for 1 lot                                           |
//+------------------------------------------------------------------+
double CRiskManager::GetPipValue(string symbol, double lot_size)
{
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double pip_size   = GetPipSize(symbol);

   if(tick_size <= 0) return 0;

   return (pip_size / tick_size) * tick_value * lot_size;
}

//+------------------------------------------------------------------+
//| Check and reset daily tracking at new day                         |
//+------------------------------------------------------------------+
void CRiskManager::CheckDailyReset()
{
   datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day > m_daily_reset_time)
   {
      m_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_daily_reset_time    = current_day;
      PrintFormat("[RiskMgr] Daily reset: New day balance = %.2f", m_daily_start_balance);
   }
}

//+------------------------------------------------------------------+
//| Master check: can we open a new trade?                            |
//+------------------------------------------------------------------+
bool CRiskManager::CanOpenTrade(string symbol)
{
   CheckDailyReset();

   if(!IsSessionActive())
   {
      Print("[RiskMgr] BLOCKED: Outside trading session");
      return false;
   }

   if(!IsSpreadAcceptable(symbol))
   {
      PrintFormat("[RiskMgr] BLOCKED: Spread too wide on %s", symbol);
      return false;
   }

   if(!IsDailyDrawdownOK())
   {
      Print("[RiskMgr] BLOCKED: Daily drawdown guard triggered");
      return false;
   }

   if(!IsTotalDrawdownOK())
   {
      Print("[RiskMgr] BLOCKED: Total drawdown guard triggered");
      return false;
   }

   if(!IsMaxPositionsOK())
   {
      Print("[RiskMgr] BLOCKED: Maximum open positions reached");
      return false;
   }

   if(IsWeekendCloseTime())
   {
      Print("[RiskMgr] BLOCKED: Weekend close period");
      return false;
   }

   if(m_challenge_mode && IsProfitTargetReached())
   {
      Print("[RiskMgr] BLOCKED: Profit target reached (challenge mode)");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if current time is within active trading sessions           |
//+------------------------------------------------------------------+
bool CRiskManager::IsSessionActive()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   // London session
   if(dt.hour >= m_london_start_hour && dt.hour < m_london_end_hour)
      return true;

   // New York session
   if(dt.hour >= m_ny_start_hour && dt.hour < m_ny_end_hour)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable for the symbol                      |
//+------------------------------------------------------------------+
bool CRiskManager::IsSpreadAcceptable(string symbol)
{
   double spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   double pip_size = (digits == 3 || digits == 5) ? point * 10 : point;
   double spread_pips = spread_points * point / pip_size;

   // Determine max spread based on symbol
   double max_spread;
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      max_spread = m_max_spread_xau;
   else
      max_spread = m_max_spread_major;

   return spread_pips <= max_spread;
}

//+------------------------------------------------------------------+
//| Check daily drawdown guard                                        |
//+------------------------------------------------------------------+
bool CRiskManager::IsDailyDrawdownOK()
{
   // If daily DD guard is disabled (0 or negative), always allow
   // This is the case for FundedNext Stellar Instant (no daily DD limit)
   if(m_daily_dd_guard_pct <= 0) return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double daily_pnl = equity - m_daily_start_balance;
   double daily_dd_pct = 0;

   if(m_daily_start_balance > 0)
      daily_dd_pct = (-daily_pnl / m_daily_start_balance) * 100.0;

   return daily_dd_pct < m_daily_dd_guard_pct;
}

//+------------------------------------------------------------------+
//| Check total drawdown guard                                        |
//+------------------------------------------------------------------+
bool CRiskManager::IsTotalDrawdownOK()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double total_pnl = equity - m_initial_balance;
   double total_dd_pct = 0;

   if(m_initial_balance > 0)
      total_dd_pct = (-total_pnl / m_initial_balance) * 100.0;

   return total_dd_pct < m_total_dd_guard_pct;
}

//+------------------------------------------------------------------+
//| Check if max open positions reached (our EA's positions only)     |
//+------------------------------------------------------------------+
bool CRiskManager::IsMaxPositionsOK()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic_number)
         count++;
   }
   return count < m_max_open_positions;
}

//+------------------------------------------------------------------+
//| Check if it's weekend close time                                  |
//+------------------------------------------------------------------+
bool CRiskManager::IsWeekendCloseTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   if(dt.day_of_week > m_weekend_close_day) return true;
   if(dt.day_of_week == m_weekend_close_day && dt.hour >= m_weekend_close_hour) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check if profit target is reached                                 |
//+------------------------------------------------------------------+
bool CRiskManager::IsProfitTargetReached()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double pnl_pct = ((equity - m_initial_balance) / m_initial_balance) * 100.0;

   if(pnl_pct >= m_profit_target_pct)
   {
      m_target_reached = true;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//| Formula: Lot = (Balance * Risk%) / (SL_pips * PipValue)          |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(string symbol, double sl_distance_points)
{
   if(sl_distance_points <= 0) return 0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * (m_risk_per_trade / 100.0);

   // Cap risk amount
   double max_risk_amount = balance * (m_max_risk_per_trade / 100.0);
   if(risk_amount > max_risk_amount)
      risk_amount = max_risk_amount;

   // Get tick value and size
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tick_value <= 0 || tick_size <= 0) return 0;

   // Convert SL distance from points to monetary value per lot
   double sl_value_per_lot = (sl_distance_points / tick_size) * tick_value;

   if(sl_value_per_lot <= 0) return 0;

   double lot_size = risk_amount / sl_value_per_lot;

   // Apply symbol constraints
   double min_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   // Round to lot step
   if(lot_step > 0)
      lot_size = MathFloor(lot_size / lot_step) * lot_step;

   // Clamp
   if(lot_size < min_lot) lot_size = min_lot;
   if(lot_size > max_lot) lot_size = max_lot;

   // Safety: never exceed max total lots
   if(lot_size > 5.0) lot_size = 5.0;

   PrintFormat("[RiskMgr] LotCalc: Balance=%.2f Risk$=%.2f SL_pts=%.1f Lot=%.2f",
               balance, risk_amount, sl_distance_points, lot_size);

   return lot_size;
}

//+------------------------------------------------------------------+
//| Manage trailing stop for an open position                         |
//+------------------------------------------------------------------+
void CRiskManager::ManageTrailingStop(string symbol, ulong ticket, ENUM_POSITION_TYPE pos_type)
{
   if(!PositionSelectByTicket(ticket)) return;

   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double pip_size   = GetPipSize(symbol);
   double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double activation_distance = m_trailing_activation * pip_size;
   double trail_distance      = m_trailing_distance * pip_size;

   if(pos_type == POSITION_TYPE_BUY)
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double profit_distance = bid - open_price;

      if(profit_distance >= activation_distance)
      {
         double new_sl = bid - trail_distance;
         // Normalize to tick size
         double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tick_size > 0)
            new_sl = MathFloor(new_sl / tick_size) * tick_size;

         if(new_sl > current_sl + point)
         {
            CTrade trade;
            trade.SetExpertMagicNumber(m_magic_number);
            if(trade.PositionModify(ticket, new_sl, current_tp))
               PrintFormat("[RiskMgr] Trailing SL moved to %.5f for ticket %d", new_sl, ticket);
         }
      }
   }
   else if(pos_type == POSITION_TYPE_SELL)
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double profit_distance = open_price - ask;

      if(profit_distance >= activation_distance)
      {
         double new_sl = ask + trail_distance;
         double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tick_size > 0)
            new_sl = MathCeil(new_sl / tick_size) * tick_size;

         if(new_sl < current_sl - point || current_sl == 0)
         {
            CTrade trade;
            trade.SetExpertMagicNumber(m_magic_number);
            if(trade.PositionModify(ticket, new_sl, current_tp))
               PrintFormat("[RiskMgr] Trailing SL moved to %.5f for ticket %d", new_sl, ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Move stop loss to breakeven when in profit                        |
//+------------------------------------------------------------------+
void CRiskManager::ManageBreakeven(string symbol, ulong ticket, ENUM_POSITION_TYPE pos_type, double open_price)
{
   if(!PositionSelectByTicket(ticket)) return;

   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double pip_size   = GetPipSize(symbol);
   double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double activation_distance = m_breakeven_activation * pip_size;
   double be_offset           = m_breakeven_offset * pip_size;

   if(pos_type == POSITION_TYPE_BUY)
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

      // Only apply if not already at or above breakeven
      if(current_sl >= open_price) return;

      if(bid - open_price >= activation_distance)
      {
         double new_sl = open_price + be_offset;
         if(new_sl > current_sl)
         {
            CTrade trade;
            trade.SetExpertMagicNumber(m_magic_number);
            if(trade.PositionModify(ticket, new_sl, current_tp))
               PrintFormat("[RiskMgr] Breakeven set at %.5f for BUY ticket %d", new_sl, ticket);
         }
      }
   }
   else if(pos_type == POSITION_TYPE_SELL)
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      if(current_sl != 0 && current_sl <= open_price) return;

      if(open_price - ask >= activation_distance)
      {
         double new_sl = open_price - be_offset;
         if(new_sl < current_sl || current_sl == 0)
         {
            CTrade trade;
            trade.SetExpertMagicNumber(m_magic_number);
            if(trade.PositionModify(ticket, new_sl, current_tp))
               PrintFormat("[RiskMgr] Breakeven set at %.5f for SELL ticket %d", new_sl, ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get daily P&L                                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyPnL()
{
   return AccountInfoDouble(ACCOUNT_EQUITY) - m_daily_start_balance;
}

//+------------------------------------------------------------------+
//| Get total P&L since start                                         |
//+------------------------------------------------------------------+
double CRiskManager::GetTotalPnL()
{
   return AccountInfoDouble(ACCOUNT_EQUITY) - m_initial_balance;
}

//+------------------------------------------------------------------+
//| Get remaining daily drawdown allowance in $                       |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyDrawdownRemaining()
{
   double guard_amount = m_daily_start_balance * (m_daily_dd_guard_pct / 100.0);
   double current_loss = m_daily_start_balance - AccountInfoDouble(ACCOUNT_EQUITY);
   if(current_loss < 0) current_loss = 0;
   return guard_amount - current_loss;
}

//+------------------------------------------------------------------+
//| Get remaining total drawdown allowance in $                       |
//+------------------------------------------------------------------+
double CRiskManager::GetTotalDrawdownRemaining()
{
   double guard_amount = m_initial_balance * (m_total_dd_guard_pct / 100.0);
   double current_loss = m_initial_balance - AccountInfoDouble(ACCOUNT_EQUITY);
   if(current_loss < 0) current_loss = 0;
   return guard_amount - current_loss;
}

//+------------------------------------------------------------------+
//| Status report for logging                                         |
//+------------------------------------------------------------------+
string CRiskManager::GetStatusReport()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   string report = StringFormat(
      "[RiskMgr Status] Bal=%.2f Eq=%.2f | DailyPnL=%.2f (DD rem: $%.2f) | TotalPnL=%.2f (DD rem: $%.2f) | Target: %s",
      balance, equity,
      GetDailyPnL(), GetDailyDrawdownRemaining(),
      GetTotalPnL(), GetTotalDrawdownRemaining(),
      m_target_reached ? "REACHED" : "pending"
   );

   return report;
}
//+------------------------------------------------------------------+
