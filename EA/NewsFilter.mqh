//+------------------------------------------------------------------+
//|                                                NewsFilter.mqh    |
//|                     HIGH-IMPACT NEWS EVENT FILTER                 |
//|                     Prevents trading around economic releases     |
//+------------------------------------------------------------------+
//|  Uses MQL5 Economic Calendar to detect upcoming news events.     |
//|  Blocks trading X minutes before and after high-impact events.   |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "1.00"

//+------------------------------------------------------------------+
class CNewsFilter
{
private:
   int      m_minutes_before;        // Minutes before event to stop trading
   int      m_minutes_after;         // Minutes after event to resume
   int      m_close_minutes_before;  // Minutes before event to close open positions
   bool     m_close_positions;       // Close open positions before news
   bool     m_filter_high;           // Filter high impact
   bool     m_filter_medium;         // Filter medium impact
   bool     m_enabled;               // Master switch

   // Cached news events
   struct NewsEvent
   {
      datetime time;
      string   name;
      string   currency;
      int      impact;     // 1=low, 2=medium, 3=high
   };

   NewsEvent m_events[];
   int       m_event_count;
   datetime  m_last_refresh;
   int       m_refresh_interval;     // Seconds between calendar refreshes

   // Symbols we trade - their base/quote currencies
   string    m_currencies[];
   int       m_currency_count;

   void      RefreshCalendar();
   bool      IsCurrencyRelevant(string currency);
   void      BuildCurrencyList(string &symbols[], int count);

public:
              CNewsFilter();
             ~CNewsFilter() {}

   void      Init(int minutes_before = 30, int minutes_after = 30,
                   bool filter_high = true, bool filter_medium = false);
   void      SetSymbols(string &symbols[], int count);
   void      Enable(bool on) { m_enabled = on; }
   void      SetCloseBeforeNews(bool enabled, int minutes = 30);

   // Main check: is it safe to trade right now?
   bool      IsSafeToTrade();
   bool      IsSafeToTradeSymbol(string symbol);

   // Pre-news position close: should we close open positions now?
   bool      ShouldClosePositions();
   string    GetCloseReason();

   // Info
   string    GetNextEventInfo();
   int       MinutesToNextEvent();
   string    GetBlockReason();

private:
   string    m_block_reason;
   string    m_close_reason;
};

//+------------------------------------------------------------------+
CNewsFilter::CNewsFilter()
{
   m_minutes_before       = 30;
   m_minutes_after        = 30;
   m_close_minutes_before = 30;
   m_close_positions      = false;
   m_filter_high          = true;
   m_filter_medium        = false;
   m_enabled              = true;
   m_event_count          = 0;
   m_last_refresh         = 0;
   m_refresh_interval     = 3600;  // Refresh every hour
   m_currency_count       = 0;
   m_block_reason         = "";
   m_close_reason         = "";
}

//+------------------------------------------------------------------+
void CNewsFilter::Init(int minutes_before, int minutes_after,
                         bool filter_high, bool filter_medium)
{
   m_minutes_before = minutes_before;
   m_minutes_after  = minutes_after;
   m_filter_high    = filter_high;
   m_filter_medium  = filter_medium;

   PrintFormat("[NewsFilter] Init: Before=%dmin After=%dmin High=%s Medium=%s",
               m_minutes_before, m_minutes_after,
               m_filter_high ? "Y" : "N",
               m_filter_medium ? "Y" : "N");

   RefreshCalendar();
}

//+------------------------------------------------------------------+
void CNewsFilter::SetSymbols(string &symbols[], int count)
{
   BuildCurrencyList(symbols, count);
}

//+------------------------------------------------------------------+
void CNewsFilter::BuildCurrencyList(string &symbols[], int count)
{
   // Extract unique currencies from symbol names
   // e.g., EURUSD -> EUR, USD | XAUUSD -> XAU, USD
   m_currency_count = 0;
   ArrayResize(m_currencies, count * 2);

   for(int i = 0; i < count; i++)
   {
      string sym = symbols[i];
      string base = "", quote = "";

      // Handle standard 6-char forex pairs
      if(StringLen(sym) >= 6)
      {
         base  = StringSubstr(sym, 0, 3);
         quote = StringSubstr(sym, 3, 3);
      }

      // Add if not already in list
      bool found_base = false, found_quote = false;
      for(int j = 0; j < m_currency_count; j++)
      {
         if(m_currencies[j] == base) found_base = true;
         if(m_currencies[j] == quote) found_quote = true;
      }

      if(!found_base && base != "")
      { m_currencies[m_currency_count] = base; m_currency_count++; }
      if(!found_quote && quote != "")
      { m_currencies[m_currency_count] = quote; m_currency_count++; }
   }

   ArrayResize(m_currencies, m_currency_count);

   string list = "";
   for(int i = 0; i < m_currency_count; i++)
   {
      if(i > 0) list += ", ";
      list += m_currencies[i];
   }
   PrintFormat("[NewsFilter] Monitoring currencies: %s", list);
}

//+------------------------------------------------------------------+
bool CNewsFilter::IsCurrencyRelevant(string currency)
{
   for(int i = 0; i < m_currency_count; i++)
   {
      if(m_currencies[i] == currency)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void CNewsFilter::RefreshCalendar()
{
   datetime now = TimeCurrent();

   // Don't refresh too often
   if(m_last_refresh > 0 && now - m_last_refresh < m_refresh_interval)
      return;

   m_last_refresh = now;
   m_event_count = 0;

   // Fetch economic calendar events for the next 24 hours
   MqlCalendarValue values[];
   datetime from_time = now - m_minutes_after * 60;  // Include recent events still in effect
   datetime to_time   = now + 86400;                  // Next 24 hours

   int total = CalendarValueHistory(values, from_time, to_time);

   if(total <= 0)
   {
      // Calendar might not be available - don't block trading
      PrintFormat("[NewsFilter] Calendar returned %d events (may be unavailable)", total);
      return;
   }

   ArrayResize(m_events, total);

   for(int i = 0; i < total; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;

      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;

      // Check impact level
      int impact = 0;
      if(event.importance == CALENDAR_IMPORTANCE_HIGH)   impact = 3;
      else if(event.importance == CALENDAR_IMPORTANCE_MODERATE) impact = 2;
      else if(event.importance == CALENDAR_IMPORTANCE_LOW)      impact = 1;

      // Filter by our criteria
      if(impact == 3 && !m_filter_high) continue;
      if(impact == 2 && !m_filter_medium) continue;
      if(impact < 2) continue;  // Always skip low impact

      // Check if this currency is relevant to us
      string currency = country.currency;
      if(!IsCurrencyRelevant(currency)) continue;

      // Store the event
      m_events[m_event_count].time     = values[i].time;
      m_events[m_event_count].name     = event.name;
      m_events[m_event_count].currency = currency;
      m_events[m_event_count].impact   = impact;
      m_event_count++;
   }

   ArrayResize(m_events, m_event_count);
   PrintFormat("[NewsFilter] Loaded %d relevant events from calendar", m_event_count);
}

//+------------------------------------------------------------------+
bool CNewsFilter::IsSafeToTrade()
{
   if(!m_enabled) return true;

   RefreshCalendar();

   datetime now = TimeCurrent();
   m_block_reason = "";

   for(int i = 0; i < m_event_count; i++)
   {
      datetime event_time = m_events[i].time;
      datetime block_start = event_time - m_minutes_before * 60;
      datetime block_end   = event_time + m_minutes_after * 60;

      if(now >= block_start && now <= block_end)
      {
         int mins_to_event = (int)(event_time - now) / 60;
         string timing = "";
         if(mins_to_event > 0)
            timing = StringFormat("in %d min", mins_to_event);
         else if(mins_to_event == 0)
            timing = "NOW";
         else
            timing = StringFormat("%d min ago", -mins_to_event);

         m_block_reason = StringFormat("NEWS: %s %s (%s) %s",
            m_events[i].currency,
            m_events[i].name,
            m_events[i].impact == 3 ? "HIGH" : "MED",
            timing);

         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
bool CNewsFilter::IsSafeToTradeSymbol(string symbol)
{
   if(!m_enabled) return true;

   RefreshCalendar();

   // Extract currencies from this symbol
   string base = "", quote = "";
   if(StringLen(symbol) >= 6)
   {
      base  = StringSubstr(symbol, 0, 3);
      quote = StringSubstr(symbol, 3, 3);
   }

   datetime now = TimeCurrent();

   for(int i = 0; i < m_event_count; i++)
   {
      // Only block if the event currency matches this symbol
      if(m_events[i].currency != base && m_events[i].currency != quote)
         continue;

      datetime event_time = m_events[i].time;
      datetime block_start = event_time - m_minutes_before * 60;
      datetime block_end   = event_time + m_minutes_after * 60;

      if(now >= block_start && now <= block_end)
      {
         m_block_reason = StringFormat("NEWS: %s %s for %s",
            m_events[i].currency, m_events[i].name, symbol);
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
void CNewsFilter::SetCloseBeforeNews(bool enabled, int minutes)
{
   m_close_positions      = enabled;
   m_close_minutes_before = minutes;
   PrintFormat("[NewsFilter] Close positions before news: %s (%d min)",
               enabled ? "ON" : "OFF", minutes);
}

//+------------------------------------------------------------------+
bool CNewsFilter::ShouldClosePositions()
{
   if(!m_enabled || !m_close_positions) return false;

   RefreshCalendar();

   datetime now = TimeCurrent();
   m_close_reason = "";

   for(int i = 0; i < m_event_count; i++)
   {
      if(m_events[i].impact < 3) continue;  // Only close for HIGH impact

      datetime event_time = m_events[i].time;
      datetime close_start = event_time - m_close_minutes_before * 60;

      if(now >= close_start && now < event_time)
      {
         int mins_to_event = (int)(event_time - now) / 60;
         m_close_reason = StringFormat("NEWS CLOSE: %s %s (HIGH) in %d min - closing positions",
            m_events[i].currency, m_events[i].name, mins_to_event);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
string CNewsFilter::GetCloseReason()
{
   return m_close_reason;
}

//+------------------------------------------------------------------+
string CNewsFilter::GetNextEventInfo()
{
   RefreshCalendar();

   datetime now = TimeCurrent();
   datetime nearest = D'2099.01.01';
   int nearest_idx = -1;

   for(int i = 0; i < m_event_count; i++)
   {
      if(m_events[i].time > now && m_events[i].time < nearest)
      {
         nearest = m_events[i].time;
         nearest_idx = i;
      }
   }

   if(nearest_idx < 0) return "No upcoming events";

   int mins = (int)(nearest - now) / 60;
   return StringFormat("%s %s [%s] in %dh %dm",
      m_events[nearest_idx].currency,
      m_events[nearest_idx].name,
      m_events[nearest_idx].impact == 3 ? "HIGH" : "MED",
      mins / 60, mins % 60);
}

//+------------------------------------------------------------------+
int CNewsFilter::MinutesToNextEvent()
{
   RefreshCalendar();

   datetime now = TimeCurrent();
   int min_minutes = 99999;

   for(int i = 0; i < m_event_count; i++)
   {
      if(m_events[i].time > now)
      {
         int mins = (int)(m_events[i].time - now) / 60;
         if(mins < min_minutes) min_minutes = mins;
      }
   }

   return min_minutes;
}

//+------------------------------------------------------------------+
string CNewsFilter::GetBlockReason()
{
   return m_block_reason;
}
//+------------------------------------------------------------------+
