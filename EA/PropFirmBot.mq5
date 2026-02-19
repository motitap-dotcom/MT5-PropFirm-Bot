//+------------------------------------------------------------------+
//|                                              PropFirmBot.mq5      |
//|                        Prop Firm Challenge Trading Bot             |
//|                        London/NY Session | SMC + EMA Strategies   |
//+------------------------------------------------------------------+
#property copyright   "PropFirmBot"
#property version     "1.00"
#property description "Prop firm challenge bot: SMC + EMA crossover strategies"
#property description "Risk-managed for instant funding challenges"

// Include modules
#include "SignalEngine.mqh"
#include "RiskManager.mqh"
#include "TradeManager.mqh"

//+------------------------------------------------------------------+
//| Input parameters (optimizable in Strategy Tester)                 |
//+------------------------------------------------------------------+

// --- General ---
input long     InpMagicNumber     = 202502;    // Magic Number
input string   InpTradeComment    = "PFBot";   // Trade Comment

// --- Challenge Settings ---
input double   InpAccountSize     = 2000;      // Challenge Account Size ($)
input double   InpProfitTarget    = 10.0;      // Profit Target (%)
input bool     InpChallengeMode   = true;       // Challenge Mode (auto-stop at target)

// --- Strategy ---
input ENUM_STRATEGY_TYPE InpStrategy = STRATEGY_SMC; // Primary Strategy
input bool     InpUseFallback     = true;       // Use EMA fallback if SMC has no signal
input ENUM_TIMEFRAMES InpEntryTF  = PERIOD_M15; // Entry Timeframe
input ENUM_TIMEFRAMES InpHTF      = PERIOD_H4;  // Higher Timeframe

// --- Signal Parameters ---
input int      InpEMAFast         = 9;          // EMA Fast Period
input int      InpEMASlow         = 21;         // EMA Slow Period
input int      InpRSIPeriod       = 14;         // RSI Period
input int      InpATRPeriod       = 14;         // ATR Period
input int      InpOBLookback      = 20;         // Order Block Lookback Bars
input double   InpFVGMinPoints    = 50.0;       // Min FVG Size (points)

// --- Risk Management ---
input double   InpRiskPercent     = 0.75;       // Risk Per Trade (%)
input double   InpMaxRiskPercent  = 1.0;        // Max Risk Per Trade (%)
input int      InpMaxPositions    = 2;          // Max Open Positions
input double   InpDailyDDGuard   = 3.0;        // Daily Drawdown Guard (%)
input double   InpTotalDDGuard   = 7.0;        // Total Drawdown Guard (%)
input double   InpMinRR           = 2.0;        // Minimum Risk:Reward Ratio

// --- Spread Filter ---
input double   InpMaxSpreadMajor  = 3.0;       // Max Spread Major Pairs (pips)
input double   InpMaxSpreadXAU    = 5.0;        // Max Spread XAUUSD (pips)

// --- Session Filter (UTC hours) ---
input int      InpLondonStart     = 7;          // London Session Start (UTC)
input int      InpLondonEnd       = 11;         // London Session End (UTC)
input int      InpNYStart         = 12;         // NY Session Start (UTC)
input int      InpNYEnd           = 16;         // NY Session End (UTC)

// --- Trade Management ---
input double   InpTrailingActivation = 30.0;    // Trailing Stop Activation (pips)
input double   InpTrailingDistance   = 20.0;     // Trailing Stop Distance (pips)
input double   InpBEActivation      = 20.0;     // Breakeven Activation (pips)
input double   InpBEOffset          = 2.0;       // Breakeven Offset (pips)
input int      InpMinBarGap         = 2;         // Min Bars Between Trades
input int      InpSlippage          = 30;        // Max Slippage (points)

// --- Multi-Symbol ---
input bool     InpTradeEURUSD     = true;       // Trade EURUSD
input bool     InpTradeGBPUSD     = true;       // Trade GBPUSD
input bool     InpTradeUSDJPY     = true;       // Trade USDJPY
input bool     InpTradeXAUUSD     = false;      // Trade XAUUSD

//+------------------------------------------------------------------+
//| Global objects                                                    |
//+------------------------------------------------------------------+
CSignalEngine  g_signals[];       // One per symbol
CRiskManager   g_risk;
CTradeManager  g_trade;

string         g_symbols[];       // Active symbols
int            g_symbol_count = 0;

// Timing
datetime       g_last_bar_time = 0;
int            g_log_interval  = 300;  // Log status every 5 minutes
datetime       g_last_log_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("  PropFirmBot v1.00 - Initializing...");
   Print("========================================");

   // Build symbol list
   BuildSymbolList();
   if(g_symbol_count == 0)
   {
      Print("[ERROR] No symbols enabled!");
      return INIT_FAILED;
   }

   // Initialize Risk Manager
   g_risk.Init(InpAccountSize, InpRiskPercent, InpMaxRiskPercent,
               InpMaxPositions, InpDailyDDGuard, InpTotalDDGuard, InpMagicNumber);
   g_risk.SetSpreadFilter(InpMaxSpreadMajor, InpMaxSpreadXAU);
   g_risk.SetSessionFilter(InpLondonStart, InpLondonEnd, InpNYStart, InpNYEnd);
   g_risk.SetWeekendGuard(5, 20);
   g_risk.SetTrailingStop(InpTrailingActivation, InpTrailingDistance);
   g_risk.SetBreakeven(InpBEActivation, InpBEOffset);
   if(InpChallengeMode)
      g_risk.SetChallengeMode(InpProfitTarget);

   // Initialize Trade Manager
   g_trade.Init(InpMagicNumber, InpSlippage, InpTradeComment);
   g_trade.SetMinBarGap(InpMinBarGap);

   // Initialize Signal Engines for each symbol
   ArrayResize(g_signals, g_symbol_count);
   for(int i = 0; i < g_symbol_count; i++)
   {
      if(!g_signals[i].Init(g_symbols[i], InpEntryTF, InpHTF,
                             InpEMAFast, InpEMASlow, InpRSIPeriod, InpATRPeriod,
                             InpOBLookback, InpFVGMinPoints))
      {
         PrintFormat("[ERROR] Failed to init SignalEngine for %s", g_symbols[i]);
         return INIT_FAILED;
      }
   }

   // Chart display
   Comment(StringFormat("PropFirmBot | %s | Risk: %.1f%% | Max Pos: %d",
           InpChallengeMode ? "Challenge Mode" : "Normal Mode",
           InpRiskPercent, InpMaxPositions));

   Print("[INIT] PropFirmBot started successfully");
   PrintFormat("[INIT] Symbols: %d | Strategy: %s | Fallback: %s",
               g_symbol_count,
               EnumToString(InpStrategy),
               InpUseFallback ? "EMA Cross" : "None");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < g_symbol_count; i++)
      g_signals[i].Deinit();

   Comment("");
   PrintFormat("[DEINIT] PropFirmBot stopped. Reason: %d", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only process on new bar (M15) to avoid over-processing
   datetime current_bar = iTime(_Symbol, InpEntryTF, 0);
   if(current_bar == g_last_bar_time)
   {
      // Still manage open positions every tick
      ManageOpenPositions();
      return;
   }
   g_last_bar_time = current_bar;

   // Reset daily tracking
   g_risk.CheckDailyReset();

   // Weekend guard: close all positions
   if(g_risk.IsWeekendCloseTime())
   {
      if(g_trade.CountOpenPositions() > 0)
      {
         Print("[WEEKEND] Closing all positions for weekend");
         g_trade.CloseAllPositions();
      }
      return;
   }

   // Drawdown guards: close all if breached
   if(!g_risk.IsDailyDrawdownOK() || !g_risk.IsTotalDrawdownOK())
   {
      if(g_trade.CountOpenPositions() > 0)
      {
         Print("[DRAWDOWN] Emergency close - drawdown guard triggered!");
         g_trade.CloseAllPositions();
      }
      return;
   }

   // Challenge mode: stop trading if target reached
   if(InpChallengeMode && g_risk.IsProfitTargetReached())
   {
      // Log periodically
      if(TimeCurrent() - g_last_log_time > g_log_interval)
      {
         Print("[CHALLENGE] Profit target reached! Bot is idle.");
         g_last_log_time = TimeCurrent();
      }
      return;
   }

   // Periodic status log
   if(TimeCurrent() - g_last_log_time > g_log_interval)
   {
      Print(g_risk.GetStatusReport());
      g_last_log_time = TimeCurrent();
   }

   // Scan for signals on each symbol
   for(int i = 0; i < g_symbol_count; i++)
   {
      ProcessSymbol(g_symbols[i], i);
   }
}

//+------------------------------------------------------------------+
//| Process signals for a single symbol                               |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol, int signal_index)
{
   // Pre-flight checks
   if(!g_risk.CanOpenTrade(symbol)) return;
   if(!g_trade.CanTradeNow(symbol)) return;

   // Don't open if we already have a position on this symbol
   if(g_trade.CountSymbolPositions(symbol) > 0) return;

   double sl_price = 0, tp_price = 0;
   ENUM_SIGNAL_TYPE signal = SIGNAL_NONE;

   // Try primary strategy
   signal = g_signals[signal_index].GetSignal(InpStrategy, sl_price, tp_price);

   // Try fallback strategy if primary has no signal
   if(signal == SIGNAL_NONE && InpUseFallback && InpStrategy == STRATEGY_SMC)
   {
      signal = g_signals[signal_index].GetSignal(STRATEGY_EMA_CROSS, sl_price, tp_price);
   }

   if(signal == SIGNAL_NONE) return;

   // Validate risk:reward ratio
   double entry_price;
   if(signal == SIGNAL_BUY)
      entry_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   else
      entry_price = SymbolInfoDouble(symbol, SYMBOL_BID);

   double sl_distance = MathAbs(entry_price - sl_price);
   double tp_distance = MathAbs(tp_price - entry_price);

   if(sl_distance <= 0) return;

   double rr_ratio = tp_distance / sl_distance;
   if(rr_ratio < InpMinRR)
   {
      PrintFormat("[FILTER] %s signal rejected: RR=%.1f < %.1f minimum",
                  symbol, rr_ratio, InpMinRR);
      return;
   }

   // Calculate position size
   double sl_distance_points = sl_distance;
   double lot = g_risk.CalculateLotSize(symbol, sl_distance_points);
   if(lot <= 0)
   {
      PrintFormat("[FILTER] %s: Calculated lot size is 0, skipping", symbol);
      return;
   }

   // Execute trade
   ulong ticket = 0;
   string strategy_name = (InpStrategy == STRATEGY_SMC) ? "SMC" : "EMA";

   if(signal == SIGNAL_BUY)
   {
      ticket = g_trade.OpenBuy(symbol, lot, sl_price, tp_price, strategy_name);
   }
   else if(signal == SIGNAL_SELL)
   {
      ticket = g_trade.OpenSell(symbol, lot, sl_price, tp_price, strategy_name);
   }

   if(ticket > 0)
   {
      PrintFormat("[TRADE] %s %s | Lot=%.2f | SL=%.5f | TP=%.5f | RR=%.1f | Ticket=%d",
                  symbol,
                  signal == SIGNAL_BUY ? "BUY" : "SELL",
                  lot, sl_price, tp_price, rr_ratio, ticket);
   }
}

//+------------------------------------------------------------------+
//| Manage open positions (trailing stop, breakeven)                  |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

      // Breakeven management (applied first)
      g_risk.ManageBreakeven(symbol, ticket, pos_type, open_price);

      // Trailing stop management
      g_risk.ManageTrailingStop(symbol, ticket, pos_type);
   }

   // Emergency close if drawdown guards breached
   if(!g_risk.IsDailyDrawdownOK() || !g_risk.IsTotalDrawdownOK())
   {
      Print("[EMERGENCY] Drawdown guard breached! Closing all positions.");
      g_trade.CloseAllPositions();
   }
}

//+------------------------------------------------------------------+
//| Build the list of active trading symbols                          |
//+------------------------------------------------------------------+
void BuildSymbolList()
{
   g_symbol_count = 0;
   ArrayResize(g_symbols, 4);

   if(InpTradeEURUSD && SymbolSelect("EURUSD", true))
   {
      g_symbols[g_symbol_count] = "EURUSD";
      g_symbol_count++;
   }
   if(InpTradeGBPUSD && SymbolSelect("GBPUSD", true))
   {
      g_symbols[g_symbol_count] = "GBPUSD";
      g_symbol_count++;
   }
   if(InpTradeUSDJPY && SymbolSelect("USDJPY", true))
   {
      g_symbols[g_symbol_count] = "USDJPY";
      g_symbol_count++;
   }
   if(InpTradeXAUUSD && SymbolSelect("XAUUSD", true))
   {
      g_symbols[g_symbol_count] = "XAUUSD";
      g_symbol_count++;
   }

   ArrayResize(g_symbols, g_symbol_count);

   string sym_list = "";
   for(int i = 0; i < g_symbol_count; i++)
   {
      if(i > 0) sym_list += ", ";
      sym_list += g_symbols[i];
   }
   PrintFormat("[INIT] Active symbols (%d): %s", g_symbol_count, sym_list);
}
//+------------------------------------------------------------------+
