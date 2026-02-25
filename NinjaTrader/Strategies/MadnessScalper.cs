#region Using declarations
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Cbi;
using NinjaTrader.Gui;
using NinjaTrader.Gui.Chart;
using NinjaTrader.Gui.SuperDom;
using NinjaTrader.Gui.Tools;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript;
using NinjaTrader.Core.FloatingPoint;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Strategies
{
    /// <summary>
    /// MadnessScalper - Fast scalping strategy for NinjaTrader Arena competition.
    /// Designed for quick entries/exits on 1-minute and 2-minute bars.
    /// Trades ES, NQ, CL with tight stops and quick profit taking.
    /// Use this alongside MarchMadnessBot on different charts for maximum exposure.
    /// </summary>
    public class MadnessScalper : Strategy
    {
        #region Variables

        // Indicators - 2min primary
        private EMA emaFast;
        private EMA emaSlow;
        private RSI rsi;
        private ATR atr;
        private MACD macd;
        private EMA vwmaProxy; // Proxy for volume-weighted direction

        // Indicators - 5min confirmation
        private EMA emaFast5;
        private EMA emaSlow5;
        private RSI rsi5;

        // State
        private int consecutiveLosses = 0;
        private int winsToday = 0;
        private int lossesToday = 0;
        private double dailyPnL = 0;
        private DateTime lastEntryTime = DateTime.MinValue;
        private double sessionOpen = 0;
        private bool sessionOpenRecorded = false;

        // Scalp tracking
        private double entryPrice = 0;
        private int barsSinceEntry = 0;

        // Bar indices:
        // 0 = Primary instrument (2min - applied chart)
        // 1 = Same instrument 5min confirmation

        #endregion

        #region OnStateChange

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = "MadnessScalper - Fast scalping for NinjaTrader Arena competition. Apply to ES, NQ, or CL chart.";
                Name = "MadnessScalper";
                Calculate = Calculate.OnBarClose;
                EntriesPerDirection = 1;
                EntryHandling = EntryHandling.AllEntries;
                IsExitOnSessionCloseStrategy = true;
                ExitOnSessionCloseSeconds = 120;
                IsFillLimitOnTouch = false;
                MaximumBarsLookBack = MaximumBarsLookBack.TwoHundredFiftySix;
                OrderFillResolution = OrderFillResolution.Standard;
                Slippage = 1;
                StartBehavior = StartBehavior.WaitUntilFlat;
                TimeInForce = TimeInForce.Gtc;
                TraceOrders = false;
                RealtimeErrorHandling = RealtimeErrorHandling.StopCancelClose;
                StopTargetHandling = StopTargetHandling.PerEntryExecution;
                BarsRequiredToTrade = 20;
                IsInstantiatedOnEachOptimizationIteration = true;

                // Scalper parameters
                FastPeriod = 8;
                SlowPeriod = 21;
                RSIPeriod = 10;
                ATRPeriod = 10;
                Contracts = 2;

                // Tight scalp targets
                StopTicks = 12;
                TargetTicks = 20;
                UseATRStops = true;
                ATRStopMult = 1.2;
                ATRTargetMult = 2.0;
                BreakevenTicks = 8;

                // Filters
                MinATR = 0.3;
                RSIUpperBand = 70;
                RSILowerBand = 30;
                MaxBarsInTrade = 15;
                CooldownBars = 3;

                // Session
                SessionStartHour = 8;
                SessionStartMinute = 35;
                SessionEndHour = 15;
                SessionEndMinute = 30;
                MaxLossesPerDay = 5;
                MaxDailyLoss = 1500;

                // Momentum
                RequireMACDConfirm = true;
                RequireHigherTFConfirm = true;
            }
            else if (State == State.Configure)
            {
                // Add 5-minute confirmation timeframe
                AddDataSeries(Data.BarsPeriodType.Minute, 5); // Index 1
            }
            else if (State == State.DataLoaded)
            {
                // Primary 2min indicators
                emaFast = EMA(BarsArray[0], FastPeriod);
                emaSlow = EMA(BarsArray[0], SlowPeriod);
                rsi = RSI(BarsArray[0], RSIPeriod, 3);
                atr = ATR(BarsArray[0], ATRPeriod);
                macd = MACD(BarsArray[0], 12, 26, 9);

                // 5min confirmation
                emaFast5 = EMA(BarsArray[1], FastPeriod);
                emaSlow5 = EMA(BarsArray[1], SlowPeriod);
                rsi5 = RSI(BarsArray[1], RSIPeriod, 3);

                AddChartIndicator(emaFast);
                AddChartIndicator(emaSlow);
            }
        }

        #endregion

        #region OnBarUpdate

        protected override void OnBarUpdate()
        {
            // Ensure enough bars on all series
            for (int i = 0; i < BarsArray.Length; i++)
            {
                if (CurrentBars[i] < BarsRequiredToTrade)
                    return;
            }

            // Only process primary bars (2min)
            if (BarsInProgress != 0) return;

            // Record session open
            if (Bars.IsFirstBarOfSession && !sessionOpenRecorded)
            {
                sessionOpen = Close[0];
                sessionOpenRecorded = true;
                winsToday = 0;
                lossesToday = 0;
                dailyPnL = 0;
                consecutiveLosses = 0;
            }
            if (!Bars.IsFirstBarOfSession)
                sessionOpenRecorded = false;

            // Daily loss limit
            if (lossesToday >= MaxLossesPerDay || dailyPnL <= -MaxDailyLoss)
                return;

            // Time filter
            if (!IsInSession()) return;

            // Track bars since entry
            if (Position.MarketPosition != MarketPosition.Flat)
            {
                barsSinceEntry++;
                ManageScalp();
                return; // Don't enter new trades while in position
            }

            // Cooldown check
            if (lastEntryTime != DateTime.MinValue &&
                (Time[0] - lastEntryTime).TotalMinutes < CooldownBars * 2)
                return;

            // Volatility filter
            double currentATR = atr[0];
            if (currentATR < MinATR) return;

            // === ENTRY LOGIC ===
            bool longSignal = GetLongSignal(currentATR);
            bool shortSignal = GetShortSignal(currentATR);

            if (longSignal)
            {
                double stop, target;
                CalculateStopTarget(true, currentATR, out stop, out target);

                SetStopLoss("ScalpLong", CalculationMode.Ticks, stop);
                SetProfitTarget("ScalpLong", CalculationMode.Ticks, target);

                EnterLong(Contracts, "ScalpLong");
                entryPrice = Close[0];
                barsSinceEntry = 0;
                lastEntryTime = Time[0];
            }
            else if (shortSignal)
            {
                double stop, target;
                CalculateStopTarget(false, currentATR, out stop, out target);

                SetStopLoss("ScalpShort", CalculationMode.Ticks, stop);
                SetProfitTarget("ScalpShort", CalculationMode.Ticks, target);

                EnterShort(Contracts, "ScalpShort");
                entryPrice = Close[0];
                barsSinceEntry = 0;
                lastEntryTime = Time[0];
            }
        }

        #endregion

        #region Signal Logic

        private bool GetLongSignal(double currentATR)
        {
            // 1. Price above fast EMA (momentum)
            if (Close[0] <= emaFast[0]) return false;

            // 2. Fast EMA above Slow EMA (trend)
            if (emaFast[0] <= emaSlow[0]) return false;

            // 3. Fast EMA rising
            if (emaFast[0] <= emaFast[1]) return false;

            // 4. RSI in bullish zone but not overbought
            if (rsi[0] <= 50 || rsi[0] >= RSIUpperBand) return false;

            // 5. MACD confirmation
            if (RequireMACDConfirm)
            {
                if (macd[0] <= macd.Avg[0]) return false;
                // MACD histogram should be rising
                double hist = macd[0] - macd.Avg[0];
                double histPrev = macd[1] - macd.Avg[1];
                if (hist <= histPrev) return false;
            }

            // 6. Higher timeframe confirmation
            if (RequireHigherTFConfirm)
            {
                if (emaFast5[0] <= emaSlow5[0]) return false;
                if (rsi5[0] <= 45) return false;
            }

            // 7. Pullback entry: price touched EMA fast and bounced
            bool pullback = Low[0] <= emaFast[0] * 1.001 && Close[0] > emaFast[0];
            bool momentum = Close[0] > Close[1] && Close[1] > Close[2]; // 3 rising closes

            return pullback || momentum;
        }

        private bool GetShortSignal(double currentATR)
        {
            // Mirror of long logic
            if (Close[0] >= emaFast[0]) return false;
            if (emaFast[0] >= emaSlow[0]) return false;
            if (emaFast[0] >= emaFast[1]) return false;
            if (rsi[0] >= 50 || rsi[0] <= RSILowerBand) return false;

            if (RequireMACDConfirm)
            {
                if (macd[0] >= macd.Avg[0]) return false;
                double hist = macd[0] - macd.Avg[0];
                double histPrev = macd[1] - macd.Avg[1];
                if (hist >= histPrev) return false;
            }

            if (RequireHigherTFConfirm)
            {
                if (emaFast5[0] >= emaSlow5[0]) return false;
                if (rsi5[0] >= 55) return false;
            }

            bool pullback = High[0] >= emaFast[0] * 0.999 && Close[0] < emaFast[0];
            bool momentum = Close[0] < Close[1] && Close[1] < Close[2];

            return pullback || momentum;
        }

        #endregion

        #region Stop/Target Calculation

        private void CalculateStopTarget(bool isLong, double currentATR, out double stopTicks, out double targetTicks)
        {
            if (UseATRStops)
            {
                stopTicks = Math.Max(StopTicks, (currentATR * ATRStopMult) / TickSize);
                targetTicks = Math.Max(TargetTicks, (currentATR * ATRTargetMult) / TickSize);
            }
            else
            {
                stopTicks = StopTicks;
                targetTicks = TargetTicks;
            }
        }

        #endregion

        #region Trade Management

        private void ManageScalp()
        {
            double currentATR = atr[0];
            double unrealizedTicks = 0;

            if (Position.MarketPosition == MarketPosition.Long)
                unrealizedTicks = (Close[0] - Position.AveragePrice) / TickSize;
            else if (Position.MarketPosition == MarketPosition.Short)
                unrealizedTicks = (Position.AveragePrice - Close[0]) / TickSize;

            // Breakeven stop after minimum profit
            if (unrealizedTicks >= BreakevenTicks)
            {
                if (Position.MarketPosition == MarketPosition.Long)
                    SetStopLoss("ScalpLong", CalculationMode.Price, Position.AveragePrice + TickSize);
                else if (Position.MarketPosition == MarketPosition.Short)
                    SetStopLoss("ScalpShort", CalculationMode.Price, Position.AveragePrice - TickSize);
            }

            // Time-based exit: if trade hasn't moved after MaxBarsInTrade bars, exit
            if (barsSinceEntry >= MaxBarsInTrade)
            {
                if (Position.MarketPosition == MarketPosition.Long)
                    ExitLong("TimeExit", "ScalpLong");
                else if (Position.MarketPosition == MarketPosition.Short)
                    ExitShort("TimeExit", "ScalpShort");
            }

            // Exit on momentum reversal
            if (Position.MarketPosition == MarketPosition.Long)
            {
                // EMA fast crossed below slow while in long
                if (emaFast[0] < emaSlow[0] && unrealizedTicks > 0)
                    ExitLong("TrendExit", "ScalpLong");
            }
            else if (Position.MarketPosition == MarketPosition.Short)
            {
                if (emaFast[0] > emaSlow[0] && unrealizedTicks > 0)
                    ExitShort("TrendExit", "ScalpShort");
            }
        }

        #endregion

        #region Position Updates

        protected override void OnPositionUpdate(Position position, double averagePrice,
            int quantity, MarketPosition marketPosition)
        {
            if (marketPosition == MarketPosition.Flat && position.Quantity > 0)
            {
                double pnl = position.GetUnrealizedProfitLoss(PerformanceUnit.Currency);
                dailyPnL += pnl;

                if (pnl >= 0)
                {
                    winsToday++;
                    consecutiveLosses = 0;
                }
                else
                {
                    lossesToday++;
                    consecutiveLosses++;
                }

                Print(string.Format("[MadnessScalper] Trade closed | PnL: ${0:F2} | Daily: ${1:F2} | W/L: {2}/{3}",
                    pnl, dailyPnL, winsToday, lossesToday));
            }
        }

        protected override void OnExecutionUpdate(Execution execution, string executionId, double price,
            int quantity, MarketPosition marketPosition, string orderId, DateTime time)
        {
            if (execution.Order.OrderState == OrderState.Filled)
            {
                Print(string.Format("[MadnessScalper] {0} | {1} @ {2} | Qty: {3}",
                    time, execution.Order.Name, price, quantity));
            }
        }

        #endregion

        #region Utility

        private bool IsInSession()
        {
            int timeVal = Time[0].Hour * 100 + Time[0].Minute;
            int start = SessionStartHour * 100 + SessionStartMinute;
            int end = SessionEndHour * 100 + SessionEndMinute;
            return timeVal >= start && timeVal <= end;
        }

        #endregion

        #region Properties

        [NinjaScriptProperty]
        [Range(2, 50)]
        [Display(Name = "Fast EMA Period", Order = 1, GroupName = "Indicators")]
        public int FastPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(5, 100)]
        [Display(Name = "Slow EMA Period", Order = 2, GroupName = "Indicators")]
        public int SlowPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(2, 30)]
        [Display(Name = "RSI Period", Order = 3, GroupName = "Indicators")]
        public int RSIPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(2, 30)]
        [Display(Name = "ATR Period", Order = 4, GroupName = "Indicators")]
        public int ATRPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(1, 10)]
        [Display(Name = "Contracts", Order = 1, GroupName = "Position")]
        public int Contracts { get; set; }

        [NinjaScriptProperty]
        [Range(4, 100)]
        [Display(Name = "Stop Loss (Ticks)", Order = 1, GroupName = "Risk")]
        public int StopTicks { get; set; }

        [NinjaScriptProperty]
        [Range(4, 200)]
        [Display(Name = "Profit Target (Ticks)", Order = 2, GroupName = "Risk")]
        public int TargetTicks { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Use ATR-Based Stops", Order = 3, GroupName = "Risk")]
        public bool UseATRStops { get; set; }

        [NinjaScriptProperty]
        [Range(0.5, 5.0)]
        [Display(Name = "ATR Stop Multiplier", Order = 4, GroupName = "Risk")]
        public double ATRStopMult { get; set; }

        [NinjaScriptProperty]
        [Range(1.0, 10.0)]
        [Display(Name = "ATR Target Multiplier", Order = 5, GroupName = "Risk")]
        public double ATRTargetMult { get; set; }

        [NinjaScriptProperty]
        [Range(2, 50)]
        [Display(Name = "Breakeven Ticks", Order = 6, GroupName = "Risk")]
        public int BreakevenTicks { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 10.0)]
        [Display(Name = "Min ATR", Order = 1, GroupName = "Filters")]
        public double MinATR { get; set; }

        [NinjaScriptProperty]
        [Range(60, 90)]
        [Display(Name = "RSI Overbought", Order = 2, GroupName = "Filters")]
        public int RSIUpperBand { get; set; }

        [NinjaScriptProperty]
        [Range(10, 40)]
        [Display(Name = "RSI Oversold", Order = 3, GroupName = "Filters")]
        public int RSILowerBand { get; set; }

        [NinjaScriptProperty]
        [Range(3, 60)]
        [Display(Name = "Max Bars In Trade", Order = 4, GroupName = "Filters")]
        public int MaxBarsInTrade { get; set; }

        [NinjaScriptProperty]
        [Range(1, 20)]
        [Display(Name = "Cooldown Bars", Order = 5, GroupName = "Filters")]
        public int CooldownBars { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Require MACD Confirm", Order = 1, GroupName = "Confirmation")]
        public bool RequireMACDConfirm { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Require Higher TF Confirm", Order = 2, GroupName = "Confirmation")]
        public bool RequireHigherTFConfirm { get; set; }

        [NinjaScriptProperty]
        [Range(0, 23)]
        [Display(Name = "Session Start Hour", Order = 1, GroupName = "Session")]
        public int SessionStartHour { get; set; }

        [NinjaScriptProperty]
        [Range(0, 59)]
        [Display(Name = "Session Start Minute", Order = 2, GroupName = "Session")]
        public int SessionStartMinute { get; set; }

        [NinjaScriptProperty]
        [Range(0, 23)]
        [Display(Name = "Session End Hour", Order = 3, GroupName = "Session")]
        public int SessionEndHour { get; set; }

        [NinjaScriptProperty]
        [Range(0, 59)]
        [Display(Name = "Session End Minute", Order = 4, GroupName = "Session")]
        public int SessionEndMinute { get; set; }

        [NinjaScriptProperty]
        [Range(1, 20)]
        [Display(Name = "Max Losses Per Day", Order = 5, GroupName = "Session")]
        public int MaxLossesPerDay { get; set; }

        [NinjaScriptProperty]
        [Range(100, 25000)]
        [Display(Name = "Max Daily Loss ($)", Order = 6, GroupName = "Session")]
        public double MaxDailyLoss { get; set; }

        #endregion
    }
}
