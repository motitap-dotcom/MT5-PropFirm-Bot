//+------------------------------------------------------------------+
//|                                              SignalEngine.mqh     |
//|                     PropFirm Bot v4.0 - Trend + Momentum Signals  |
//|                     EMA Trend + RSI + MACD Confirmation            |
//+------------------------------------------------------------------+
//|  Strategy: Trend-Following with Momentum Confirmation             |
//|  - H1 EMA50 determines trade direction (trend filter)             |
//|  - M15 EMA 8/21 crossover for entry timing                       |
//|  - RSI confirms momentum (not overbought/oversold)                |
//|  - MACD histogram confirms momentum direction                     |
//|  - ATR for dynamic SL/TP sizing                                   |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "4.00"

#include <Trade\Trade.mqh>

//--- Signal types
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE     = 0,  // No signal
   SIGNAL_BUY      = 1,  // Buy signal
   SIGNAL_SELL     = -1  // Sell signal
};

enum ENUM_STRATEGY_TYPE
{
   STRATEGY_TREND_MOMENTUM = 0,  // Trend + Momentum (primary)
   STRATEGY_EMA_CROSS      = 1   // EMA Crossover (simplified fallback)
};

//+------------------------------------------------------------------+
//| Signal Engine Class                                               |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
   // Indicator handles - M15 (entry timeframe)
   int               m_handle_ema_fast;     // EMA 8
   int               m_handle_ema_slow;     // EMA 21
   int               m_handle_rsi;          // RSI 14
   int               m_handle_atr;          // ATR 14
   int               m_handle_macd;         // MACD 12,26,9

   // Indicator handles - H1 (trend filter)
   int               m_handle_ema_h1_50;    // EMA 50 on H1

   // Symbol and timeframes
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf_entry;            // M15
   ENUM_TIMEFRAMES   m_tf_htf;              // H1

   // Parameters
   int               m_ema_fast_period;
   int               m_ema_slow_period;
   int               m_rsi_period;
   int               m_atr_period;
   double            m_rsi_buy_max;         // Max RSI for buy (not overbought)
   double            m_rsi_buy_min;         // Min RSI for buy (has momentum)
   double            m_rsi_sell_max;        // Max RSI for sell
   double            m_rsi_sell_min;        // Min RSI for sell (not oversold)
   double            m_atr_sl_multiplier;   // SL = ATR * this
   double            m_atr_tp_multiplier;   // TP = ATR * this
   double            m_min_atr_filter;      // Minimum ATR to trade (volatility filter)

   // Internal buffers
   double            m_ema_fast[];
   double            m_ema_slow[];
   double            m_rsi[];
   double            m_atr[];
   double            m_macd_main[];
   double            m_macd_signal[];
   double            m_macd_hist[];
   double            m_ema_h1_50[];

   // Trend filter
   int               GetH1TrendBias();

public:
                     CSignalEngine();
                    ~CSignalEngine();

   bool              Init(string symbol,
                          ENUM_TIMEFRAMES tf_entry = PERIOD_M15,
                          ENUM_TIMEFRAMES tf_htf = PERIOD_H1,
                          int ema_fast = 8,
                          int ema_slow = 21,
                          int rsi_period = 14,
                          int atr_period = 14);

   void              Deinit();

   // Strategy parameters
   void              SetRSILevels(double buy_min, double buy_max, double sell_min, double sell_max);
   void              SetATRMultipliers(double sl_mult, double tp_mult);
   void              SetMinATR(double min_atr);

   // Main signal methods
   ENUM_SIGNAL_TYPE  GetTrendMomentumSignal(double &sl_price, double &tp_price);
   ENUM_SIGNAL_TYPE  GetEMACrossSignal(double &sl_price, double &tp_price);
   ENUM_SIGNAL_TYPE  GetSignal(ENUM_STRATEGY_TYPE strategy, double &sl_price, double &tp_price);

   // Utility
   double            GetCurrentATR();
   double            GetCurrentRSI();
   bool              IsEMABullish();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSignalEngine::CSignalEngine()
{
   m_handle_ema_fast  = INVALID_HANDLE;
   m_handle_ema_slow  = INVALID_HANDLE;
   m_handle_rsi       = INVALID_HANDLE;
   m_handle_atr       = INVALID_HANDLE;
   m_handle_macd      = INVALID_HANDLE;
   m_handle_ema_h1_50 = INVALID_HANDLE;

   // RSI levels: buy when 35-68, sell when 32-65
   m_rsi_buy_min  = 35.0;
   m_rsi_buy_max  = 68.0;
   m_rsi_sell_min = 32.0;
   m_rsi_sell_max = 65.0;

   // ATR multipliers for SL/TP
   m_atr_sl_multiplier = 1.5;
   m_atr_tp_multiplier = 3.0;  // 2:1 RR minimum

   m_min_atr_filter = 0.0;  // Will be set per symbol
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSignalEngine::~CSignalEngine()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialize indicators                                             |
//+------------------------------------------------------------------+
bool CSignalEngine::Init(string symbol,
                          ENUM_TIMEFRAMES tf_entry,
                          ENUM_TIMEFRAMES tf_htf,
                          int ema_fast,
                          int ema_slow,
                          int rsi_period,
                          int atr_period)
{
   m_symbol         = symbol;
   m_tf_entry       = tf_entry;
   m_tf_htf         = tf_htf;
   m_ema_fast_period= ema_fast;
   m_ema_slow_period= ema_slow;
   m_rsi_period     = rsi_period;
   m_atr_period     = atr_period;

   // Create M15 indicator handles
   m_handle_ema_fast = iMA(m_symbol, m_tf_entry, m_ema_fast_period, 0, MODE_EMA, PRICE_CLOSE);
   if(m_handle_ema_fast == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create EMA(%d) handle for %s: %d", m_ema_fast_period, m_symbol, GetLastError());
      return false;
   }

   m_handle_ema_slow = iMA(m_symbol, m_tf_entry, m_ema_slow_period, 0, MODE_EMA, PRICE_CLOSE);
   if(m_handle_ema_slow == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create EMA(%d) handle for %s: %d", m_ema_slow_period, m_symbol, GetLastError());
      return false;
   }

   m_handle_rsi = iRSI(m_symbol, m_tf_entry, m_rsi_period, PRICE_CLOSE);
   if(m_handle_rsi == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create RSI handle for %s: %d", m_symbol, GetLastError());
      return false;
   }

   m_handle_atr = iATR(m_symbol, m_tf_entry, m_atr_period);
   if(m_handle_atr == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create ATR handle for %s: %d", m_symbol, GetLastError());
      return false;
   }

   m_handle_macd = iMACD(m_symbol, m_tf_entry, 12, 26, 9, PRICE_CLOSE);
   if(m_handle_macd == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create MACD handle for %s: %d", m_symbol, GetLastError());
      return false;
   }

   // Create H1 trend filter handle
   m_handle_ema_h1_50 = iMA(m_symbol, m_tf_htf, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(m_handle_ema_h1_50 == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create H1 EMA(50) handle for %s: %d", m_symbol, GetLastError());
      return false;
   }

   // Set arrays as series (newest first)
   ArraySetAsSeries(m_ema_fast, true);
   ArraySetAsSeries(m_ema_slow, true);
   ArraySetAsSeries(m_rsi, true);
   ArraySetAsSeries(m_atr, true);
   ArraySetAsSeries(m_macd_main, true);
   ArraySetAsSeries(m_macd_signal, true);
   ArraySetAsSeries(m_macd_hist, true);
   ArraySetAsSeries(m_ema_h1_50, true);

   PrintFormat("[SignalEngine] Initialized for %s | Entry: %s | HTF: %s | EMA %d/%d | RSI %d | ATR %d | MACD 12/26/9",
               m_symbol, EnumToString(m_tf_entry), EnumToString(m_tf_htf),
               m_ema_fast_period, m_ema_slow_period, m_rsi_period, m_atr_period);

   return true;
}

//+------------------------------------------------------------------+
//| Release indicator handles                                         |
//+------------------------------------------------------------------+
void CSignalEngine::Deinit()
{
   if(m_handle_ema_fast  != INVALID_HANDLE) IndicatorRelease(m_handle_ema_fast);
   if(m_handle_ema_slow  != INVALID_HANDLE) IndicatorRelease(m_handle_ema_slow);
   if(m_handle_rsi       != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
   if(m_handle_atr       != INVALID_HANDLE) IndicatorRelease(m_handle_atr);
   if(m_handle_macd      != INVALID_HANDLE) IndicatorRelease(m_handle_macd);
   if(m_handle_ema_h1_50 != INVALID_HANDLE) IndicatorRelease(m_handle_ema_h1_50);

   m_handle_ema_fast  = INVALID_HANDLE;
   m_handle_ema_slow  = INVALID_HANDLE;
   m_handle_rsi       = INVALID_HANDLE;
   m_handle_atr       = INVALID_HANDLE;
   m_handle_macd      = INVALID_HANDLE;
   m_handle_ema_h1_50 = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Set RSI levels for buy/sell filters                               |
//+------------------------------------------------------------------+
void CSignalEngine::SetRSILevels(double buy_min, double buy_max, double sell_min, double sell_max)
{
   m_rsi_buy_min  = buy_min;
   m_rsi_buy_max  = buy_max;
   m_rsi_sell_min = sell_min;
   m_rsi_sell_max = sell_max;
}

//+------------------------------------------------------------------+
//| Set ATR multipliers for SL and TP                                 |
//+------------------------------------------------------------------+
void CSignalEngine::SetATRMultipliers(double sl_mult, double tp_mult)
{
   m_atr_sl_multiplier = sl_mult;
   m_atr_tp_multiplier = tp_mult;
}

//+------------------------------------------------------------------+
//| Set minimum ATR filter                                            |
//+------------------------------------------------------------------+
void CSignalEngine::SetMinATR(double min_atr)
{
   m_min_atr_filter = min_atr;
}

//+------------------------------------------------------------------+
//| Get H1 Trend Bias: +1 = bullish, -1 = bearish, 0 = no trend     |
//+------------------------------------------------------------------+
int CSignalEngine::GetH1TrendBias()
{
   if(CopyBuffer(m_handle_ema_h1_50, 0, 0, 5, m_ema_h1_50) < 5) return 0;

   double close_h1[];
   ArraySetAsSeries(close_h1, true);
   if(CopyClose(m_symbol, m_tf_htf, 0, 5, close_h1) < 5) return 0;

   // Price above EMA50 for at least 2 of last 3 bars = bullish
   int above_count = 0;
   for(int i = 0; i < 3; i++)
      if(close_h1[i] > m_ema_h1_50[i]) above_count++;

   if(above_count >= 2) return 1;  // Bullish trend

   // Price below EMA50 for at least 2 of last 3 bars = bearish
   int below_count = 0;
   for(int i = 0; i < 3; i++)
      if(close_h1[i] < m_ema_h1_50[i]) below_count++;

   if(below_count >= 2) return -1;  // Bearish trend

   return 0;  // No clear trend
}

//+------------------------------------------------------------------+
//| PRIMARY: Trend + Momentum Signal                                  |
//| H1 trend filter + M15 EMA cross + RSI + MACD confirmation        |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalEngine::GetTrendMomentumSignal(double &sl_price, double &tp_price)
{
   sl_price = 0;
   tp_price = 0;

   // Step 1: Get H1 trend direction
   int trend = GetH1TrendBias();
   if(trend == 0)
   {
      // No clear trend - skip
      return SIGNAL_NONE;
   }

   // Step 2: Copy M15 indicator data (need 3 bars for crossover detection)
   if(CopyBuffer(m_handle_ema_fast, 0, 0, 4, m_ema_fast) < 4) return SIGNAL_NONE;
   if(CopyBuffer(m_handle_ema_slow, 0, 0, 4, m_ema_slow) < 4) return SIGNAL_NONE;
   if(CopyBuffer(m_handle_rsi, 0, 0, 3, m_rsi) < 3)           return SIGNAL_NONE;
   if(CopyBuffer(m_handle_atr, 0, 0, 3, m_atr) < 3)           return SIGNAL_NONE;
   if(CopyBuffer(m_handle_macd, 2, 0, 3, m_macd_hist) < 3)    return SIGNAL_NONE;

   double atr = m_atr[1];  // Use previous bar ATR (complete bar)
   if(atr <= 0) return SIGNAL_NONE;

   // Minimum volatility filter
   if(m_min_atr_filter > 0 && atr < m_min_atr_filter)
      return SIGNAL_NONE;

   // Step 3: Check for EMA crossover on COMPLETED bars (bar[1] and bar[2])
   // Cross up:  EMA_fast was below EMA_slow on bar[2], now above on bar[1]
   bool cross_up   = (m_ema_fast[2] <= m_ema_slow[2]) && (m_ema_fast[1] > m_ema_slow[1]);
   // Cross down: EMA_fast was above EMA_slow on bar[2], now below on bar[1]
   bool cross_down = (m_ema_fast[2] >= m_ema_slow[2]) && (m_ema_fast[1] < m_ema_slow[1]);

   // Also accept: EMA already aligned in trend direction AND momentum increasing
   // This catches continuation entries, not just crossovers
   bool ema_bullish_aligned = (m_ema_fast[1] > m_ema_slow[1]) &&
                               (m_ema_fast[1] - m_ema_slow[1] > m_ema_fast[2] - m_ema_slow[2]);
   bool ema_bearish_aligned = (m_ema_fast[1] < m_ema_slow[1]) &&
                               (m_ema_slow[1] - m_ema_fast[1] > m_ema_slow[2] - m_ema_fast[2]);

   double rsi = m_rsi[1];  // Use completed bar RSI
   double macd_hist = m_macd_hist[1];      // MACD histogram on completed bar
   double macd_hist_prev = m_macd_hist[2]; // Previous MACD histogram

   // === BUY SIGNAL ===
   if(trend == 1)  // H1 bullish
   {
      bool ema_ok = cross_up || ema_bullish_aligned;
      bool rsi_ok = (rsi >= m_rsi_buy_min && rsi <= m_rsi_buy_max);
      bool macd_ok = (macd_hist > 0) || (macd_hist > macd_hist_prev); // Positive or improving

      if(ema_ok && rsi_ok && macd_ok)
      {
         double entry = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         sl_price = entry - (atr * m_atr_sl_multiplier);
         tp_price = entry + (atr * m_atr_tp_multiplier);

         PrintFormat("[TREND] BUY %s: Entry=%.5f SL=%.5f TP=%.5f | RSI=%.1f MACD=%.6f ATR=%.5f | Cross=%s Aligned=%s",
                     m_symbol, entry, sl_price, tp_price, rsi, macd_hist, atr,
                     cross_up ? "Y" : "N", ema_bullish_aligned ? "Y" : "N");

         return SIGNAL_BUY;
      }
   }

   // === SELL SIGNAL ===
   if(trend == -1)  // H1 bearish
   {
      bool ema_ok = cross_down || ema_bearish_aligned;
      bool rsi_ok = (rsi >= m_rsi_sell_min && rsi <= m_rsi_sell_max);
      bool macd_ok = (macd_hist < 0) || (macd_hist < macd_hist_prev); // Negative or declining

      if(ema_ok && rsi_ok && macd_ok)
      {
         double entry = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         sl_price = entry + (atr * m_atr_sl_multiplier);
         tp_price = entry - (atr * m_atr_tp_multiplier);

         PrintFormat("[TREND] SELL %s: Entry=%.5f SL=%.5f TP=%.5f | RSI=%.1f MACD=%.6f ATR=%.5f | Cross=%s Aligned=%s",
                     m_symbol, entry, sl_price, tp_price, rsi, macd_hist, atr,
                     cross_down ? "Y" : "N", ema_bearish_aligned ? "Y" : "N");

         return SIGNAL_SELL;
      }
   }

   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| FALLBACK: Simple EMA Crossover Signal (no MACD required)          |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalEngine::GetEMACrossSignal(double &sl_price, double &tp_price)
{
   sl_price = 0;
   tp_price = 0;

   // Copy indicator data
   if(CopyBuffer(m_handle_ema_fast, 0, 0, 4, m_ema_fast) < 4) return SIGNAL_NONE;
   if(CopyBuffer(m_handle_ema_slow, 0, 0, 4, m_ema_slow) < 4) return SIGNAL_NONE;
   if(CopyBuffer(m_handle_rsi, 0, 0, 3, m_rsi) < 3)           return SIGNAL_NONE;
   if(CopyBuffer(m_handle_atr, 0, 0, 3, m_atr) < 3)           return SIGNAL_NONE;

   double atr = m_atr[1];
   if(atr <= 0) return SIGNAL_NONE;

   double rsi = m_rsi[1];

   // EMA crossover on completed bars
   bool cross_up   = (m_ema_fast[2] <= m_ema_slow[2]) && (m_ema_fast[1] > m_ema_slow[1]);
   bool cross_down = (m_ema_fast[2] >= m_ema_slow[2]) && (m_ema_fast[1] < m_ema_slow[1]);

   // BUY: EMA cross up + RSI not overbought
   if(cross_up && rsi < 70 && rsi > 30)
   {
      double entry = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      sl_price = entry - (atr * m_atr_sl_multiplier);
      tp_price = entry + (atr * m_atr_tp_multiplier);

      PrintFormat("[EMA] BUY %s: Entry=%.5f SL=%.5f TP=%.5f RSI=%.1f",
                  m_symbol, entry, sl_price, tp_price, rsi);
      return SIGNAL_BUY;
   }

   // SELL: EMA cross down + RSI not oversold
   if(cross_down && rsi > 30 && rsi < 70)
   {
      double entry = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      sl_price = entry + (atr * m_atr_sl_multiplier);
      tp_price = entry - (atr * m_atr_tp_multiplier);

      PrintFormat("[EMA] SELL %s: Entry=%.5f SL=%.5f TP=%.5f RSI=%.1f",
                  m_symbol, entry, sl_price, tp_price, rsi);
      return SIGNAL_SELL;
   }

   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Main signal dispatcher                                            |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalEngine::GetSignal(ENUM_STRATEGY_TYPE strategy, double &sl_price, double &tp_price)
{
   switch(strategy)
   {
      case STRATEGY_TREND_MOMENTUM:
         return GetTrendMomentumSignal(sl_price, tp_price);

      case STRATEGY_EMA_CROSS:
         return GetEMACrossSignal(sl_price, tp_price);

      default:
         return SIGNAL_NONE;
   }
}

//+------------------------------------------------------------------+
//| Get current ATR value                                             |
//+------------------------------------------------------------------+
double CSignalEngine::GetCurrentATR()
{
   if(CopyBuffer(m_handle_atr, 0, 0, 2, m_atr) < 2) return 0;
   return m_atr[1];  // Completed bar
}

//+------------------------------------------------------------------+
//| Get current RSI value                                             |
//+------------------------------------------------------------------+
double CSignalEngine::GetCurrentRSI()
{
   if(CopyBuffer(m_handle_rsi, 0, 0, 2, m_rsi) < 2) return 50;
   return m_rsi[1];  // Completed bar
}

//+------------------------------------------------------------------+
//| Check if EMA fast > EMA slow (bullish)                            |
//+------------------------------------------------------------------+
bool CSignalEngine::IsEMABullish()
{
   if(CopyBuffer(m_handle_ema_fast, 0, 0, 2, m_ema_fast) < 2) return false;
   if(CopyBuffer(m_handle_ema_slow, 0, 0, 2, m_ema_slow) < 2) return false;
   return m_ema_fast[1] > m_ema_slow[1];
}
//+------------------------------------------------------------------+
