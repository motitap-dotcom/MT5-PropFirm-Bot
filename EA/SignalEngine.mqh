//+------------------------------------------------------------------+
//|                                              SignalEngine.mqh     |
//|                        PropFirm Challenge Bot - Signal Generator  |
//|                        London/NY Session Breakout + SMC Concepts  |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "1.00"

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
   STRATEGY_SMC       = 0,  // Smart Money Concepts (primary)
   STRATEGY_EMA_CROSS = 1   // EMA Crossover (fallback)
};

//+------------------------------------------------------------------+
//| Signal Engine Class                                               |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
   // Indicator handles - M15
   int               m_handle_ema_fast;     // EMA 9
   int               m_handle_ema_slow;     // EMA 21
   int               m_handle_rsi;          // RSI 14
   int               m_handle_atr;          // ATR 14

   // Indicator handles - H4 (higher timeframe bias)
   int               m_handle_ema_h4_50;    // EMA 50 on H4
   int               m_handle_ema_h4_200;   // EMA 200 on H4

   // Symbol and timeframes
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf_entry;            // M15
   ENUM_TIMEFRAMES   m_tf_htf;              // H4

   // Parameters
   int               m_ema_fast_period;
   int               m_ema_slow_period;
   int               m_rsi_period;
   int               m_atr_period;
   int               m_ob_lookback;         // Order block lookback bars
   double            m_fvg_min_size;        // Minimum FVG size in points
   double            m_rsi_overbought;
   double            m_rsi_oversold;

   // Internal buffers
   double            m_ema_fast[];
   double            m_ema_slow[];
   double            m_rsi[];
   double            m_atr[];
   double            m_ema_h4_50[];
   double            m_ema_h4_200[];

   // SMC detection methods
   bool              DetectBullishOrderBlock(int shift, double &ob_high, double &ob_low);
   bool              DetectBearishOrderBlock(int shift, double &ob_high, double &ob_low);
   bool              DetectBullishFVG(int shift, double &fvg_high, double &fvg_low);
   bool              DetectBearishFVG(int shift, double &fvg_high, double &fvg_low);
   bool              DetectLiquiditySweep(bool is_bullish, int lookback);
   int               GetHTFBias();

public:
                     CSignalEngine();
                    ~CSignalEngine();

   bool              Init(string symbol,
                          ENUM_TIMEFRAMES tf_entry = PERIOD_M15,
                          ENUM_TIMEFRAMES tf_htf = PERIOD_H4,
                          int ema_fast = 9,
                          int ema_slow = 21,
                          int rsi_period = 14,
                          int atr_period = 14,
                          int ob_lookback = 20,
                          double fvg_min_points = 50.0);

   void              Deinit();

   // Main signal methods
   ENUM_SIGNAL_TYPE  GetSMCSignal(double &sl_price, double &tp_price);
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
   m_handle_ema_h4_50 = INVALID_HANDLE;
   m_handle_ema_h4_200= INVALID_HANDLE;

   m_rsi_overbought = 70.0;
   m_rsi_oversold   = 30.0;
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
                          int atr_period,
                          int ob_lookback,
                          double fvg_min_points)
{
   m_symbol         = symbol;
   m_tf_entry       = tf_entry;
   m_tf_htf         = tf_htf;
   m_ema_fast_period= ema_fast;
   m_ema_slow_period= ema_slow;
   m_rsi_period     = rsi_period;
   m_atr_period     = atr_period;
   m_ob_lookback    = ob_lookback;
   m_fvg_min_size   = fvg_min_points;

   // Create M15 indicator handles
   m_handle_ema_fast = iMA(m_symbol, m_tf_entry, m_ema_fast_period, 0, MODE_EMA, PRICE_CLOSE);
   if(m_handle_ema_fast == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create EMA(%d) handle: %d", m_ema_fast_period, GetLastError());
      return false;
   }

   m_handle_ema_slow = iMA(m_symbol, m_tf_entry, m_ema_slow_period, 0, MODE_EMA, PRICE_CLOSE);
   if(m_handle_ema_slow == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create EMA(%d) handle: %d", m_ema_slow_period, GetLastError());
      return false;
   }

   m_handle_rsi = iRSI(m_symbol, m_tf_entry, m_rsi_period, PRICE_CLOSE);
   if(m_handle_rsi == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create RSI handle: %d", GetLastError());
      return false;
   }

   m_handle_atr = iATR(m_symbol, m_tf_entry, m_atr_period);
   if(m_handle_atr == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create ATR handle: %d", GetLastError());
      return false;
   }

   // Create H4 indicator handles
   m_handle_ema_h4_50 = iMA(m_symbol, m_tf_htf, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(m_handle_ema_h4_50 == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create H4 EMA(50) handle: %d", GetLastError());
      return false;
   }

   m_handle_ema_h4_200 = iMA(m_symbol, m_tf_htf, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(m_handle_ema_h4_200 == INVALID_HANDLE)
   {
      PrintFormat("[SignalEngine] Failed to create H4 EMA(200) handle: %d", GetLastError());
      return false;
   }

   // Set arrays as series (newest first)
   ArraySetAsSeries(m_ema_fast, true);
   ArraySetAsSeries(m_ema_slow, true);
   ArraySetAsSeries(m_rsi, true);
   ArraySetAsSeries(m_atr, true);
   ArraySetAsSeries(m_ema_h4_50, true);
   ArraySetAsSeries(m_ema_h4_200, true);

   PrintFormat("[SignalEngine] Initialized for %s | Entry TF: %s | HTF: %s",
               m_symbol,
               EnumToString(m_tf_entry),
               EnumToString(m_tf_htf));

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
   if(m_handle_ema_h4_50 != INVALID_HANDLE) IndicatorRelease(m_handle_ema_h4_50);
   if(m_handle_ema_h4_200!= INVALID_HANDLE) IndicatorRelease(m_handle_ema_h4_200);

   m_handle_ema_fast  = INVALID_HANDLE;
   m_handle_ema_slow  = INVALID_HANDLE;
   m_handle_rsi       = INVALID_HANDLE;
   m_handle_atr       = INVALID_HANDLE;
   m_handle_ema_h4_50 = INVALID_HANDLE;
   m_handle_ema_h4_200= INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe Bias: +1 = bullish, -1 = bearish, 0 = none  |
//+------------------------------------------------------------------+
int CSignalEngine::GetHTFBias()
{
   if(CopyBuffer(m_handle_ema_h4_50, 0, 0, 3, m_ema_h4_50) < 3)   return 0;
   if(CopyBuffer(m_handle_ema_h4_200, 0, 0, 3, m_ema_h4_200) < 3) return 0;

   double close_h4[];
   ArraySetAsSeries(close_h4, true);
   if(CopyClose(m_symbol, m_tf_htf, 0, 3, close_h4) < 3) return 0;

   // Strong Bullish: price above EMA50, EMA50 above EMA200
   if(close_h4[0] > m_ema_h4_50[0] && m_ema_h4_50[0] > m_ema_h4_200[0])
      return 1;

   // Strong Bearish: price below EMA50, EMA50 below EMA200
   if(close_h4[0] < m_ema_h4_50[0] && m_ema_h4_50[0] < m_ema_h4_200[0])
      return -1;

   // Weak Bullish: price above both EMAs (even if EMA50 < EMA200, early trend)
   if(close_h4[0] > m_ema_h4_50[0] && close_h4[0] > m_ema_h4_200[0])
      return 1;

   // Weak Bearish: price below both EMAs
   if(close_h4[0] < m_ema_h4_50[0] && close_h4[0] < m_ema_h4_200[0])
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Detect Bullish Order Block                                        |
//| Last bearish candle before a strong bullish move                  |
//+------------------------------------------------------------------+
bool CSignalEngine::DetectBullishOrderBlock(int shift, double &ob_high, double &ob_low)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_needed = shift + m_ob_lookback + 3;
   if(CopyRates(m_symbol, m_tf_entry, 0, bars_needed, rates) < bars_needed)
      return false;

   if(CopyBuffer(m_handle_atr, 0, 0, bars_needed, m_atr) < bars_needed)
      return false;

   // Scan for bullish order blocks
   for(int i = shift + 2; i < shift + m_ob_lookback; i++)
   {
      // Look for bearish candle followed by strong bullish move
      bool is_bearish = rates[i].close < rates[i].open;
      if(!is_bearish) continue;

      // The next candle(s) must form a strong bullish engulfing
      double bullish_move = rates[i-1].close - rates[i].low;
      double atr_val = m_atr[i];
      if(atr_val <= 0) continue;

      // Strong move = at least 1.0x ATR
      if(bullish_move < atr_val * 1.0) continue;

      // The OB zone is the body of the bearish candle
      ob_high = MathMax(rates[i].open, rates[i].close);
      ob_low  = MathMin(rates[i].open, rates[i].close);

      // Check if current price is near the OB zone (within or approaching)
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      if(ask >= ob_low - (atr_val * 0.3) && ask <= ob_high + (atr_val * 0.8))
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect Bearish Order Block                                        |
//| Last bullish candle before a strong bearish move                  |
//+------------------------------------------------------------------+
bool CSignalEngine::DetectBearishOrderBlock(int shift, double &ob_high, double &ob_low)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_needed = shift + m_ob_lookback + 3;
   if(CopyRates(m_symbol, m_tf_entry, 0, bars_needed, rates) < bars_needed)
      return false;

   if(CopyBuffer(m_handle_atr, 0, 0, bars_needed, m_atr) < bars_needed)
      return false;

   for(int i = shift + 2; i < shift + m_ob_lookback; i++)
   {
      // Look for bullish candle followed by strong bearish move
      bool is_bullish = rates[i].close > rates[i].open;
      if(!is_bullish) continue;

      double bearish_move = rates[i].high - rates[i-1].close;
      double atr_val = m_atr[i];
      if(atr_val <= 0) continue;

      if(bearish_move < atr_val * 1.0) continue;

      ob_high = MathMax(rates[i].open, rates[i].close);
      ob_low  = MathMin(rates[i].open, rates[i].close);

      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      if(bid <= ob_high + (atr_val * 0.3) && bid >= ob_low - (atr_val * 0.8))
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect Bullish Fair Value Gap (FVG)                               |
//| Gap between candle[i+1].high and candle[i-1].low                 |
//+------------------------------------------------------------------+
bool CSignalEngine::DetectBullishFVG(int shift, double &fvg_high, double &fvg_low)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_needed = shift + m_ob_lookback + 3;
   if(CopyRates(m_symbol, m_tf_entry, 0, bars_needed, rates) < bars_needed)
      return false;

   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

   for(int i = shift + 1; i < shift + m_ob_lookback - 1; i++)
   {
      // Bullish FVG: gap between candle[i+1].high (top of pre-impulse) and candle[i-1].low (bottom of post-impulse)
      double gap_low  = rates[i+1].high;  // Top of candle before the impulse (lower boundary of gap)
      double gap_high = rates[i-1].low;   // Bottom of candle after the impulse (upper boundary of gap)

      if(gap_high <= gap_low) continue; // No gap

      double gap_size = (gap_high - gap_low) / point;
      if(gap_size < m_fvg_min_size) continue;

      // Check if price is in the FVG zone
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      if(ask >= gap_low && ask <= gap_high)
      {
         fvg_high = gap_high;
         fvg_low  = gap_low;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect Bearish Fair Value Gap                                     |
//+------------------------------------------------------------------+
bool CSignalEngine::DetectBearishFVG(int shift, double &fvg_high, double &fvg_low)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_needed = shift + m_ob_lookback + 3;
   if(CopyRates(m_symbol, m_tf_entry, 0, bars_needed, rates) < bars_needed)
      return false;

   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

   for(int i = shift + 1; i < shift + m_ob_lookback - 1; i++)
   {
      // Bearish FVG: gap between candle[i-1].high and candle[i+1].low
      double gap_high = rates[i+1].low;   // Bottom of candle before the impulse
      double gap_low  = rates[i-1].high;  // Top of candle after the impulse

      if(gap_high <= gap_low) continue;

      double gap_size = (gap_high - gap_low) / point;
      if(gap_size < m_fvg_min_size) continue;

      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      if(bid >= gap_low && bid <= gap_high)
      {
         fvg_high = gap_high;
         fvg_low  = gap_low;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect Liquidity Sweep                                            |
//| Price sweeps a recent swing high/low then reverses                |
//+------------------------------------------------------------------+
bool CSignalEngine::DetectLiquiditySweep(bool is_bullish, int lookback)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_needed = lookback + 5;
   if(CopyRates(m_symbol, m_tf_entry, 0, bars_needed, rates) < bars_needed)
      return false;

   if(is_bullish)
   {
      // Find recent swing low in lookback period (skip last 2 bars)
      double swing_low = DBL_MAX;
      for(int i = 3; i < lookback; i++)
      {
         if(rates[i].low < swing_low)
            swing_low = rates[i].low;
      }

      // Check if recent bar swept below swing low then closed above
      if(rates[1].low <= swing_low && rates[1].close > swing_low)
         return true;
      if(rates[0].low <= swing_low && rates[0].close > swing_low)
         return true;
   }
   else
   {
      // Find recent swing high
      double swing_high = 0;
      for(int i = 3; i < lookback; i++)
      {
         if(rates[i].high > swing_high)
            swing_high = rates[i].high;
      }

      if(rates[1].high >= swing_high && rates[1].close < swing_high)
         return true;
      if(rates[0].high >= swing_high && rates[0].close < swing_high)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| PRIMARY: Smart Money Concepts Signal                              |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalEngine::GetSMCSignal(double &sl_price, double &tp_price)
{
   sl_price = 0;
   tp_price = 0;

   // Step 1: Get H4 bias
   int htf_bias = GetHTFBias();
   if(htf_bias == 0)
   {
      PrintFormat("[SMC] %s - no H4 bias (EMA50/200 mixed), skip", m_symbol);
      return SIGNAL_NONE;
   }

   // Step 2: Get ATR for SL/TP calculation
   if(CopyBuffer(m_handle_atr, 0, 0, 3, m_atr) < 3) return SIGNAL_NONE;
   double atr = m_atr[0];
   if(atr <= 0) return SIGNAL_NONE;

   double ob_high, ob_low, fvg_high, fvg_low;

   // Step 3: Look for BUY setup (bullish HTF bias)
   if(htf_bias == 1)
   {
      bool has_liquidity_sweep = DetectLiquiditySweep(true, 30);
      bool has_bullish_ob = DetectBullishOrderBlock(0, ob_high, ob_low);
      bool has_bullish_fvg = DetectBullishFVG(0, fvg_high, fvg_low);

      // Need order block OR fair value gap (liquidity sweep is bonus confirmation)
      if(has_bullish_ob || has_bullish_fvg)
      {
         double entry = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

         // SL below the order block or FVG zone
         if(has_bullish_ob)
            sl_price = ob_low - atr * 0.5;
         else
            sl_price = fvg_low - atr * 0.5;

         double sl_distance = entry - sl_price;
         if(sl_distance <= 0) return SIGNAL_NONE;

         // TP at 2:1 minimum RR
         tp_price = entry + (sl_distance * 2.0);

         PrintFormat("[SMC] BUY signal: Entry=%.5f SL=%.5f TP=%.5f | LiqSweep=%s OB=%s FVG=%s",
                     entry, sl_price, tp_price,
                     has_liquidity_sweep ? "Y" : "N",
                     has_bullish_ob ? "Y" : "N",
                     has_bullish_fvg ? "Y" : "N");

         return SIGNAL_BUY;
      }
      else
      {
         PrintFormat("[SMC] %s bullish bias but no OB/FVG | OB=%s FVG=%s LiqSweep=%s",
                     m_symbol, has_bullish_ob ? "Y" : "N", has_bullish_fvg ? "Y" : "N",
                     has_liquidity_sweep ? "Y" : "N");
      }
   }

   // Step 4: Look for SELL setup (bearish HTF bias)
   if(htf_bias == -1)
   {
      bool has_liquidity_sweep = DetectLiquiditySweep(false, 30);
      bool has_bearish_ob = DetectBearishOrderBlock(0, ob_high, ob_low);
      bool has_bearish_fvg = DetectBearishFVG(0, fvg_high, fvg_low);

      // Need order block OR fair value gap (liquidity sweep is bonus confirmation)
      if(has_bearish_ob || has_bearish_fvg)
      {
         double entry = SymbolInfoDouble(m_symbol, SYMBOL_BID);

         if(has_bearish_ob)
            sl_price = ob_high + atr * 0.5;
         else
            sl_price = fvg_high + atr * 0.5;

         double sl_distance = sl_price - entry;
         if(sl_distance <= 0) return SIGNAL_NONE;

         tp_price = entry - (sl_distance * 2.0);

         PrintFormat("[SMC] SELL signal: Entry=%.5f SL=%.5f TP=%.5f | LiqSweep=%s OB=%s FVG=%s",
                     entry, sl_price, tp_price,
                     has_liquidity_sweep ? "Y" : "N",
                     has_bearish_ob ? "Y" : "N",
                     has_bearish_fvg ? "Y" : "N");

         return SIGNAL_SELL;
      }
      else
      {
         PrintFormat("[SMC] %s bearish bias but no OB/FVG | OB=%s FVG=%s LiqSweep=%s",
                     m_symbol, has_bearish_ob ? "Y" : "N", has_bearish_fvg ? "Y" : "N",
                     has_liquidity_sweep ? "Y" : "N");
      }
   }

   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| FALLBACK: EMA Crossover Signal                                    |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalEngine::GetEMACrossSignal(double &sl_price, double &tp_price)
{
   sl_price = 0;
   tp_price = 0;

   // Copy more bars for recent-cross detection
   double ema_f[], ema_s[], rsi_buf[], atr_buf[];
   ArraySetAsSeries(ema_f, true);
   ArraySetAsSeries(ema_s, true);
   ArraySetAsSeries(rsi_buf, true);
   ArraySetAsSeries(atr_buf, true);

   if(CopyBuffer(m_handle_ema_fast, 0, 0, 6, ema_f) < 6) return SIGNAL_NONE;
   if(CopyBuffer(m_handle_ema_slow, 0, 0, 6, ema_s) < 6) return SIGNAL_NONE;
   if(CopyBuffer(m_handle_rsi, 0, 0, 3, rsi_buf) < 3)    return SIGNAL_NONE;
   if(CopyBuffer(m_handle_atr, 0, 0, 3, atr_buf) < 3)    return SIGNAL_NONE;

   double atr = atr_buf[0];
   if(atr <= 0) return SIGNAL_NONE;

   // Get H4 bias for confirmation
   int htf_bias = GetHTFBias();

   // === METHOD 1: Exact cross on current bar ===
   bool cross_up   = (ema_f[1] <= ema_s[1]) && (ema_f[0] > ema_s[0]);
   bool cross_down = (ema_f[1] >= ema_s[1]) && (ema_f[0] < ema_s[0]);

   // === METHOD 2: Recent cross within last 4 bars + EMA still aligned ===
   // This catches signals missed because cross happened mid-bar
   bool recent_cross_up = false;
   bool recent_cross_down = false;
   if(!cross_up && !cross_down)
   {
      // Check if cross happened in last 4 bars and EMAs are still aligned
      for(int i = 1; i < 5; i++)
      {
         if(ema_f[i] <= ema_s[i] && ema_f[i-1] > ema_s[i-1])
         {
            // Bullish cross at bar i -> i-1, check EMAs still bullish now
            if(ema_f[0] > ema_s[0]) { recent_cross_up = true; break; }
         }
         if(ema_f[i] >= ema_s[i] && ema_f[i-1] < ema_s[i-1])
         {
            // Bearish cross at bar i -> i-1, check EMAs still bearish now
            if(ema_f[0] < ema_s[0]) { recent_cross_down = true; break; }
         }
      }
   }

   // === METHOD 3: EMA momentum + RSI pullback ===
   // EMA clearly aligned + RSI pulled back to neutral zone (good entry)
   bool momentum_buy  = false;
   bool momentum_sell = false;

   double ema_gap_pct = (ema_f[0] - ema_s[0]) / ema_s[0] * 10000; // in basis points

   // Bullish momentum: EMA fast > slow by meaningful amount + RSI pulled back
   if(ema_gap_pct > 3.0 && ema_gap_pct < 30.0 && rsi_buf[0] > 40 && rsi_buf[0] < 58)
   {
      // Confirm RSI bounced from lower level (pullback entry)
      if(rsi_buf[1] < rsi_buf[0] && rsi_buf[1] < 55)
         momentum_buy = true;
   }

   // Bearish momentum: EMA fast < slow + RSI pulled back from high
   if(ema_gap_pct < -3.0 && ema_gap_pct > -30.0 && rsi_buf[0] > 42 && rsi_buf[0] < 60)
   {
      if(rsi_buf[1] > rsi_buf[0] && rsi_buf[1] > 45)
         momentum_sell = true;
   }

   // === BUY SIGNAL ===
   bool buy_signal = (cross_up || recent_cross_up || momentum_buy);
   if(buy_signal && rsi_buf[0] < m_rsi_overbought && rsi_buf[0] > 35 && htf_bias >= 0)
   {
      double entry = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      sl_price = entry - (atr * 1.5);
      double sl_distance = entry - sl_price;
      tp_price = entry + (sl_distance * 2.0);

      string method = cross_up ? "CROSS" : (recent_cross_up ? "RECENT_CROSS" : "MOMENTUM");
      PrintFormat("[EMA] BUY %s: Entry=%.5f SL=%.5f TP=%.5f RSI=%.1f HTF=%d",
                  method, entry, sl_price, tp_price, rsi_buf[0], htf_bias);
      return SIGNAL_BUY;
   }

   // === SELL SIGNAL ===
   bool sell_signal = (cross_down || recent_cross_down || momentum_sell);
   if(sell_signal && rsi_buf[0] > m_rsi_oversold && rsi_buf[0] < 65 && htf_bias <= 0)
   {
      double entry = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      sl_price = entry + (atr * 1.5);
      double sl_distance = sl_price - entry;
      tp_price = entry - (sl_distance * 2.0);

      string method = cross_down ? "CROSS" : (recent_cross_down ? "RECENT_CROSS" : "MOMENTUM");
      PrintFormat("[EMA] SELL %s: Entry=%.5f SL=%.5f TP=%.5f RSI=%.1f HTF=%d",
                  method, entry, sl_price, tp_price, rsi_buf[0], htf_bias);
      return SIGNAL_SELL;
   }

   // Log why no signal was generated
   PrintFormat("[EMA] %s no signal | CrossUp=%s RecentUp=%s MomBuy=%s | CrossDn=%s RecentDn=%s MomSell=%s | RSI=%.1f HTF=%d | EMAGap=%.1fbp",
              m_symbol,
              cross_up ? "Y" : "N", recent_cross_up ? "Y" : "N", momentum_buy ? "Y" : "N",
              cross_down ? "Y" : "N", recent_cross_down ? "Y" : "N", momentum_sell ? "Y" : "N",
              rsi_buf[0], htf_bias, ema_gap_pct);

   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Main signal dispatcher                                            |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalEngine::GetSignal(ENUM_STRATEGY_TYPE strategy, double &sl_price, double &tp_price)
{
   switch(strategy)
   {
      case STRATEGY_SMC:
         return GetSMCSignal(sl_price, tp_price);

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
   if(CopyBuffer(m_handle_atr, 0, 0, 1, m_atr) < 1) return 0;
   return m_atr[0];
}

//+------------------------------------------------------------------+
//| Get current RSI value                                             |
//+------------------------------------------------------------------+
double CSignalEngine::GetCurrentRSI()
{
   if(CopyBuffer(m_handle_rsi, 0, 0, 1, m_rsi) < 1) return 50;
   return m_rsi[0];
}

//+------------------------------------------------------------------+
//| Check if EMA fast > EMA slow (bullish)                            |
//+------------------------------------------------------------------+
bool CSignalEngine::IsEMABullish()
{
   if(CopyBuffer(m_handle_ema_fast, 0, 0, 1, m_ema_fast) < 1) return false;
   if(CopyBuffer(m_handle_ema_slow, 0, 0, 1, m_ema_slow) < 1) return false;
   return m_ema_fast[0] > m_ema_slow[0];
}
//+------------------------------------------------------------------+
