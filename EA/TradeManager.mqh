//+------------------------------------------------------------------+
//|                                             TradeManager.mqh      |
//|                        PropFirm Challenge Bot - Trade Execution   |
//|                        Order placement, position tracking, close  |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Trade Manager Class                                               |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   CTrade            m_trade;
   CPositionInfo     m_position;

   long              m_magic_number;
   int               m_slippage;          // Max slippage in points
   int               m_max_retries;       // Order send retries
   string            m_comment_prefix;    // Trade comment prefix

   // Trade tracking (per-symbol cooldown)
   datetime          m_last_trade_time[];    // Per-symbol last trade time
   string            m_tracked_symbols[];    // Symbols being tracked
   int               m_tracked_count;        // Number of tracked symbols
   int               m_min_bar_gap;          // Min bars between trades on same symbol

   // Normalize price to symbol tick size
   double            NormalizePrice(string symbol, double price);
   void              RecordTradeTime(string symbol);

public:
                     CTradeManager();
                    ~CTradeManager();

   void              Init(long magic, int slippage = 30, string comment = "PFBot");

   // Order execution
   ulong             OpenBuy(string symbol, double lot, double sl, double tp, string comment = "");
   ulong             OpenSell(string symbol, double lot, double sl, double tp, string comment = "");

   // Position management
   bool              ClosePosition(ulong ticket);
   bool              CloseAllPositions();
   bool              CloseSymbolPositions(string symbol);
   bool              ModifyPosition(ulong ticket, double new_sl, double new_tp);

   // Position queries
   int               CountOpenPositions();
   int               CountSymbolPositions(string symbol);
   double            GetTotalProfit();
   double            GetSymbolProfit(string symbol);
   bool              HasOpenPosition(string symbol, ENUM_POSITION_TYPE type);

   // Safety
   bool              CanTradeNow(string symbol);
   void              SetMinBarGap(int bars) { m_min_bar_gap = bars; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
   m_magic_number   = 123456;
   m_slippage       = 30;
   m_max_retries    = 3;
   m_comment_prefix = "PFBot";
   m_tracked_count  = 0;
   m_min_bar_gap    = 1;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager() {}

//+------------------------------------------------------------------+
//| Initialize trade manager                                          |
//+------------------------------------------------------------------+
void CTradeManager::Init(long magic, int slippage, string comment)
{
   m_magic_number   = magic;
   m_slippage       = slippage;
   m_comment_prefix = comment;

   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints(slippage);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   m_trade.SetTypeFillingBySymbol(_Symbol);

   PrintFormat("[TradeMgr] Initialized: Magic=%d Slippage=%d", magic, slippage);
}

//+------------------------------------------------------------------+
//| Normalize price to tick size                                      |
//+------------------------------------------------------------------+
double CTradeManager::NormalizePrice(string symbol, double price)
{
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0) return price;
   return MathRound(price / tick_size) * tick_size;
}

//+------------------------------------------------------------------+
//| Open a BUY position                                               |
//+------------------------------------------------------------------+
ulong CTradeManager::OpenBuy(string symbol, double lot, double sl, double tp, string comment)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(ask <= 0)
   {
      PrintFormat("[TradeMgr] ERROR: Invalid ASK price for %s", symbol);
      return 0;
   }

   sl = NormalizePrice(symbol, sl);
   tp = NormalizePrice(symbol, tp);

   // Validate SL is below entry
   if(sl >= ask)
   {
      PrintFormat("[TradeMgr] ERROR: BUY SL (%.5f) must be below ASK (%.5f)", sl, ask);
      return 0;
   }

   // Validate TP is above entry
   if(tp <= ask)
   {
      PrintFormat("[TradeMgr] ERROR: BUY TP (%.5f) must be above ASK (%.5f)", tp, ask);
      return 0;
   }

   string full_comment = m_comment_prefix;
   if(comment != "") full_comment += "_" + comment;

   for(int retry = 0; retry < m_max_retries; retry++)
   {
      if(m_trade.Buy(lot, symbol, ask, sl, tp, full_comment))
      {
         ulong ticket = m_trade.ResultOrder();
         RecordTradeTime(symbol);

         PrintFormat("[TradeMgr] BUY opened: %s Lot=%.2f Entry=%.5f SL=%.5f TP=%.5f Ticket=%d",
                     symbol, lot, ask, sl, tp, ticket);
         return ticket;
      }
      else
      {
         uint error = m_trade.ResultRetcode();
         PrintFormat("[TradeMgr] BUY failed (attempt %d): %s Error=%d %s",
                     retry + 1, symbol, error, m_trade.ResultRetcodeDescription());

         // Don't retry on fatal errors
         if(error == TRADE_RETCODE_INVALID_STOPS ||
            error == TRADE_RETCODE_INVALID_VOLUME ||
            error == TRADE_RETCODE_MARKET_CLOSED ||
            error == TRADE_RETCODE_NO_MONEY)
            break;

         Sleep(500);
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Open a SELL position                                              |
//+------------------------------------------------------------------+
ulong CTradeManager::OpenSell(string symbol, double lot, double sl, double tp, string comment)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0)
   {
      PrintFormat("[TradeMgr] ERROR: Invalid BID price for %s", symbol);
      return 0;
   }

   sl = NormalizePrice(symbol, sl);
   tp = NormalizePrice(symbol, tp);

   // Validate SL is above entry
   if(sl <= bid)
   {
      PrintFormat("[TradeMgr] ERROR: SELL SL (%.5f) must be above BID (%.5f)", sl, bid);
      return 0;
   }

   // Validate TP is below entry
   if(tp >= bid)
   {
      PrintFormat("[TradeMgr] ERROR: SELL TP (%.5f) must be below BID (%.5f)", tp, bid);
      return 0;
   }

   string full_comment = m_comment_prefix;
   if(comment != "") full_comment += "_" + comment;

   for(int retry = 0; retry < m_max_retries; retry++)
   {
      if(m_trade.Sell(lot, symbol, bid, sl, tp, full_comment))
      {
         ulong ticket = m_trade.ResultOrder();
         RecordTradeTime(symbol);

         PrintFormat("[TradeMgr] SELL opened: %s Lot=%.2f Entry=%.5f SL=%.5f TP=%.5f Ticket=%d",
                     symbol, lot, bid, sl, tp, ticket);
         return ticket;
      }
      else
      {
         uint error = m_trade.ResultRetcode();
         PrintFormat("[TradeMgr] SELL failed (attempt %d): %s Error=%d %s",
                     retry + 1, symbol, error, m_trade.ResultRetcodeDescription());

         if(error == TRADE_RETCODE_INVALID_STOPS ||
            error == TRADE_RETCODE_INVALID_VOLUME ||
            error == TRADE_RETCODE_MARKET_CLOSED ||
            error == TRADE_RETCODE_NO_MONEY)
            break;

         Sleep(500);
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Close a specific position by ticket                               |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
   {
      PrintFormat("[TradeMgr] Position %d not found", ticket);
      return false;
   }

   if(m_trade.PositionClose(ticket))
   {
      PrintFormat("[TradeMgr] Position %d closed", ticket);
      return true;
   }
   else
   {
      PrintFormat("[TradeMgr] Failed to close position %d: %s",
                  ticket, m_trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Close all positions belonging to this EA                          |
//+------------------------------------------------------------------+
bool CTradeManager::CloseAllPositions()
{
   bool all_closed = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;

      if(!m_trade.PositionClose(ticket))
      {
         PrintFormat("[TradeMgr] Failed to close position %d: %s",
                     ticket, m_trade.ResultRetcodeDescription());
         all_closed = false;
      }
      else
      {
         PrintFormat("[TradeMgr] Closed position %d (CloseAll)", ticket);
      }
   }

   return all_closed;
}

//+------------------------------------------------------------------+
//| Close all positions for a specific symbol                         |
//+------------------------------------------------------------------+
bool CTradeManager::CloseSymbolPositions(string symbol)
{
   bool all_closed = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;

      if(!m_trade.PositionClose(ticket))
      {
         all_closed = false;
      }
   }

   return all_closed;
}

//+------------------------------------------------------------------+
//| Modify position SL/TP                                             |
//+------------------------------------------------------------------+
bool CTradeManager::ModifyPosition(ulong ticket, double new_sl, double new_tp)
{
   if(!PositionSelectByTicket(ticket)) return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   new_sl = NormalizePrice(symbol, new_sl);
   new_tp = NormalizePrice(symbol, new_tp);

   return m_trade.PositionModify(ticket, new_sl, new_tp);
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                  |
//+------------------------------------------------------------------+
int CTradeManager::CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic_number)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count open positions for a specific symbol                        |
//+------------------------------------------------------------------+
int CTradeManager::CountSymbolPositions(string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
         PositionGetString(POSITION_SYMBOL) == symbol)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get total floating profit for this EA                             |
//+------------------------------------------------------------------+
double CTradeManager::GetTotalProfit()
{
   double total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) == m_magic_number)
         total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

//+------------------------------------------------------------------+
//| Get floating profit for a specific symbol                         |
//+------------------------------------------------------------------+
double CTradeManager::GetSymbolProfit(string symbol)
{
   double total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
         PositionGetString(POSITION_SYMBOL) == symbol)
         total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

//+------------------------------------------------------------------+
//| Check if there's already an open position for symbol+direction    |
//+------------------------------------------------------------------+
bool CTradeManager::HasOpenPosition(string symbol, ENUM_POSITION_TYPE type)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
         PositionGetString(POSITION_SYMBOL) == symbol &&
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Record trade time for a symbol (per-symbol cooldown)             |
//+------------------------------------------------------------------+
void CTradeManager::RecordTradeTime(string symbol)
{
   // Find existing entry
   for(int i = 0; i < m_tracked_count; i++)
   {
      if(m_tracked_symbols[i] == symbol)
      {
         m_last_trade_time[i] = TimeCurrent();
         return;
      }
   }
   // Add new entry
   m_tracked_count++;
   ArrayResize(m_tracked_symbols, m_tracked_count);
   ArrayResize(m_last_trade_time, m_tracked_count);
   m_tracked_symbols[m_tracked_count - 1] = symbol;
   m_last_trade_time[m_tracked_count - 1] = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Anti-overtrading: per-symbol cooldown check                       |
//+------------------------------------------------------------------+
bool CTradeManager::CanTradeNow(string symbol)
{
   // Per-symbol cooldown: min bars between trades on SAME symbol
   for(int i = 0; i < m_tracked_count; i++)
   {
      if(m_tracked_symbols[i] == symbol)
      {
         int seconds_gap = m_min_bar_gap * PeriodSeconds(PERIOD_M15);
         if(TimeCurrent() - m_last_trade_time[i] < seconds_gap)
            return false;
         break;
      }
   }

   return true;
}
//+------------------------------------------------------------------+
