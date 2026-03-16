//+------------------------------------------------------------------+
//|                                             TradeJournal.mqh      |
//|                     COMPLETE TRADE LOG & AUDIT TRAIL              |
//|                     Every action logged to CSV + Experts log      |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "2.00"

//+------------------------------------------------------------------+
class CTradeJournal
{
private:
   string   m_filename;       // CSV log file
   long     m_magic;
   bool     m_file_ready;
   int      m_file_handle;

   // Running stats
   int      m_total_trades;
   int      m_total_wins;
   int      m_total_losses;
   double   m_total_profit;
   double   m_total_loss;
   double   m_largest_win;
   double   m_largest_loss;
   double   m_initial_balance;

   void     WriteCSVHeader();
   string   EscapeCSV(string val);

public:
            CTradeJournal();
           ~CTradeJournal();

   bool     Init(long magic, double initial_balance);
   void     Deinit();

   // Log trade events
   void     LogTradeOpen(string symbol, string direction, double lot,
                          double entry, double sl, double tp,
                          ulong ticket, string strategy, string reason);

   void     LogTradeClose(string symbol, string direction, double lot,
                           double entry, double exit_price, double sl, double tp,
                           double pnl, double pnl_pips, ulong ticket,
                           string exit_reason, double balance_after);

   void     LogEvent(string event_type, string message);

   // Stats
   int      TotalTrades()  { return m_total_trades; }
   int      TotalWins()    { return m_total_wins; }
   int      TotalLosses()  { return m_total_losses; }
   double   WinRate()      { return m_total_trades > 0 ? (double)m_total_wins / m_total_trades * 100.0 : 0; }
   double   TotalProfit()  { return m_total_profit; }
   double   TotalLoss()    { return m_total_loss; }
   double   NetPnL()       { return m_total_profit - m_total_loss; }
   double   ProfitFactor() { return m_total_loss > 0 ? m_total_profit / m_total_loss : 0; }
   double   LargestWin()   { return m_largest_win; }
   double   LargestLoss()  { return m_largest_loss; }

   string   GetSummary();
};

//+------------------------------------------------------------------+
CTradeJournal::CTradeJournal()
{
   m_file_ready = false;
   m_file_handle = INVALID_HANDLE;
   m_magic = 0;
   m_total_trades = 0;
   m_total_wins = 0;
   m_total_losses = 0;
   m_total_profit = 0;
   m_total_loss = 0;
   m_largest_win = 0;
   m_largest_loss = 0;
   m_initial_balance = 0;
}

//+------------------------------------------------------------------+
CTradeJournal::~CTradeJournal()
{
   Deinit();
}

//+------------------------------------------------------------------+
bool CTradeJournal::Init(long magic, double initial_balance)
{
   m_magic = magic;
   m_initial_balance = initial_balance;

   // Create filename with date
   MqlDateTime dt;
   TimeCurrent(dt);
   m_filename = StringFormat("PropFirmBot_Journal_%04d%02d%02d.csv",
                              dt.year, dt.mon, dt.day);

   // Check if file exists (append mode)
   m_file_handle = FileOpen(m_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(m_file_handle == INVALID_HANDLE)
   {
      PrintFormat("[Journal] ERROR: Cannot open %s: %d", m_filename, GetLastError());
      return false;
   }

   // If empty file, write header
   if(FileSize(m_file_handle) == 0)
      WriteCSVHeader();
   else
      FileSeek(m_file_handle, 0, SEEK_END);

   m_file_ready = true;

   PrintFormat("[Journal] Initialized: %s | Initial balance: $%.2f", m_filename, initial_balance);
   LogEvent("INIT", StringFormat("EA started. Balance=$%.2f Magic=%d", initial_balance, magic));

   return true;
}

//+------------------------------------------------------------------+
void CTradeJournal::Deinit()
{
   if(m_file_handle != INVALID_HANDLE)
   {
      LogEvent("SHUTDOWN", StringFormat("EA stopped. Net PnL=$%.2f WinRate=%.1f%%",
               NetPnL(), WinRate()));
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE;
   }
   m_file_ready = false;
}

//+------------------------------------------------------------------+
void CTradeJournal::WriteCSVHeader()
{
   if(m_file_handle == INVALID_HANDLE) return;
   FileWrite(m_file_handle,
      "DateTime", "Type", "Symbol", "Direction", "Lot",
      "EntryPrice", "ExitPrice", "SL", "TP",
      "PnL", "PnL_Pips", "Ticket",
      "Strategy", "Reason", "Balance", "Equity",
      "DailyDD%", "TotalDD%", "Message");
}

//+------------------------------------------------------------------+
void CTradeJournal::LogTradeOpen(string symbol, string direction, double lot,
                                   double entry, double sl, double tp,
                                   ulong ticket, string strategy, string reason)
{
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);

   // CSV
   if(m_file_ready)
   {
      FileWrite(m_file_handle,
         time_str, "OPEN", symbol, direction,
         DoubleToString(lot, 2),
         DoubleToString(entry, 5), "", DoubleToString(sl, 5), DoubleToString(tp, 5),
         "", "", IntegerToString(ticket),
         strategy, reason,
         DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
         DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
         "", "",
         StringFormat("%s %s %.2f lots @ %.5f SL=%.5f TP=%.5f", direction, symbol, lot, entry, sl, tp));
      FileFlush(m_file_handle);
   }

   // Console
   PrintFormat("[JOURNAL] OPEN %s %s | Lot=%.2f Entry=%.5f SL=%.5f TP=%.5f | #%d | %s",
               direction, symbol, lot, entry, sl, tp, ticket, strategy);
}

//+------------------------------------------------------------------+
void CTradeJournal::LogTradeClose(string symbol, string direction, double lot,
                                    double entry, double exit_price, double sl, double tp,
                                    double pnl, double pnl_pips, ulong ticket,
                                    string exit_reason, double balance_after)
{
   // Update stats
   m_total_trades++;
   if(pnl > 0)
   {
      m_total_wins++;
      m_total_profit += pnl;
      if(pnl > m_largest_win) m_largest_win = pnl;
   }
   else if(pnl < 0)
   {
      m_total_losses++;
      m_total_loss += MathAbs(pnl);
      if(MathAbs(pnl) > MathAbs(m_largest_loss)) m_largest_loss = pnl;
   }
   // pnl == 0 is breakeven, not counted as win or loss

   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // CSV
   if(m_file_ready)
   {
      FileWrite(m_file_handle,
         time_str, "CLOSE", symbol, direction,
         DoubleToString(lot, 2),
         DoubleToString(entry, 5), DoubleToString(exit_price, 5),
         DoubleToString(sl, 5), DoubleToString(tp, 5),
         DoubleToString(pnl, 2), DoubleToString(pnl_pips, 1),
         IntegerToString(ticket),
         "", exit_reason,
         DoubleToString(balance_after, 2),
         DoubleToString(equity, 2),
         "", "",
         StringFormat("%s %s PnL=$%.2f (%.1f pips) %s",
                      pnl > 0 ? "WIN" : "LOSS", symbol, pnl, pnl_pips, exit_reason));
      FileFlush(m_file_handle);
   }

   // Console
   PrintFormat("[JOURNAL] CLOSE #%d %s %s | PnL=$%.2f (%.1f pips) | %s | Bal=$%.2f | #%d W%d L%d WR=%.0f%%",
               ticket, direction, symbol, pnl, pnl_pips, exit_reason,
               balance_after, m_total_trades, m_total_wins, m_total_losses, WinRate());
}

//+------------------------------------------------------------------+
void CTradeJournal::LogEvent(string event_type, string message)
{
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);

   if(m_file_ready)
   {
      FileWrite(m_file_handle,
         time_str, event_type, "", "", "",
         "", "", "", "",
         "", "", "",
         "", "",
         DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
         DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
         "", "",
         message);
      FileFlush(m_file_handle);
   }

   PrintFormat("[JOURNAL] [%s] %s", event_type, message);
}

//+------------------------------------------------------------------+
string CTradeJournal::EscapeCSV(string val)
{
   StringReplace(val, "\"", "\"\"");
   if(StringFind(val, ",") >= 0 || StringFind(val, "\"") >= 0)
      return "\"" + val + "\"";
   return val;
}

//+------------------------------------------------------------------+
string CTradeJournal::GetSummary()
{
   return StringFormat(
      "Trades: %d | Wins: %d | Losses: %d | WR: %.1f%%\n"
      "Gross Profit: $%.2f | Gross Loss: $%.2f\n"
      "Net PnL: $%.2f | PF: %.2f\n"
      "Largest Win: $%.2f | Largest Loss: $%.2f",
      m_total_trades, m_total_wins, m_total_losses, WinRate(),
      m_total_profit, m_total_loss,
      NetPnL(), ProfitFactor(),
      m_largest_win, m_largest_loss);
}
//+------------------------------------------------------------------+
