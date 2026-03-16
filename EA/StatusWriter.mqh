//+------------------------------------------------------------------+
//|                                               StatusWriter.mqh   |
//|                     Writes JSON status file for web dashboard     |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "1.00"

#include "Guardian.mqh"

//+------------------------------------------------------------------+
class CStatusWriter
{
private:
   string   m_folder;
   string   m_filename;
   int      m_update_interval;  // seconds
   datetime m_last_write;
   long     m_magic;

   string   EscapeJSON(string s);
   string   PositionToJSON(ulong ticket);

public:
            CStatusWriter();
           ~CStatusWriter();

   void     Init(long magic, string folder = "PropFirmBot");
   void     WriteStatus(CGuardian &guardian, int open_positions, double floating_pnl);
};

//+------------------------------------------------------------------+
CStatusWriter::CStatusWriter()
{
   m_folder = "PropFirmBot";
   m_filename = "status.json";
   m_update_interval = 10;  // Write every 10 seconds (was 3 - too frequent, causes lag)
   m_last_write = 0;
   m_magic = 0;
}

//+------------------------------------------------------------------+
CStatusWriter::~CStatusWriter() {}

//+------------------------------------------------------------------+
void CStatusWriter::Init(long magic, string folder)
{
   m_magic = magic;
   m_folder = folder;
   m_last_write = 0;

   // Create folder if needed
   FolderCreate(m_folder);
}

//+------------------------------------------------------------------+
string CStatusWriter::EscapeJSON(string s)
{
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\n", "\\n");
   StringReplace(s, "\r", "");
   StringReplace(s, "\t", "\\t");
   return s;
}

//+------------------------------------------------------------------+
string CStatusWriter::PositionToJSON(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return "";

   string symbol     = PositionGetString(POSITION_SYMBOL);
   long   type       = PositionGetInteger(POSITION_TYPE);
   double volume     = PositionGetDouble(POSITION_VOLUME);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl         = PositionGetDouble(POSITION_SL);
   double tp         = PositionGetDouble(POSITION_TP);
   double profit     = PositionGetDouble(POSITION_PROFIT)
                     + PositionGetDouble(POSITION_SWAP);
   double current    = PositionGetDouble(POSITION_PRICE_CURRENT);
   datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   string comment    = PositionGetString(POSITION_COMMENT);

   // Calculate pips
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double pip_size = (digits == 3 || digits == 5)
                     ? SymbolInfoDouble(symbol, SYMBOL_POINT) * 10
                     : SymbolInfoDouble(symbol, SYMBOL_POINT);
   double pips = 0;
   if(pip_size > 0)
   {
      if(type == POSITION_TYPE_BUY)
         pips = (current - open_price) / pip_size;
      else
         pips = (open_price - current) / pip_size;
   }

   return StringFormat(
      "{\"ticket\":%d,\"symbol\":\"%s\",\"type\":\"%s\","
      "\"volume\":%.2f,\"open_price\":%.5f,\"current_price\":%.5f,"
      "\"sl\":%.5f,\"tp\":%.5f,\"profit\":%.2f,\"pips\":%.1f,"
      "\"open_time\":\"%s\",\"comment\":\"%s\"}",
      ticket, symbol, type == POSITION_TYPE_BUY ? "BUY" : "SELL",
      volume, open_price, current, sl, tp, profit, pips,
      TimeToString(open_time, TIME_DATE|TIME_MINUTES),
      EscapeJSON(comment));
}

//+------------------------------------------------------------------+
void CStatusWriter::WriteStatus(CGuardian &guardian, int open_positions, double floating_pnl)
{
   // Throttle writes
   if(TimeCurrent() - m_last_write < m_update_interval) return;
   m_last_write = TimeCurrent();

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin  = AccountInfoDouble(ACCOUNT_MARGIN);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   long   leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   long   account  = AccountInfoInteger(ACCOUNT_LOGIN);
   string server   = AccountInfoString(ACCOUNT_SERVER);
   string name     = AccountInfoString(ACCOUNT_NAME);

   double daily_dd = guardian.DailyDD();
   double total_dd = guardian.TotalDD();
   double profit_pct = guardian.ProfitPct();
   double initial_bal = guardian.InitialBalance();

   // Guardian state
   string state_str;
   switch(guardian.GetState())
   {
      case GUARDIAN_ACTIVE:    state_str = "ACTIVE";    break;
      case GUARDIAN_CAUTION:   state_str = "CAUTION";   break;
      case GUARDIAN_HALTED:    state_str = "HALTED";    break;
      case GUARDIAN_EMERGENCY: state_str = "EMERGENCY"; break;
      case GUARDIAN_SHUTDOWN:  state_str = "SHUTDOWN";  break;
      default:                state_str = "UNKNOWN";    break;
   }

   // Build open positions JSON array
   string positions_json = "[";
   int pos_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

      string pos_json = PositionToJSON(ticket);
      if(pos_json == "") continue;

      if(pos_count > 0) positions_json += ",";
      positions_json += pos_json;
      pos_count++;
   }
   positions_json += "]";

   // Build full JSON
   string json = StringFormat(
      "{\n"
      "  \"timestamp\": \"%s\",\n"
      "  \"server_time\": \"%s\",\n"
      "  \"gmt_time\": \"%s\",\n"
      "  \"account\": {\n"
      "    \"number\": %d,\n"
      "    \"name\": \"%s\",\n"
      "    \"server\": \"%s\",\n"
      "    \"currency\": \"%s\",\n"
      "    \"leverage\": %d,\n"
      "    \"balance\": %.2f,\n"
      "    \"equity\": %.2f,\n"
      "    \"margin\": %.2f,\n"
      "    \"free_margin\": %.2f,\n"
      "    \"floating_pnl\": %.2f,\n"
      "    \"initial_balance\": %.2f,\n"
      "    \"total_pnl\": %.2f,\n"
      "    \"profit_percent\": %.2f\n"
      "  },\n"
      "  \"guardian\": {\n"
      "    \"state\": \"%s\",\n"
      "    \"daily_dd\": %.2f,\n"
      "    \"total_dd\": %.2f,\n"
      "    \"halt_message\": \"%s\",\n"
      "    \"connection_ok\": %s,\n"
      "    \"can_trade\": %s\n"
      "  },\n"
      "  \"today\": {\n"
      "    \"trades\": %d,\n"
      "    \"wins\": %d,\n"
      "    \"losses\": %d,\n"
      "    \"profit\": %.2f,\n"
      "    \"loss\": %.2f,\n"
      "    \"net\": %.2f,\n"
      "    \"consec_losses\": %d\n"
      "  },\n"
      "  \"positions\": {\n"
      "    \"count\": %d,\n"
      "    \"open\": %s\n"
      "  }\n"
      "}",
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      TimeToString(TimeGMT(), TIME_DATE|TIME_SECONDS),
      account, EscapeJSON(name), EscapeJSON(server), currency, leverage,
      balance, equity, margin, free_margin, floating_pnl,
      initial_bal, equity - initial_bal, profit_pct,
      state_str, daily_dd, total_dd,
      EscapeJSON(guardian.GetHaltMessage()),
      guardian.ConnectionOK() ? "true" : "false",
      guardian.CanTrade() ? "true" : "false",
      guardian.DailyTrades(),
      guardian.TodayWins(), guardian.TodayLosses(),
      guardian.TodayProfit(), guardian.TodayLoss(),
      guardian.TodayProfit() - guardian.TodayLoss(),
      guardian.ConsecLosses(),
      pos_count, positions_json);

   // Write to file (overwrite) - writes to MQL5/Files/PropFirmBot/status.json
   string filepath = m_folder + "\\" + m_filename;
   int handle = FileOpen(filepath, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle != INVALID_HANDLE)
   {
      FileWriteString(handle, json);
      FileClose(handle);
   }
   else
   {
      int err = GetLastError();
      PrintFormat("[StatusWriter] ERROR: Cannot write %s (error %d) - retrying with FolderCreate", filepath, err);
      // Retry: recreate folder and try again
      FolderCreate(m_folder);
      handle = FileOpen(filepath, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle != INVALID_HANDLE)
      {
         FileWriteString(handle, json);
         FileClose(handle);
         Print("[StatusWriter] Retry succeeded");
      }
      else
         PrintFormat("[StatusWriter] ERROR: Retry also failed (error %d)", GetLastError());
   }
}
//+------------------------------------------------------------------+
