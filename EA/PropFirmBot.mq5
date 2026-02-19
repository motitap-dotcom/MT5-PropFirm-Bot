//+------------------------------------------------------------------+
//|                                              PropFirmBot.mq5      |
//|                     PROP FIRM CHALLENGE BOT v2.0 - LIVE READY     |
//|                     Guardian + Dashboard + Journal integrated     |
//+------------------------------------------------------------------+
#property copyright   "PropFirmBot"
#property version     "2.00"
#property description "Prop firm challenge bot with full protection system"
#property description "Guardian watchdog | Dashboard | Trade journal"
#property strict

// Include all modules
#include "SignalEngine.mqh"
#include "RiskManager.mqh"
#include "TradeManager.mqh"
#include "Guardian.mqh"
#include "Dashboard.mqh"
#include "TradeJournal.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

// --- General ---
input long     InpMagicNumber     = 202502;    // Magic Number
input string   InpTradeComment    = "PFBot";   // Trade Comment

// --- Challenge Settings ---
input double   InpAccountSize     = 2000;      // Challenge Account Size ($)
input double   InpProfitTarget    = 10.0;      // Profit Target (%)
input double   InpHardDailyDD     = 5.0;       // HARD Daily DD Limit (%) [PROP FIRM]
input double   InpHardTotalDD     = 10.0;      // HARD Total DD Limit (%) [PROP FIRM]
input bool     InpChallengeMode   = true;       // Challenge Mode ON

// --- Strategy ---
input ENUM_STRATEGY_TYPE InpStrategy = STRATEGY_SMC; // Primary Strategy
input bool     InpUseFallback     = true;       // Use EMA fallback
input ENUM_TIMEFRAMES InpEntryTF  = PERIOD_M15; // Entry Timeframe
input ENUM_TIMEFRAMES InpHTF      = PERIOD_H4;  // Higher Timeframe

// --- Signal Parameters ---
input int      InpEMAFast         = 9;          // EMA Fast Period
input int      InpEMASlow         = 21;         // EMA Slow Period
input int      InpRSIPeriod       = 14;         // RSI Period
input int      InpATRPeriod       = 14;         // ATR Period
input int      InpOBLookback      = 20;         // Order Block Lookback
input double   InpFVGMinPoints    = 50.0;       // Min FVG Size (points)

// --- Risk Management ---
input double   InpRiskPercent     = 0.5;        // Risk Per Trade (%)
input double   InpMaxRiskPercent  = 0.75;       // Max Risk Per Trade (%)
input int      InpMaxPositions    = 2;          // Max Open Positions
input double   InpMinRR           = 2.0;        // Min Risk:Reward
input int      InpMaxDailyTrades  = 8;          // Max Trades Per Day
input int      InpMaxConsecLosses = 5;          // Max Consecutive Losses

// --- Spread Filter ---
input double   InpMaxSpreadMajor  = 2.5;        // Max Spread Major (pips)
input double   InpMaxSpreadXAU    = 4.0;        // Max Spread XAUUSD (pips)

// --- Session Filter (UTC) ---
input int      InpLondonStart     = 7;          // London Start
input int      InpLondonEnd       = 11;         // London End
input int      InpNYStart         = 12;         // NY Start
input int      InpNYEnd           = 16;         // NY End

// --- Trade Management ---
input double   InpTrailingActivation = 30.0;    // Trailing Activation (pips)
input double   InpTrailingDistance   = 20.0;     // Trailing Distance (pips)
input double   InpBEActivation      = 20.0;     // Breakeven Activation (pips)
input double   InpBEOffset          = 2.0;       // Breakeven Offset (pips)
input int      InpMinBarGap         = 2;         // Min Bars Between Trades
input int      InpSlippage          = 20;        // Max Slippage (points)

// --- Symbols ---
input bool     InpTradeEURUSD     = true;       // Trade EURUSD
input bool     InpTradeGBPUSD     = true;       // Trade GBPUSD
input bool     InpTradeUSDJPY     = true;       // Trade USDJPY
input bool     InpTradeXAUUSD     = false;      // Trade XAUUSD

// --- Dashboard ---
input bool     InpShowDashboard   = true;       // Show On-Chart Dashboard
input int      InpDashboardX      = 10;         // Dashboard X Position
input int      InpDashboardY      = 30;         // Dashboard Y Position

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS                                                    |
//+------------------------------------------------------------------+
CGuardian      g_guardian;        // MASTER WATCHDOG - highest authority
CDashboard     g_dashboard;       // On-chart monitoring panel
CTradeJournal  g_journal;         // Trade log & audit trail
CSignalEngine  g_signals[];       // Signal engines (one per symbol)
CRiskManager   g_risk;            // Risk calculations
CTradeManager  g_trade;           // Order execution

string         g_symbols[];
int            g_symbol_count = 0;

datetime       g_last_bar_time = 0;
datetime       g_last_dashboard_update = 0;
int            g_dashboard_interval = 2;  // Update dashboard every 2 seconds

// Position tracking for close detection
struct PositionSnapshot
{
   ulong   ticket;
   string  symbol;
   int     type;    // 0=buy, 1=sell
   double  lot;
   double  open_price;
   double  sl;
   double  tp;
};
PositionSnapshot g_prev_positions[];
int              g_prev_pos_count = 0;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==============================================");
   Print("  PropFirmBot v2.0 - LIVE CHALLENGE MODE");
   Print("  GUARDIAN PROTECTION SYSTEM ACTIVE");
   Print("==============================================");

   // Build symbol list
   BuildSymbolList();
   if(g_symbol_count == 0)
   {
      Print("[FATAL] No symbols enabled!");
      return INIT_FAILED;
   }

   // === GUARDIAN: Initialize first - it protects everything ===
   if(!g_guardian.Init(InpAccountSize, InpHardDailyDD, InpHardTotalDD,
                        InpProfitTarget, InpMagicNumber))
   {
      Print("[FATAL] Guardian initialization failed!");
      return INIT_FAILED;
   }

   // === JOURNAL: Start logging immediately ===
   if(!g_journal.Init(InpMagicNumber, AccountInfoDouble(ACCOUNT_BALANCE)))
   {
      Print("[WARNING] Journal init failed - continuing without CSV logging");
   }
   g_journal.LogEvent("STARTUP", StringFormat(
      "Challenge: $%.0f | Target: %.1f%% | DD limits: %.1f%%/%.1f%% | Symbols: %d",
      InpAccountSize, InpProfitTarget, InpHardDailyDD, InpHardTotalDD, g_symbol_count));

   // === RISK MANAGER ===
   g_risk.Init(InpAccountSize, InpRiskPercent, InpMaxRiskPercent,
               InpMaxPositions, InpHardDailyDD - 2.0, InpHardTotalDD - 3.0, InpMagicNumber);
   g_risk.SetSpreadFilter(InpMaxSpreadMajor, InpMaxSpreadXAU);
   g_risk.SetSessionFilter(InpLondonStart, InpLondonEnd, InpNYStart, InpNYEnd);
   g_risk.SetWeekendGuard(5, 20);
   g_risk.SetTrailingStop(InpTrailingActivation, InpTrailingDistance);
   g_risk.SetBreakeven(InpBEActivation, InpBEOffset);
   if(InpChallengeMode)
      g_risk.SetChallengeMode(InpProfitTarget);

   // === TRADE MANAGER ===
   g_trade.Init(InpMagicNumber, InpSlippage, InpTradeComment);
   g_trade.SetMinBarGap(InpMinBarGap);

   // === SIGNAL ENGINES ===
   ArrayResize(g_signals, g_symbol_count);
   for(int i = 0; i < g_symbol_count; i++)
   {
      if(!g_signals[i].Init(g_symbols[i], InpEntryTF, InpHTF,
                             InpEMAFast, InpEMASlow, InpRSIPeriod, InpATRPeriod,
                             InpOBLookback, InpFVGMinPoints))
      {
         PrintFormat("[FATAL] SignalEngine init failed for %s", g_symbols[i]);
         return INIT_FAILED;
      }
   }

   // === DASHBOARD ===
   if(InpShowDashboard)
      g_dashboard.Init(InpDashboardX, InpDashboardY);

   // Take initial position snapshot
   TakePositionSnapshot();

   Print("[INIT] ALL SYSTEMS GO - Guardian active, Dashboard on, Journal logging");
   Print("[INIT] >>> REAL CHALLENGE MODE - EVERY DOLLAR COUNTS <<<");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_journal.LogEvent("SHUTDOWN", StringFormat(
      "Reason=%d | Journal: %s", reason, g_journal.GetSummary()));

   for(int i = 0; i < g_symbol_count; i++)
      g_signals[i].Deinit();

   g_journal.Deinit();

   if(InpShowDashboard)
      g_dashboard.Destroy();

   Comment("");
   PrintFormat("[DEINIT] PropFirmBot stopped. Reason: %d", reason);
}

//+------------------------------------------------------------------+
//| MAIN TICK HANDLER                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   // ============================================
   // STEP 1: GUARDIAN CHECK (every single tick!)
   // ============================================
   ENUM_GUARDIAN_STATE state = g_guardian.RunChecks();

   // Emergency: force close everything
   if(g_guardian.MustCloseAll())
   {
      if(g_trade.CountOpenPositions() > 0)
      {
         g_journal.LogEvent("EMERGENCY", g_guardian.GetHaltMessage());
         g_trade.CloseAllPositions();
      }
   }

   // Shutdown: stop everything permanently
   if(g_guardian.IsDead())
   {
      UpdateDashboard();
      return;
   }

   // ============================================
   // STEP 2: DETECT CLOSED TRADES (every tick)
   // ============================================
   DetectClosedTrades();

   // ============================================
   // STEP 3: MANAGE OPEN POSITIONS (every tick)
   // ============================================
   ManageOpenPositions();

   // ============================================
   // STEP 4: DASHBOARD UPDATE (every few seconds)
   // ============================================
   UpdateDashboard();

   // ============================================
   // STEP 5: NEW BAR LOGIC (signal scanning)
   // ============================================
   datetime current_bar = iTime(_Symbol, InpEntryTF, 0);
   if(current_bar == g_last_bar_time)
      return;  // Same bar - no new signal scan
   g_last_bar_time = current_bar;

   // Only scan for signals if Guardian says we can trade
   if(!g_guardian.CanTrade())
      return;

   // CAUTION mode: reduce risk (halve lot size)
   bool caution_mode = g_guardian.IsCaution();

   // Scan symbols for signals
   for(int i = 0; i < g_symbol_count; i++)
   {
      ProcessSymbol(g_symbols[i], i, caution_mode);
   }
}

//+------------------------------------------------------------------+
//| Process signals for one symbol                                    |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol, int signal_index, bool caution_mode)
{
   // Pre-flight checks
   if(!g_risk.CanOpenTrade(symbol)) return;
   if(!g_trade.CanTradeNow(symbol)) return;
   if(g_trade.CountSymbolPositions(symbol) > 0) return;

   // Spread anomaly check
   if(!g_guardian.CheckSpreadAnomaly(symbol))
   {
      PrintFormat("[GUARDIAN] %s spread anomaly - skipping", symbol);
      return;
   }

   double sl_price = 0, tp_price = 0;
   ENUM_SIGNAL_TYPE signal = SIGNAL_NONE;

   // Primary strategy
   signal = g_signals[signal_index].GetSignal(InpStrategy, sl_price, tp_price);

   // Fallback
   if(signal == SIGNAL_NONE && InpUseFallback && InpStrategy == STRATEGY_SMC)
      signal = g_signals[signal_index].GetSignal(STRATEGY_EMA_CROSS, sl_price, tp_price);

   if(signal == SIGNAL_NONE) return;

   // Validate RR
   double entry_price = (signal == SIGNAL_BUY)
                        ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(symbol, SYMBOL_BID);

   double sl_dist = MathAbs(entry_price - sl_price);
   double tp_dist = MathAbs(tp_price - entry_price);
   if(sl_dist <= 0) return;

   double rr = tp_dist / sl_dist;
   if(rr < InpMinRR)
   {
      PrintFormat("[FILTER] %s RR=%.1f < %.1f", symbol, rr, InpMinRR);
      return;
   }

   // Calculate lot size
   double lot = g_risk.CalculateLotSize(symbol, sl_dist);
   if(lot <= 0) return;

   // CAUTION MODE: halve the lot size
   if(caution_mode)
   {
      lot = lot * 0.5;
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(lot_step > 0)
         lot = MathFloor(lot / lot_step) * lot_step;
      if(lot < min_lot) lot = min_lot;
   }

   // Execute
   string strategy_name = (InpStrategy == STRATEGY_SMC) ? "SMC" : "EMA";
   ulong ticket = 0;

   if(signal == SIGNAL_BUY)
      ticket = g_trade.OpenBuy(symbol, lot, sl_price, tp_price, strategy_name);
   else
      ticket = g_trade.OpenSell(symbol, lot, sl_price, tp_price, strategy_name);

   if(ticket > 0)
   {
      // Notify Guardian
      g_guardian.OnTradeOpened();

      // Log to Journal
      g_journal.LogTradeOpen(symbol,
         signal == SIGNAL_BUY ? "BUY" : "SELL",
         lot, entry_price, sl_price, tp_price,
         ticket, strategy_name,
         caution_mode ? "CAUTION_MODE" : "NORMAL");

      // Update position snapshot
      TakePositionSnapshot();

      PrintFormat("[TRADE] %s %s | Lot=%.2f | SL=%.5f | TP=%.5f | RR=%.1f | #%d%s",
                  symbol, signal == SIGNAL_BUY ? "BUY" : "SELL",
                  lot, sl_price, tp_price, rr, ticket,
                  caution_mode ? " [CAUTION]" : "");
   }
}

//+------------------------------------------------------------------+
//| Manage open positions: breakeven + trailing                       |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

      g_risk.ManageBreakeven(symbol, ticket, pt, open_price);
      g_risk.ManageTrailingStop(symbol, ticket, pt);
   }
}

//+------------------------------------------------------------------+
//| Detect trades that closed since last check                        |
//+------------------------------------------------------------------+
void DetectClosedTrades()
{
   // Compare current positions to previous snapshot
   for(int p = 0; p < g_prev_pos_count; p++)
   {
      bool still_open = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == g_prev_positions[p].ticket)
         {
            still_open = true;
            break;
         }
      }

      if(!still_open)
      {
         // This position was closed - find it in history
         ulong closed_ticket = g_prev_positions[p].ticket;
         string symbol = g_prev_positions[p].symbol;
         string direction = g_prev_positions[p].type == 0 ? "BUY" : "SELL";
         double open_price = g_prev_positions[p].open_price;
         double lot = g_prev_positions[p].lot;
         double sl = g_prev_positions[p].sl;
         double tp = g_prev_positions[p].tp;

         // Try to get actual close info from deal history
         double close_price = 0;
         double pnl = 0;
         string exit_reason = "Unknown";

         // Look in recent deals
         HistorySelect(TimeCurrent() - 300, TimeCurrent()); // Last 5 minutes
         int deals = HistoryDealsTotal();
         for(int d = deals - 1; d >= 0; d--)
         {
            ulong deal_ticket = HistoryDealGetTicket(d);
            if(HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) == (long)closed_ticket ||
               HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == InpMagicNumber)
            {
               long deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
               // Closing deals: DEAL_TYPE_BUY closes SELL, DEAL_TYPE_SELL closes BUY
               if((g_prev_positions[p].type == 0 && deal_type == DEAL_TYPE_SELL) ||
                  (g_prev_positions[p].type == 1 && deal_type == DEAL_TYPE_BUY))
               {
                  close_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
                  pnl = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT)
                      + HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
                      + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

                  long deal_reason = HistoryDealGetInteger(deal_ticket, DEAL_REASON);
                  switch((int)deal_reason)
                  {
                     case DEAL_REASON_SL:      exit_reason = "SL"; break;
                     case DEAL_REASON_TP:      exit_reason = "TP"; break;
                     case DEAL_REASON_EXPERT:  exit_reason = "EA"; break;
                     default:                  exit_reason = "Market"; break;
                  }
                  break;
               }
            }
         }

         // If we couldn't get close_price, estimate
         if(close_price == 0)
         {
            if(g_prev_positions[p].type == 0)
               close_price = SymbolInfoDouble(symbol, SYMBOL_BID);
            else
               close_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         }

         // Calculate pip PnL
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         double pip_size = (digits == 3 || digits == 5)
                           ? SymbolInfoDouble(symbol, SYMBOL_POINT) * 10
                           : SymbolInfoDouble(symbol, SYMBOL_POINT);
         double pnl_pips = 0;
         if(pip_size > 0)
         {
            if(g_prev_positions[p].type == 0)
               pnl_pips = (close_price - open_price) / pip_size;
            else
               pnl_pips = (open_price - close_price) / pip_size;
         }

         // Notify Guardian
         g_guardian.OnTradeClosed(pnl);

         // Log to Journal
         g_journal.LogTradeClose(symbol, direction, lot,
            open_price, close_price, sl, tp,
            pnl, pnl_pips, closed_ticket,
            exit_reason, AccountInfoDouble(ACCOUNT_BALANCE));

         PrintFormat("[CLOSED] #%d %s %s | PnL=$%.2f (%.1f pips) | %s",
                     closed_ticket, direction, symbol, pnl, pnl_pips, exit_reason);
      }
   }

   // Update snapshot
   TakePositionSnapshot();
}

//+------------------------------------------------------------------+
//| Take snapshot of current positions for close detection            |
//+------------------------------------------------------------------+
void TakePositionSnapshot()
{
   g_prev_pos_count = 0;
   int total = PositionsTotal();
   ArrayResize(g_prev_positions, total);

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      g_prev_positions[g_prev_pos_count].ticket     = ticket;
      g_prev_positions[g_prev_pos_count].symbol      = PositionGetString(POSITION_SYMBOL);
      g_prev_positions[g_prev_pos_count].type        = (int)PositionGetInteger(POSITION_TYPE);
      g_prev_positions[g_prev_pos_count].lot         = PositionGetDouble(POSITION_VOLUME);
      g_prev_positions[g_prev_pos_count].open_price  = PositionGetDouble(POSITION_PRICE_OPEN);
      g_prev_positions[g_prev_pos_count].sl          = PositionGetDouble(POSITION_SL);
      g_prev_positions[g_prev_pos_count].tp          = PositionGetDouble(POSITION_TP);
      g_prev_pos_count++;
   }
   ArrayResize(g_prev_positions, g_prev_pos_count);
}

//+------------------------------------------------------------------+
//| Update dashboard display                                          |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard) return;

   // Throttle updates
   if(TimeCurrent() - g_last_dashboard_update < g_dashboard_interval) return;
   g_last_dashboard_update = TimeCurrent();

   int open_pos = g_trade.CountOpenPositions();
   double floating = g_trade.GetTotalProfit();

   g_dashboard.Update(g_guardian, open_pos, floating);
}

//+------------------------------------------------------------------+
//| Build active symbol list                                          |
//+------------------------------------------------------------------+
void BuildSymbolList()
{
   g_symbol_count = 0;
   ArrayResize(g_symbols, 4);

   if(InpTradeEURUSD && SymbolSelect("EURUSD", true))
   { g_symbols[g_symbol_count] = "EURUSD"; g_symbol_count++; }
   if(InpTradeGBPUSD && SymbolSelect("GBPUSD", true))
   { g_symbols[g_symbol_count] = "GBPUSD"; g_symbol_count++; }
   if(InpTradeUSDJPY && SymbolSelect("USDJPY", true))
   { g_symbols[g_symbol_count] = "USDJPY"; g_symbol_count++; }
   if(InpTradeXAUUSD && SymbolSelect("XAUUSD", true))
   { g_symbols[g_symbol_count] = "XAUUSD"; g_symbol_count++; }

   ArrayResize(g_symbols, g_symbol_count);

   string sym_list = "";
   for(int i = 0; i < g_symbol_count; i++)
   {
      if(i > 0) sym_list += ", ";
      sym_list += g_symbols[i];
   }
   PrintFormat("[INIT] Symbols (%d): %s", g_symbol_count, sym_list);
}

//+------------------------------------------------------------------+
//| OnTrade - detect broker-side trade events                         |
//+------------------------------------------------------------------+
void OnTrade()
{
   // This runs when any trade event happens (open, close, modify)
   // We use it as a backup for DetectClosedTrades
   DetectClosedTrades();
}
//+------------------------------------------------------------------+
