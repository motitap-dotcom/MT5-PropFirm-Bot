//+------------------------------------------------------------------+
//|                                             TradeAnalyzer.mqh    |
//|                     SELF-LEARNING TRADE ANALYSIS ENGINE           |
//|                     Monitors performance & auto-adjusts behavior  |
//+------------------------------------------------------------------+
//|  Tracks trading patterns and adjusts EA behavior in real-time:   |
//|  - Detects losing streaks per symbol/session/strategy            |
//|  - Adapts risk based on recent performance                       |
//|  - Identifies best/worst times to trade                          |
//|  - Logs everything for Python deep analysis                      |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "1.00"

#include "TradeJournal.mqh"

//--- Performance window sizes
#define PERF_WINDOW_SHORT   10    // Last 10 trades
#define PERF_WINDOW_MEDIUM  30    // Last 30 trades
#define PERF_WINDOW_LONG    100   // Last 100 trades

//+------------------------------------------------------------------+
struct TradeRecord
{
   datetime    time;
   string      symbol;
   string      direction;
   string      strategy;
   int         session;        // 0=London, 1=NY
   double      pnl;
   double      pnl_pips;
   double      lot;
   double      rr_actual;     // Actual R:R achieved
   int         duration_sec;  // Trade duration
   int         day_of_week;
   int         hour;
};

struct SymbolStats
{
   string symbol;
   int    trades;
   int    wins;
   int    losses;
   double total_pnl;
   double win_rate;
   double avg_win;
   double avg_loss;
   double profit_factor;
   bool   is_profitable;
};

struct SessionStats
{
   int    session;  // 0=London, 1=NY
   int    trades;
   int    wins;
   double total_pnl;
   double win_rate;
};

struct StrategyStats
{
   string strategy;  // "SMC" or "EMA"
   int    trades;
   int    wins;
   double total_pnl;
   double win_rate;
   double profit_factor;
};

//+------------------------------------------------------------------+
class CTradeAnalyzer
{
private:
   TradeRecord  m_history[];
   int          m_history_count;
   int          m_max_history;

   // Per-symbol performance
   SymbolStats  m_symbol_stats[];
   int          m_symbol_stat_count;

   // Per-session performance
   SessionStats m_session_stats[2];  // London, NY

   // Per-strategy performance
   StrategyStats m_strategy_stats[2]; // SMC, EMA

   // Adaptive parameters
   double       m_risk_adjustment;    // 0.5 to 1.5 multiplier
   bool         m_symbol_blocked[];   // Symbols temporarily blocked
   string       m_blocked_symbols[];
   int          m_blocked_count;

   // Analysis results
   string       m_analysis_log;       // Last analysis summary
   datetime     m_last_analysis_time;
   int          m_analysis_interval;  // Seconds between full analyses

   // Internal
   void         UpdateSymbolStats();
   void         UpdateSessionStats();
   void         UpdateStrategyStats();
   double       CalcWinRate(int wins, int total);
   double       CalcProfitFactor(double gross_win, double gross_loss);
   int          GetSessionFromHour(int hour);
   void         SaveAnalysisCSV();

public:
               CTradeAnalyzer();
              ~CTradeAnalyzer() {}

   void        Init(int max_history = 500);

   // Record trades
   void        RecordTrade(string symbol, string direction, string strategy,
                            double pnl, double pnl_pips, double lot,
                            double sl_distance, double tp_distance,
                            int duration_sec);

   // Run analysis
   void        Analyze();

   // Adaptive adjustments (EA reads these)
   double      GetRiskAdjustment()    { return m_risk_adjustment; }
   bool        IsSymbolBlocked(string symbol);
   bool        ShouldReduceRisk();
   double      GetSymbolRiskMultiplier(string symbol);
   bool        IsStrategyWorking(string strategy);

   // Reports
   string      GetShortReport();
   string      GetFullReport();
   string      GetRecommendations();

   // Per-symbol queries
   double      GetSymbolWinRate(string symbol);
   double      GetSymbolProfitFactor(string symbol);
   int         GetSymbolTradeCount(string symbol);
};

//+------------------------------------------------------------------+
CTradeAnalyzer::CTradeAnalyzer()
{
   m_history_count     = 0;
   m_max_history       = 500;
   m_symbol_stat_count = 0;
   m_blocked_count     = 0;
   m_risk_adjustment   = 1.0;
   m_analysis_log      = "";
   m_last_analysis_time = 0;
   m_analysis_interval  = 3600;  // Analyze every hour

   // Init session stats
   for(int i = 0; i < 2; i++)
   {
      m_session_stats[i].session = i;
      m_session_stats[i].trades = 0;
      m_session_stats[i].wins = 0;
      m_session_stats[i].total_pnl = 0;
      m_session_stats[i].win_rate = 0;
   }

   // Init strategy stats
   m_strategy_stats[0].strategy = "TREND";
   m_strategy_stats[1].strategy = "EMA";
   for(int i = 0; i < 2; i++)
   {
      m_strategy_stats[i].trades = 0;
      m_strategy_stats[i].wins = 0;
      m_strategy_stats[i].total_pnl = 0;
      m_strategy_stats[i].win_rate = 0;
      m_strategy_stats[i].profit_factor = 0;
   }
}

//+------------------------------------------------------------------+
void CTradeAnalyzer::Init(int max_history)
{
   m_max_history = max_history;
   ArrayResize(m_history, 0);
   ArrayResize(m_symbol_stats, 0);
   ArrayResize(m_symbol_blocked, 0);
   ArrayResize(m_blocked_symbols, 0);

   PrintFormat("[Analyzer] Initialized: MaxHistory=%d", max_history);
}

//+------------------------------------------------------------------+
void CTradeAnalyzer::RecordTrade(string symbol, string direction, string strategy,
                                   double pnl, double pnl_pips, double lot,
                                   double sl_distance, double tp_distance,
                                   int duration_sec)
{
   // Add to history
   if(m_history_count >= m_max_history)
   {
      // Remove oldest entry
      for(int i = 0; i < m_history_count - 1; i++)
         m_history[i] = m_history[i + 1];
      m_history_count--;
   }

   ArrayResize(m_history, m_history_count + 1);

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   m_history[m_history_count].time        = TimeCurrent();
   m_history[m_history_count].symbol      = symbol;
   m_history[m_history_count].direction   = direction;
   m_history[m_history_count].strategy    = strategy;
   m_history[m_history_count].pnl         = pnl;
   m_history[m_history_count].pnl_pips    = pnl_pips;
   m_history[m_history_count].lot         = lot;
   m_history[m_history_count].duration_sec = duration_sec;
   m_history[m_history_count].day_of_week = dt.day_of_week;
   m_history[m_history_count].hour        = dt.hour;
   m_history[m_history_count].session     = GetSessionFromHour(dt.hour);

   // Calculate actual R:R
   if(sl_distance > 0)
      m_history[m_history_count].rr_actual = MathAbs(pnl_pips) / (sl_distance > 0 ? sl_distance : 1);
   else
      m_history[m_history_count].rr_actual = 0;

   m_history_count++;

   // Run analysis after every trade
   Analyze();

   PrintFormat("[Analyzer] Trade recorded: %s %s PnL=$%.2f | History=%d",
               symbol, direction, pnl, m_history_count);
}

//+------------------------------------------------------------------+
int CTradeAnalyzer::GetSessionFromHour(int hour)
{
   if(hour >= 7 && hour < 14) return 0;   // London
   if(hour >= 14 && hour < 21) return 1;  // NY
   return -1;  // Off-session
}

//+------------------------------------------------------------------+
void CTradeAnalyzer::Analyze()
{
   if(m_history_count < 3) return; // Need minimum data

   UpdateSymbolStats();
   UpdateSessionStats();
   UpdateStrategyStats();

   // === ADAPTIVE RISK ADJUSTMENT ===
   // Based on recent short-term performance
   int recent_count = MathMin(m_history_count, PERF_WINDOW_SHORT);
   int recent_wins = 0;
   double recent_pnl = 0;

   for(int i = m_history_count - recent_count; i < m_history_count; i++)
   {
      if(m_history[i].pnl > 0) recent_wins++;
      recent_pnl += m_history[i].pnl;
   }

   double recent_wr = CalcWinRate(recent_wins, recent_count);

   // Adjust risk based on recent performance
   if(recent_count >= 5)
   {
      if(recent_wr < 30)
         m_risk_adjustment = 0.5;      // Bad streak: halve risk
      else if(recent_wr < 40)
         m_risk_adjustment = 0.75;     // Below average: reduce risk
      else if(recent_wr > 60 && recent_pnl > 0)
         m_risk_adjustment = 1.0;      // Good streak: normal risk
      else
         m_risk_adjustment = 0.85;     // Default: slightly conservative
   }

   // === SYMBOL BLOCKING ===
   // Block symbols that consistently lose
   m_blocked_count = 0;
   ArrayResize(m_blocked_symbols, m_symbol_stat_count);

   for(int i = 0; i < m_symbol_stat_count; i++)
   {
      if(m_symbol_stats[i].trades >= 5 &&
         m_symbol_stats[i].win_rate < 25 &&
         m_symbol_stats[i].total_pnl < 0)
      {
         m_blocked_symbols[m_blocked_count] = m_symbol_stats[i].symbol;
         m_blocked_count++;

         PrintFormat("[Analyzer] BLOCKED %s: WR=%.0f%% PnL=$%.2f (%d trades)",
                     m_symbol_stats[i].symbol,
                     m_symbol_stats[i].win_rate,
                     m_symbol_stats[i].total_pnl,
                     m_symbol_stats[i].trades);
      }
   }

   m_last_analysis_time = TimeCurrent();

   // Save analysis to CSV for Python to pick up
   SaveAnalysisCSV();
}

//+------------------------------------------------------------------+
void CTradeAnalyzer::UpdateSymbolStats()
{
   // Get unique symbols
   string symbols[];
   int sym_count = 0;

   for(int i = 0; i < m_history_count; i++)
   {
      bool found = false;
      for(int j = 0; j < sym_count; j++)
      {
         if(symbols[j] == m_history[i].symbol) { found = true; break; }
      }
      if(!found)
      {
         ArrayResize(symbols, sym_count + 1);
         symbols[sym_count] = m_history[i].symbol;
         sym_count++;
      }
   }

   m_symbol_stat_count = sym_count;
   ArrayResize(m_symbol_stats, sym_count);

   for(int s = 0; s < sym_count; s++)
   {
      m_symbol_stats[s].symbol = symbols[s];
      m_symbol_stats[s].trades = 0;
      m_symbol_stats[s].wins = 0;
      m_symbol_stats[s].losses = 0;
      m_symbol_stats[s].total_pnl = 0;
      double gross_win = 0, gross_loss = 0;
      double sum_win = 0, sum_loss = 0;

      for(int i = 0; i < m_history_count; i++)
      {
         if(m_history[i].symbol != symbols[s]) continue;

         m_symbol_stats[s].trades++;
         m_symbol_stats[s].total_pnl += m_history[i].pnl;

         if(m_history[i].pnl > 0)
         {
            m_symbol_stats[s].wins++;
            gross_win += m_history[i].pnl;
            sum_win += m_history[i].pnl;
         }
         else
         {
            m_symbol_stats[s].losses++;
            gross_loss += MathAbs(m_history[i].pnl);
            sum_loss += MathAbs(m_history[i].pnl);
         }
      }

      m_symbol_stats[s].win_rate = CalcWinRate(m_symbol_stats[s].wins, m_symbol_stats[s].trades);
      m_symbol_stats[s].avg_win  = m_symbol_stats[s].wins > 0 ? sum_win / m_symbol_stats[s].wins : 0;
      m_symbol_stats[s].avg_loss = m_symbol_stats[s].losses > 0 ? sum_loss / m_symbol_stats[s].losses : 0;
      m_symbol_stats[s].profit_factor = CalcProfitFactor(gross_win, gross_loss);
      m_symbol_stats[s].is_profitable = m_symbol_stats[s].total_pnl > 0;
   }
}

//+------------------------------------------------------------------+
void CTradeAnalyzer::UpdateSessionStats()
{
   for(int s = 0; s < 2; s++)
   {
      m_session_stats[s].trades = 0;
      m_session_stats[s].wins = 0;
      m_session_stats[s].total_pnl = 0;

      for(int i = 0; i < m_history_count; i++)
      {
         if(m_history[i].session != s) continue;

         m_session_stats[s].trades++;
         m_session_stats[s].total_pnl += m_history[i].pnl;
         if(m_history[i].pnl > 0) m_session_stats[s].wins++;
      }

      m_session_stats[s].win_rate = CalcWinRate(m_session_stats[s].wins, m_session_stats[s].trades);
   }
}

//+------------------------------------------------------------------+
void CTradeAnalyzer::UpdateStrategyStats()
{
   for(int s = 0; s < 2; s++)
   {
      m_strategy_stats[s].trades = 0;
      m_strategy_stats[s].wins = 0;
      m_strategy_stats[s].total_pnl = 0;
      double gross_win = 0, gross_loss = 0;

      string strat = (s == 0) ? "TREND" : "EMA";

      for(int i = 0; i < m_history_count; i++)
      {
         if(m_history[i].strategy != strat) continue;

         m_strategy_stats[s].trades++;
         m_strategy_stats[s].total_pnl += m_history[i].pnl;
         if(m_history[i].pnl > 0)
         {
            m_strategy_stats[s].wins++;
            gross_win += m_history[i].pnl;
         }
         else
         {
            gross_loss += MathAbs(m_history[i].pnl);
         }
      }

      m_strategy_stats[s].win_rate = CalcWinRate(m_strategy_stats[s].wins, m_strategy_stats[s].trades);
      m_strategy_stats[s].profit_factor = CalcProfitFactor(gross_win, gross_loss);
   }
}

//+------------------------------------------------------------------+
double CTradeAnalyzer::CalcWinRate(int wins, int total)
{
   if(total <= 0) return 0;
   return (double)wins / total * 100.0;
}

//+------------------------------------------------------------------+
double CTradeAnalyzer::CalcProfitFactor(double gross_win, double gross_loss)
{
   if(gross_loss <= 0) return gross_win > 0 ? 99.0 : 0;
   return gross_win / gross_loss;
}

//+------------------------------------------------------------------+
bool CTradeAnalyzer::IsSymbolBlocked(string symbol)
{
   for(int i = 0; i < m_blocked_count; i++)
   {
      if(m_blocked_symbols[i] == symbol) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool CTradeAnalyzer::ShouldReduceRisk()
{
   return m_risk_adjustment < 0.9;
}

//+------------------------------------------------------------------+
double CTradeAnalyzer::GetSymbolRiskMultiplier(string symbol)
{
   for(int i = 0; i < m_symbol_stat_count; i++)
   {
      if(m_symbol_stats[i].symbol != symbol) continue;

      // If few trades, return normal
      if(m_symbol_stats[i].trades < 5) return 1.0;

      // Great performance: allow full risk
      if(m_symbol_stats[i].win_rate > 55 && m_symbol_stats[i].profit_factor > 1.5)
         return 1.0;

      // OK performance
      if(m_symbol_stats[i].win_rate > 40)
         return 0.85;

      // Poor performance
      return 0.6;
   }

   return 1.0; // No data - normal risk
}

//+------------------------------------------------------------------+
bool CTradeAnalyzer::IsStrategyWorking(string strategy)
{
   int idx = (strategy == "TREND") ? 0 : 1;

   if(m_strategy_stats[idx].trades < 5) return true; // Not enough data

   return m_strategy_stats[idx].win_rate >= 35 &&
          m_strategy_stats[idx].profit_factor >= 0.8;
}

//+------------------------------------------------------------------+
double CTradeAnalyzer::GetSymbolWinRate(string symbol)
{
   for(int i = 0; i < m_symbol_stat_count; i++)
      if(m_symbol_stats[i].symbol == symbol)
         return m_symbol_stats[i].win_rate;
   return 0;
}

//+------------------------------------------------------------------+
double CTradeAnalyzer::GetSymbolProfitFactor(string symbol)
{
   for(int i = 0; i < m_symbol_stat_count; i++)
      if(m_symbol_stats[i].symbol == symbol)
         return m_symbol_stats[i].profit_factor;
   return 0;
}

//+------------------------------------------------------------------+
int CTradeAnalyzer::GetSymbolTradeCount(string symbol)
{
   for(int i = 0; i < m_symbol_stat_count; i++)
      if(m_symbol_stats[i].symbol == symbol)
         return m_symbol_stats[i].trades;
   return 0;
}

//+------------------------------------------------------------------+
string CTradeAnalyzer::GetShortReport()
{
   return StringFormat(
      "Trades: %d | Risk Adj: %.0f%%\n"
      "Blocked: %d symbols\n"
      "SMC: %d trades WR=%.0f%% PF=%.2f\n"
      "EMA: %d trades WR=%.0f%% PF=%.2f\n"
      "London: WR=%.0f%% | NY: WR=%.0f%%",
      m_history_count, m_risk_adjustment * 100,
      m_blocked_count,
      m_strategy_stats[0].trades, m_strategy_stats[0].win_rate, m_strategy_stats[0].profit_factor,
      m_strategy_stats[1].trades, m_strategy_stats[1].win_rate, m_strategy_stats[1].profit_factor,
      m_session_stats[0].win_rate, m_session_stats[1].win_rate);
}

//+------------------------------------------------------------------+
string CTradeAnalyzer::GetFullReport()
{
   string report = "=== TRADE ANALYZER REPORT ===\n\n";

   // Overall
   report += StringFormat("Total trades: %d | Risk adjustment: %.0f%%\n\n",
                           m_history_count, m_risk_adjustment * 100);

   // Per symbol
   report += "--- PER SYMBOL ---\n";
   for(int i = 0; i < m_symbol_stat_count; i++)
   {
      report += StringFormat("%s: %d trades | WR=%.0f%% | PF=%.2f | PnL=$%.2f %s\n",
         m_symbol_stats[i].symbol,
         m_symbol_stats[i].trades,
         m_symbol_stats[i].win_rate,
         m_symbol_stats[i].profit_factor,
         m_symbol_stats[i].total_pnl,
         IsSymbolBlocked(m_symbol_stats[i].symbol) ? "[BLOCKED]" : "");
   }

   // Per strategy
   report += "\n--- PER STRATEGY ---\n";
   for(int i = 0; i < 2; i++)
   {
      report += StringFormat("%s: %d trades | WR=%.0f%% | PF=%.2f | PnL=$%.2f %s\n",
         m_strategy_stats[i].strategy,
         m_strategy_stats[i].trades,
         m_strategy_stats[i].win_rate,
         m_strategy_stats[i].profit_factor,
         m_strategy_stats[i].total_pnl,
         IsStrategyWorking(m_strategy_stats[i].strategy) ? "" : "[UNDERPERFORMING]");
   }

   // Per session
   report += "\n--- PER SESSION ---\n";
   report += StringFormat("London: %d trades | WR=%.0f%% | PnL=$%.2f\n",
      m_session_stats[0].trades, m_session_stats[0].win_rate, m_session_stats[0].total_pnl);
   report += StringFormat("NY:     %d trades | WR=%.0f%% | PnL=$%.2f\n",
      m_session_stats[1].trades, m_session_stats[1].win_rate, m_session_stats[1].total_pnl);

   return report;
}

//+------------------------------------------------------------------+
string CTradeAnalyzer::GetRecommendations()
{
   string rec = "=== RECOMMENDATIONS ===\n";
   int count = 0;

   // Check each symbol
   for(int i = 0; i < m_symbol_stat_count; i++)
   {
      if(m_symbol_stats[i].trades >= 5 && m_symbol_stats[i].win_rate < 35)
      {
         rec += StringFormat("- Consider removing %s (WR=%.0f%%, PnL=$%.2f)\n",
            m_symbol_stats[i].symbol, m_symbol_stats[i].win_rate, m_symbol_stats[i].total_pnl);
         count++;
      }
   }

   // Check strategies
   for(int i = 0; i < 2; i++)
   {
      if(m_strategy_stats[i].trades >= 10 && m_strategy_stats[i].profit_factor < 0.8)
      {
         rec += StringFormat("- %s strategy underperforming (PF=%.2f). Review parameters.\n",
            m_strategy_stats[i].strategy, m_strategy_stats[i].profit_factor);
         count++;
      }
   }

   // Check sessions
   for(int i = 0; i < 2; i++)
   {
      if(m_session_stats[i].trades >= 5 && m_session_stats[i].win_rate < 30)
      {
         string sess = (i == 0) ? "London" : "NY";
         rec += StringFormat("- %s session poor (WR=%.0f%%). Consider disabling.\n",
            sess, m_session_stats[i].win_rate);
         count++;
      }
   }

   // Risk adjustment
   if(m_risk_adjustment < 0.8)
   {
      rec += StringFormat("- Risk reduced to %.0f%% due to poor recent performance\n",
         m_risk_adjustment * 100);
      count++;
   }

   if(count == 0)
      rec += "- No action needed. Performance is acceptable.\n";

   return rec;
}

//+------------------------------------------------------------------+
void CTradeAnalyzer::SaveAnalysisCSV()
{
   // Save analysis data to CSV for Python to pick up
   string filename = "PropFirmBot_Analysis.csv";
   int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(handle == INVALID_HANDLE) return;

   // Header
   FileWrite(handle, "Type", "Name", "Trades", "Wins", "Losses",
             "WinRate", "ProfitFactor", "TotalPnL", "AvgWin", "AvgLoss",
             "RiskAdj", "Blocked", "Timestamp");

   // Overall
   int total_wins = 0;
   double total_pnl = 0;
   for(int i = 0; i < m_history_count; i++)
   {
      if(m_history[i].pnl > 0) total_wins++;
      total_pnl += m_history[i].pnl;
   }
   FileWrite(handle, "OVERALL", "ALL",
      IntegerToString(m_history_count), IntegerToString(total_wins),
      IntegerToString(m_history_count - total_wins),
      DoubleToString(CalcWinRate(total_wins, m_history_count), 1),
      "", DoubleToString(total_pnl, 2),
      "", "", DoubleToString(m_risk_adjustment, 2), "",
      TimeToString(TimeCurrent()));

   // Per symbol
   for(int i = 0; i < m_symbol_stat_count; i++)
   {
      FileWrite(handle, "SYMBOL", m_symbol_stats[i].symbol,
         IntegerToString(m_symbol_stats[i].trades),
         IntegerToString(m_symbol_stats[i].wins),
         IntegerToString(m_symbol_stats[i].losses),
         DoubleToString(m_symbol_stats[i].win_rate, 1),
         DoubleToString(m_symbol_stats[i].profit_factor, 2),
         DoubleToString(m_symbol_stats[i].total_pnl, 2),
         DoubleToString(m_symbol_stats[i].avg_win, 2),
         DoubleToString(m_symbol_stats[i].avg_loss, 2),
         "", IsSymbolBlocked(m_symbol_stats[i].symbol) ? "Y" : "N",
         "");
   }

   // Per strategy
   for(int i = 0; i < 2; i++)
   {
      FileWrite(handle, "STRATEGY", m_strategy_stats[i].strategy,
         IntegerToString(m_strategy_stats[i].trades),
         IntegerToString(m_strategy_stats[i].wins),
         IntegerToString(m_strategy_stats[i].trades - m_strategy_stats[i].wins),
         DoubleToString(m_strategy_stats[i].win_rate, 1),
         DoubleToString(m_strategy_stats[i].profit_factor, 2),
         DoubleToString(m_strategy_stats[i].total_pnl, 2),
         "", "", "", "", "");
   }

   FileClose(handle);
}
//+------------------------------------------------------------------+
