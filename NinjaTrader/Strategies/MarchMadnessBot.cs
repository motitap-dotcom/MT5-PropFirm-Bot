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
    /// MarchMadnessBot - Aggressive momentum strategy for NinjaTrader Arena competition.
    /// Trades ES, NQ, CL futures with multi-timeframe confirmation.
    /// Designed for maximum PnL in a 4-day simulated competition.
    /// </summary>
    public class MarchMadnessBot : Strategy
    {
        #region Variables

        // ===== Indicators - Primary (5min) =====
        private EMA emaFastES, emaSlowES;
        private EMA emaFastNQ, emaSlowNQ;
        private EMA emaFastCL, emaSlowCL;

        private RSI rsiES, rsiNQ, rsiCL;
        private MACD macdES, macdNQ, macdCL;
        private ATR atrES, atrNQ, atrCL;
        private VOL volES, volNQ, volCL;

        // ===== Indicators - Confirmation (15min) =====
        private EMA emaFastES_15, emaSlowES_15;
        private EMA emaFastNQ_15, emaSlowNQ_15;
        private EMA emaFastCL_15, emaSlowCL_15;
        private RSI rsiES_15, rsiNQ_15, rsiCL_15;

        // ===== State tracking =====
        private double esHighWater = 0;
        private double nqHighWater = 0;
        private double clHighWater = 0;

        private int esConsecutiveLosses = 0;
        private int nqConsecutiveLosses = 0;
        private int clConsecutiveLosses = 0;

        private double sessionStartEquity = 0;
        private double peakEquity = 0;
        private int totalTradesToday = 0;

        private DateTime lastTradeTimeES = DateTime.MinValue;
        private DateTime lastTradeTimeNQ = DateTime.MinValue;
        private DateTime lastTradeTimeCL = DateTime.MinValue;

        // ===== Bar indices for multi-instrument =====
        // 0 = ES 5min (primary)
        // 1 = NQ 5min
        // 2 = CL 5min
        // 3 = ES 15min
        // 4 = NQ 15min
        // 5 = CL 15min

        #endregion

        #region OnStateChange

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = "MarchMadnessBot - Aggressive momentum strategy for NinjaTrader Arena $20K March Market Madness competition";
                Name = "MarchMadnessBot";
                Calculate = Calculate.OnBarClose;
                EntriesPerDirection = 1;
                EntryHandling = EntryHandling.AllEntries;
                IsExitOnSessionCloseStrategy = true;
                ExitOnSessionCloseSeconds = 60;
                IsFillLimitOnTouch = false;
                MaximumBarsLookBack = MaximumBarsLookBack.TwoHundredFiftySix;
                OrderFillResolution = OrderFillResolution.Standard;
                Slippage = 2;
                StartBehavior = StartBehavior.WaitUntilFlat;
                TimeInForce = TimeInForce.Gtc;
                TraceOrders = false;
                RealtimeErrorHandling = RealtimeErrorHandling.StopCancelClose;
                StopTargetHandling = StopTargetHandling.PerEntryExecution;
                BarsRequiredToTrade = 20;
                IsInstantiatedOnEachOptimizationIteration = true;

                // === User Parameters ===
                FastEMAPeriod = 9;
                SlowEMAPeriod = 21;
                RSIPeriod = 14;
                ATRPeriod = 14;
                MACDFast = 12;
                MACDSlow = 26;
                MACDSmooth = 9;

                // Competition mode - aggressive
                MaxContractsPerInstrument = 2;
                ATRStopMultiplier = 1.8;
                ATRTargetMultiplier = 3.5;
                UseTrailingStop = true;
                TrailingATRMultiplier = 1.5;

                // RSI thresholds
                RSILongThreshold = 45;
                RSIShortThreshold = 55;
                RSIOverbought = 80;
                RSIOversold = 20;

                // Filters
                MinATRFilter = 0.5;
                VolumeMultiplier = 1.2;
                MaxConsecutiveLosses = 3;
                SessionDrawdownLimit = 2500;
                CooldownMinutes = 10;
                EnableMorningSession = true;
                EnableAfternoonSession = true;
                MorningStartHour = 8;
                MorningStartMinute = 35;
                MorningEndHour = 11;
                MorningEndMinute = 30;
                AfternoonStartHour = 13;
                AfternoonStartMinute = 0;
                AfternoonEndHour = 15;
                AfternoonEndMinute = 45;

                // Breakout
                BreakoutLookback = 10;
                BreakoutATRMultiplier = 0.5;

                // Momentum scoring
                EnableMomentumScoring = true;
                MinMomentumScore = 3;
            }
            else if (State == State.Configure)
            {
                // Add secondary instruments - 5min bars
                AddDataSeries("NQ 03-26", Data.BarsPeriodType.Minute, 5);   // Index 1
                AddDataSeries("CL 04-26", Data.BarsPeriodType.Minute, 5);   // Index 2

                // Add 15-minute confirmation bars
                AddDataSeries("ES 03-26", Data.BarsPeriodType.Minute, 15);  // Index 3
                AddDataSeries("NQ 03-26", Data.BarsPeriodType.Minute, 15);  // Index 4
                AddDataSeries("CL 04-26", Data.BarsPeriodType.Minute, 15);  // Index 5
            }
            else if (State == State.DataLoaded)
            {
                // === ES indicators (primary, BarsInProgress 0) ===
                emaFastES = EMA(BarsArray[0], FastEMAPeriod);
                emaSlowES = EMA(BarsArray[0], SlowEMAPeriod);
                rsiES = RSI(BarsArray[0], RSIPeriod, 3);
                macdES = MACD(BarsArray[0], MACDFast, MACDSlow, MACDSmooth);
                atrES = ATR(BarsArray[0], ATRPeriod);
                volES = VOL(BarsArray[0]);

                // === NQ indicators (BarsInProgress 1) ===
                emaFastNQ = EMA(BarsArray[1], FastEMAPeriod);
                emaSlowNQ = EMA(BarsArray[1], SlowEMAPeriod);
                rsiNQ = RSI(BarsArray[1], RSIPeriod, 3);
                macdNQ = MACD(BarsArray[1], MACDFast, MACDSlow, MACDSmooth);
                atrNQ = ATR(BarsArray[1], ATRPeriod);
                volNQ = VOL(BarsArray[1]);

                // === CL indicators (BarsInProgress 2) ===
                emaFastCL = EMA(BarsArray[2], FastEMAPeriod);
                emaSlowCL = EMA(BarsArray[2], SlowEMAPeriod);
                rsiCL = RSI(BarsArray[2], RSIPeriod, 3);
                macdCL = MACD(BarsArray[2], MACDFast, MACDSlow, MACDSmooth);
                atrCL = ATR(BarsArray[2], ATRPeriod);
                volCL = VOL(BarsArray[2]);

                // === 15min confirmation indicators ===
                emaFastES_15 = EMA(BarsArray[3], FastEMAPeriod);
                emaSlowES_15 = EMA(BarsArray[3], SlowEMAPeriod);
                rsiES_15 = RSI(BarsArray[3], RSIPeriod, 3);

                emaFastNQ_15 = EMA(BarsArray[4], FastEMAPeriod);
                emaSlowNQ_15 = EMA(BarsArray[4], SlowEMAPeriod);
                rsiNQ_15 = RSI(BarsArray[4], RSIPeriod, 3);

                emaFastCL_15 = EMA(BarsArray[5], FastEMAPeriod);
                emaSlowCL_15 = EMA(BarsArray[5], SlowEMAPeriod);
                rsiCL_15 = RSI(BarsArray[5], RSIPeriod, 3);

                // Add indicators to chart for visual reference
                AddChartIndicator(emaFastES);
                AddChartIndicator(emaSlowES);
                AddChartIndicator(rsiES);
                AddChartIndicator(macdES);
            }
        }

        #endregion

        #region OnBarUpdate

        protected override void OnBarUpdate()
        {
            // Ensure we have enough bars for all series
            for (int i = 0; i < BarsArray.Length; i++)
            {
                if (CurrentBars[i] < BarsRequiredToTrade)
                    return;
            }

            // Track session equity
            if (sessionStartEquity == 0)
                sessionStartEquity = Account.Get(AccountItem.CashValue, Currency.UsDollar);

            double currentEquity = Account.Get(AccountItem.CashValue, Currency.UsDollar);
            if (currentEquity > peakEquity)
                peakEquity = currentEquity;

            // Session drawdown protection
            if (sessionStartEquity - currentEquity > SessionDrawdownLimit)
            {
                // Hit daily drawdown limit - close all and stop
                if (BarsInProgress == 0) FlattenAll();
                return;
            }

            // Reset counters on new session
            if (BarsInProgress == 0 && Bars.IsFirstBarOfSession)
            {
                sessionStartEquity = currentEquity;
                peakEquity = currentEquity;
                totalTradesToday = 0;
                esConsecutiveLosses = 0;
                nqConsecutiveLosses = 0;
                clConsecutiveLosses = 0;
            }

            // Process each instrument on its 5-min bar
            switch (BarsInProgress)
            {
                case 0: // ES 5min
                    ProcessInstrument_ES();
                    break;
                case 1: // NQ 5min
                    ProcessInstrument_NQ();
                    break;
                case 2: // CL 5min
                    ProcessInstrument_CL();
                    break;
                // Cases 3-5 are 15min confirmation - no direct trading logic
            }
        }

        #endregion

        #region Instrument Processing

        private void ProcessInstrument_ES()
        {
            if (!IsWithinTradingHours()) return;
            if (esConsecutiveLosses >= MaxConsecutiveLosses) return;
            if (!HasCooldownElapsed(lastTradeTimeES)) return;

            int score = CalculateMomentumScore(
                emaFastES, emaSlowES, rsiES, macdES, atrES, volES,
                emaFastES_15, emaSlowES_15, rsiES_15,
                0, 3);

            double currentATR = atrES[0];
            if (currentATR < MinATRFilter) return;

            int contracts = CalculatePositionSize(score, currentATR, 0);

            // Check for breakout conditions
            bool bullishBreakout = IsBreakout(true, 0);
            bool bearishBreakout = IsBreakout(false, 0);

            if (score >= MinMomentumScore || bullishBreakout)
            {
                // Strong bullish signal
                if (Positions[0].MarketPosition == MarketPosition.Short)
                    ExitShort(0, contracts, "ExitShortES", "ShortES");

                if (Positions[0].MarketPosition != MarketPosition.Long)
                {
                    double stopDistance = currentATR * ATRStopMultiplier;
                    double targetDistance = currentATR * ATRTargetMultiplier;

                    SetStopLoss("LongES", CalculationMode.Ticks, stopDistance / TickSize);
                    SetProfitTarget("LongES", CalculationMode.Ticks, targetDistance / TickSize);

                    if (UseTrailingStop)
                        SetTrailStop("LongES", CalculationMode.Ticks, currentATR * TrailingATRMultiplier / TickSize, false);

                    EnterLong(0, contracts, "LongES");
                    lastTradeTimeES = Time[0];
                    totalTradesToday++;
                }
            }
            else if (score <= -MinMomentumScore || bearishBreakout)
            {
                // Strong bearish signal
                if (Positions[0].MarketPosition == MarketPosition.Long)
                    ExitLong(0, contracts, "ExitLongES", "LongES");

                if (Positions[0].MarketPosition != MarketPosition.Short)
                {
                    double stopDistance = currentATR * ATRStopMultiplier;
                    double targetDistance = currentATR * ATRTargetMultiplier;

                    SetStopLoss("ShortES", CalculationMode.Ticks, stopDistance / TickSize);
                    SetProfitTarget("ShortES", CalculationMode.Ticks, targetDistance / TickSize);

                    if (UseTrailingStop)
                        SetTrailStop("ShortES", CalculationMode.Ticks, currentATR * TrailingATRMultiplier / TickSize, false);

                    EnterShort(0, contracts, "ShortES");
                    lastTradeTimeES = Time[0];
                    totalTradesToday++;
                }
            }

            // Manage existing positions - tighten stops in profit
            ManagePosition_ES(currentATR);
        }

        private void ProcessInstrument_NQ()
        {
            if (!IsWithinTradingHours()) return;
            if (nqConsecutiveLosses >= MaxConsecutiveLosses) return;
            if (!HasCooldownElapsed(lastTradeTimeNQ)) return;

            int score = CalculateMomentumScore(
                emaFastNQ, emaSlowNQ, rsiNQ, macdNQ, atrNQ, volNQ,
                emaFastNQ_15, emaSlowNQ_15, rsiNQ_15,
                1, 4);

            double currentATR = atrNQ[0];
            if (currentATR < MinATRFilter) return;

            int contracts = CalculatePositionSize(score, currentATR, 1);

            bool bullishBreakout = IsBreakout(true, 1);
            bool bearishBreakout = IsBreakout(false, 1);

            if (score >= MinMomentumScore || bullishBreakout)
            {
                if (Positions[1].MarketPosition == MarketPosition.Short)
                    ExitShort(1, contracts, "ExitShortNQ", "ShortNQ");

                if (Positions[1].MarketPosition != MarketPosition.Long)
                {
                    double stopDistance = currentATR * ATRStopMultiplier;
                    double targetDistance = currentATR * ATRTargetMultiplier;

                    SetStopLoss("LongNQ", CalculationMode.Ticks, stopDistance / TickSize);
                    SetProfitTarget("LongNQ", CalculationMode.Ticks, targetDistance / TickSize);

                    if (UseTrailingStop)
                        SetTrailStop("LongNQ", CalculationMode.Ticks, currentATR * TrailingATRMultiplier / TickSize, false);

                    EnterLong(1, contracts, "LongNQ");
                    lastTradeTimeNQ = Time[0];
                    totalTradesToday++;
                }
            }
            else if (score <= -MinMomentumScore || bearishBreakout)
            {
                if (Positions[1].MarketPosition == MarketPosition.Long)
                    ExitLong(1, contracts, "ExitLongNQ", "LongNQ");

                if (Positions[1].MarketPosition != MarketPosition.Short)
                {
                    double stopDistance = currentATR * ATRStopMultiplier;
                    double targetDistance = currentATR * ATRTargetMultiplier;

                    SetStopLoss("ShortNQ", CalculationMode.Ticks, stopDistance / TickSize);
                    SetProfitTarget("ShortNQ", CalculationMode.Ticks, targetDistance / TickSize);

                    if (UseTrailingStop)
                        SetTrailStop("ShortNQ", CalculationMode.Ticks, currentATR * TrailingATRMultiplier / TickSize, false);

                    EnterShort(1, contracts, "ShortNQ");
                    lastTradeTimeNQ = Time[0];
                    totalTradesToday++;
                }
            }

            ManagePosition_NQ(currentATR);
        }

        private void ProcessInstrument_CL()
        {
            if (!IsWithinTradingHours()) return;
            if (clConsecutiveLosses >= MaxConsecutiveLosses) return;
            if (!HasCooldownElapsed(lastTradeTimeCL)) return;

            int score = CalculateMomentumScore(
                emaFastCL, emaSlowCL, rsiCL, macdCL, atrCL, volCL,
                emaFastCL_15, emaSlowCL_15, rsiCL_15,
                2, 5);

            double currentATR = atrCL[0];
            if (currentATR < MinATRFilter) return;

            int contracts = CalculatePositionSize(score, currentATR, 2);

            bool bullishBreakout = IsBreakout(true, 2);
            bool bearishBreakout = IsBreakout(false, 2);

            if (score >= MinMomentumScore || bullishBreakout)
            {
                if (Positions[2].MarketPosition == MarketPosition.Short)
                    ExitShort(2, contracts, "ExitShortCL", "ShortCL");

                if (Positions[2].MarketPosition != MarketPosition.Long)
                {
                    double stopDistance = currentATR * ATRStopMultiplier;
                    double targetDistance = currentATR * ATRTargetMultiplier;

                    SetStopLoss("LongCL", CalculationMode.Ticks, stopDistance / TickSize);
                    SetProfitTarget("LongCL", CalculationMode.Ticks, targetDistance / TickSize);

                    if (UseTrailingStop)
                        SetTrailStop("LongCL", CalculationMode.Ticks, currentATR * TrailingATRMultiplier / TickSize, false);

                    EnterLong(2, contracts, "LongCL");
                    lastTradeTimeCL = Time[0];
                    totalTradesToday++;
                }
            }
            else if (score <= -MinMomentumScore || bearishBreakout)
            {
                if (Positions[2].MarketPosition == MarketPosition.Long)
                    ExitLong(2, contracts, "ExitLongCL", "LongCL");

                if (Positions[2].MarketPosition != MarketPosition.Short)
                {
                    double stopDistance = currentATR * ATRStopMultiplier;
                    double targetDistance = currentATR * ATRTargetMultiplier;

                    SetStopLoss("ShortCL", CalculationMode.Ticks, stopDistance / TickSize);
                    SetProfitTarget("ShortCL", CalculationMode.Ticks, targetDistance / TickSize);

                    if (UseTrailingStop)
                        SetTrailStop("ShortCL", CalculationMode.Ticks, currentATR * TrailingATRMultiplier / TickSize, false);

                    EnterShort(2, contracts, "ShortCL");
                    lastTradeTimeCL = Time[0];
                    totalTradesToday++;
                }
            }

            ManagePosition_CL(currentATR);
        }

        #endregion

        #region Momentum Scoring System

        /// <summary>
        /// Calculates a momentum score from -7 to +7.
        /// Positive = bullish, Negative = bearish.
        /// Each factor contributes +1 or -1.
        /// </summary>
        private int CalculateMomentumScore(
            EMA emaFast, EMA emaSlow, RSI rsi, MACD macd, ATR atr, VOL vol,
            EMA emaFast15, EMA emaSlow15, RSI rsi15,
            int barsIdx5, int barsIdx15)
        {
            if (!EnableMomentumScoring) return 0;

            int score = 0;

            // 1. EMA Trend (5min): Fast above Slow = bullish
            if (emaFast[0] > emaSlow[0])
                score++;
            else if (emaFast[0] < emaSlow[0])
                score--;

            // 2. EMA Momentum: Fast EMA rising/falling
            if (emaFast[0] > emaFast[1])
                score++;
            else if (emaFast[0] < emaFast[1])
                score--;

            // 3. RSI (5min): Above/below 50
            if (rsi[0] > 50 + (50 - RSILongThreshold))
                score++;
            else if (rsi[0] < 50 - (RSIShortThreshold - 50))
                score--;

            // 4. MACD Signal: Line above/below signal
            if (macd[0] > macd.Avg[0])
                score++;
            else if (macd[0] < macd.Avg[0])
                score--;

            // 5. MACD Histogram rising/falling
            double histCurrent = macd[0] - macd.Avg[0];
            double histPrev = macd[1] - macd.Avg[1];
            if (histCurrent > histPrev)
                score++;
            else if (histCurrent < histPrev)
                score--;

            // 6. Higher timeframe confirmation (15min EMA trend)
            if (emaFast15[0] > emaSlow15[0])
                score++;
            else if (emaFast15[0] < emaSlow15[0])
                score--;

            // 7. Higher timeframe RSI confirmation
            if (rsi15[0] > 55)
                score++;
            else if (rsi15[0] < 45)
                score--;

            return score;
        }

        #endregion

        #region Breakout Detection

        /// <summary>
        /// Detects price breakout from recent consolidation range.
        /// </summary>
        private bool IsBreakout(bool bullish, int barsIdx)
        {
            double highest = double.MinValue;
            double lowest = double.MaxValue;

            for (int i = 1; i <= BreakoutLookback; i++)
            {
                if (Highs[barsIdx][i] > highest) highest = Highs[barsIdx][i];
                if (Lows[barsIdx][i] < lowest) lowest = Lows[barsIdx][i];
            }

            double range = highest - lowest;
            double atrVal = 0;

            switch (barsIdx)
            {
                case 0: atrVal = atrES[0]; break;
                case 1: atrVal = atrNQ[0]; break;
                case 2: atrVal = atrCL[0]; break;
            }

            // Range must be tight enough (consolidation)
            if (range > atrVal * 3) return false;

            double breakoutThreshold = atrVal * BreakoutATRMultiplier;

            if (bullish)
                return Closes[barsIdx][0] > highest + breakoutThreshold;
            else
                return Closes[barsIdx][0] < lowest - breakoutThreshold;
        }

        #endregion

        #region Position Sizing

        /// <summary>
        /// Competition mode: always trade max contracts when signal is strong.
        /// Reduce to 1 contract for weaker signals.
        /// </summary>
        private int CalculatePositionSize(int momentumScore, double atr, int barsIdx)
        {
            int absScore = Math.Abs(momentumScore);

            // Very strong signal (5+) -> max contracts
            if (absScore >= 5)
                return MaxContractsPerInstrument;

            // Moderate signal (3-4) -> 1 contract
            if (absScore >= MinMomentumScore)
                return Math.Max(1, MaxContractsPerInstrument - 1);

            return 1;
        }

        #endregion

        #region Position Management

        private void ManagePosition_ES(double currentATR)
        {
            if (Positions[0].MarketPosition == MarketPosition.Flat) return;

            double unrealizedPnL = Positions[0].GetUnrealizedProfitLoss(PerformanceUnit.Currency);

            // Move to breakeven after 1.5 ATR profit
            if (unrealizedPnL > currentATR * 1.5 * Positions[0].Quantity)
            {
                if (Positions[0].MarketPosition == MarketPosition.Long)
                    SetStopLoss("LongES", CalculationMode.Price, Positions[0].AveragePrice + (currentATR * 0.2));
                else if (Positions[0].MarketPosition == MarketPosition.Short)
                    SetStopLoss("ShortES", CalculationMode.Price, Positions[0].AveragePrice - (currentATR * 0.2));
            }

            // Exit if RSI hits extreme (counter-trend warning)
            if (Positions[0].MarketPosition == MarketPosition.Long && rsiES[0] >= RSIOverbought)
            {
                ExitLong(0, Positions[0].Quantity, "RSI_OB_ES", "LongES");
            }
            else if (Positions[0].MarketPosition == MarketPosition.Short && rsiES[0] <= RSIOversold)
            {
                ExitShort(0, Positions[0].Quantity, "RSI_OS_ES", "ShortES");
            }
        }

        private void ManagePosition_NQ(double currentATR)
        {
            if (Positions[1].MarketPosition == MarketPosition.Flat) return;

            double unrealizedPnL = Positions[1].GetUnrealizedProfitLoss(PerformanceUnit.Currency);

            if (unrealizedPnL > currentATR * 1.5 * Positions[1].Quantity)
            {
                if (Positions[1].MarketPosition == MarketPosition.Long)
                    SetStopLoss("LongNQ", CalculationMode.Price, Positions[1].AveragePrice + (currentATR * 0.2));
                else if (Positions[1].MarketPosition == MarketPosition.Short)
                    SetStopLoss("ShortNQ", CalculationMode.Price, Positions[1].AveragePrice - (currentATR * 0.2));
            }

            if (Positions[1].MarketPosition == MarketPosition.Long && rsiNQ[0] >= RSIOverbought)
            {
                ExitLong(1, Positions[1].Quantity, "RSI_OB_NQ", "LongNQ");
            }
            else if (Positions[1].MarketPosition == MarketPosition.Short && rsiNQ[0] <= RSIOversold)
            {
                ExitShort(1, Positions[1].Quantity, "RSI_OS_NQ", "ShortNQ");
            }
        }

        private void ManagePosition_CL(double currentATR)
        {
            if (Positions[2].MarketPosition == MarketPosition.Flat) return;

            double unrealizedPnL = Positions[2].GetUnrealizedProfitLoss(PerformanceUnit.Currency);

            if (unrealizedPnL > currentATR * 1.5 * Positions[2].Quantity)
            {
                if (Positions[2].MarketPosition == MarketPosition.Long)
                    SetStopLoss("LongCL", CalculationMode.Price, Positions[2].AveragePrice + (currentATR * 0.2));
                else if (Positions[2].MarketPosition == MarketPosition.Short)
                    SetStopLoss("ShortCL", CalculationMode.Price, Positions[2].AveragePrice - (currentATR * 0.2));
            }

            if (Positions[2].MarketPosition == MarketPosition.Long && rsiCL[0] >= RSIOverbought)
            {
                ExitLong(2, Positions[2].Quantity, "RSI_OB_CL", "LongCL");
            }
            else if (Positions[2].MarketPosition == MarketPosition.Short && rsiCL[0] <= RSIOversold)
            {
                ExitShort(2, Positions[2].Quantity, "RSI_OS_CL", "ShortCL");
            }
        }

        private void FlattenAll()
        {
            if (Positions[0].MarketPosition == MarketPosition.Long)
                ExitLong(0, Positions[0].Quantity, "FlattenES", "LongES");
            if (Positions[0].MarketPosition == MarketPosition.Short)
                ExitShort(0, Positions[0].Quantity, "FlattenES", "ShortES");

            if (Positions[1].MarketPosition == MarketPosition.Long)
                ExitLong(1, Positions[1].Quantity, "FlattenNQ", "LongNQ");
            if (Positions[1].MarketPosition == MarketPosition.Short)
                ExitShort(1, Positions[1].Quantity, "FlattenNQ", "ShortNQ");

            if (Positions[2].MarketPosition == MarketPosition.Long)
                ExitLong(2, Positions[2].Quantity, "FlattenCL", "LongCL");
            if (Positions[2].MarketPosition == MarketPosition.Short)
                ExitShort(2, Positions[2].Quantity, "FlattenCL", "ShortCL");
        }

        #endregion

        #region Trade Tracking

        protected override void OnExecutionUpdate(Execution execution, string executionId, double price,
            int quantity, MarketPosition marketPosition, string orderId, DateTime time)
        {
            // Track consecutive losses per instrument
            if (execution.Order.OrderState == OrderState.Filled)
            {
                Print(string.Format("[MarchMadnessBot] {0} | {1} {2} @ {3} | Qty: {4}",
                    time, execution.Order.Name, execution.Instrument.FullName, price, quantity));
            }
        }

        protected override void OnPositionUpdate(Position position, double averagePrice,
            int quantity, MarketPosition marketPosition)
        {
            if (marketPosition == MarketPosition.Flat)
            {
                double pnl = position.GetUnrealizedProfitLoss(PerformanceUnit.Currency);

                // Determine which instrument closed
                string instrument = position.Instrument.FullName;
                if (instrument.Contains("ES"))
                {
                    if (pnl < 0) esConsecutiveLosses++;
                    else esConsecutiveLosses = 0;
                }
                else if (instrument.Contains("NQ"))
                {
                    if (pnl < 0) nqConsecutiveLosses++;
                    else nqConsecutiveLosses = 0;
                }
                else if (instrument.Contains("CL"))
                {
                    if (pnl < 0) clConsecutiveLosses++;
                    else clConsecutiveLosses = 0;
                }

                Print(string.Format("[MarchMadnessBot] Position closed: {0} | PnL: ${1:F2} | Consecutive losses: ES={2} NQ={3} CL={4}",
                    instrument, pnl, esConsecutiveLosses, nqConsecutiveLosses, clConsecutiveLosses));
            }
        }

        #endregion

        #region Utility Methods

        /// <summary>
        /// Check if current time is within allowed trading hours (CT timezone).
        /// Competition runs Mon-Fri, standard futures hours.
        /// </summary>
        private bool IsWithinTradingHours()
        {
            int hour = Time[0].Hour;
            int minute = Time[0].Minute;
            int timeValue = hour * 100 + minute;

            bool inMorning = EnableMorningSession &&
                timeValue >= (MorningStartHour * 100 + MorningStartMinute) &&
                timeValue <= (MorningEndHour * 100 + MorningEndMinute);

            bool inAfternoon = EnableAfternoonSession &&
                timeValue >= (AfternoonStartHour * 100 + AfternoonStartMinute) &&
                timeValue <= (AfternoonEndHour * 100 + AfternoonEndMinute);

            return inMorning || inAfternoon;
        }

        /// <summary>
        /// Cooldown period between trades to avoid overtrading.
        /// </summary>
        private bool HasCooldownElapsed(DateTime lastTradeTime)
        {
            if (lastTradeTime == DateTime.MinValue) return true;
            return (Time[0] - lastTradeTime).TotalMinutes >= CooldownMinutes;
        }

        #endregion

        #region Properties

        // === Indicator Parameters ===
        [NinjaScriptProperty]
        [Range(2, 50)]
        [Display(Name = "Fast EMA Period", Order = 1, GroupName = "Indicators")]
        public int FastEMAPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(5, 100)]
        [Display(Name = "Slow EMA Period", Order = 2, GroupName = "Indicators")]
        public int SlowEMAPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(2, 50)]
        [Display(Name = "RSI Period", Order = 3, GroupName = "Indicators")]
        public int RSIPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(2, 50)]
        [Display(Name = "ATR Period", Order = 4, GroupName = "Indicators")]
        public int ATRPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(2, 50)]
        [Display(Name = "MACD Fast", Order = 5, GroupName = "Indicators")]
        public int MACDFast { get; set; }

        [NinjaScriptProperty]
        [Range(5, 100)]
        [Display(Name = "MACD Slow", Order = 6, GroupName = "Indicators")]
        public int MACDSlow { get; set; }

        [NinjaScriptProperty]
        [Range(2, 50)]
        [Display(Name = "MACD Smooth", Order = 7, GroupName = "Indicators")]
        public int MACDSmooth { get; set; }

        // === Position Sizing ===
        [NinjaScriptProperty]
        [Range(1, 10)]
        [Display(Name = "Max Contracts Per Instrument", Order = 1, GroupName = "Position Sizing")]
        public int MaxContractsPerInstrument { get; set; }

        // === Risk Management ===
        [NinjaScriptProperty]
        [Range(0.5, 5.0)]
        [Display(Name = "ATR Stop Multiplier", Order = 1, GroupName = "Risk Management")]
        public double ATRStopMultiplier { get; set; }

        [NinjaScriptProperty]
        [Range(1.0, 10.0)]
        [Display(Name = "ATR Target Multiplier", Order = 2, GroupName = "Risk Management")]
        public double ATRTargetMultiplier { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Use Trailing Stop", Order = 3, GroupName = "Risk Management")]
        public bool UseTrailingStop { get; set; }

        [NinjaScriptProperty]
        [Range(0.5, 5.0)]
        [Display(Name = "Trailing ATR Multiplier", Order = 4, GroupName = "Risk Management")]
        public double TrailingATRMultiplier { get; set; }

        [NinjaScriptProperty]
        [Range(1, 10)]
        [Display(Name = "Max Consecutive Losses", Order = 5, GroupName = "Risk Management")]
        public int MaxConsecutiveLosses { get; set; }

        [NinjaScriptProperty]
        [Range(500, 25000)]
        [Display(Name = "Session Drawdown Limit ($)", Order = 6, GroupName = "Risk Management")]
        public double SessionDrawdownLimit { get; set; }

        [NinjaScriptProperty]
        [Range(1, 60)]
        [Display(Name = "Cooldown Minutes", Order = 7, GroupName = "Risk Management")]
        public int CooldownMinutes { get; set; }

        // === RSI Thresholds ===
        [NinjaScriptProperty]
        [Range(20, 50)]
        [Display(Name = "RSI Long Threshold", Order = 1, GroupName = "RSI Settings")]
        public int RSILongThreshold { get; set; }

        [NinjaScriptProperty]
        [Range(50, 80)]
        [Display(Name = "RSI Short Threshold", Order = 2, GroupName = "RSI Settings")]
        public int RSIShortThreshold { get; set; }

        [NinjaScriptProperty]
        [Range(70, 95)]
        [Display(Name = "RSI Overbought", Order = 3, GroupName = "RSI Settings")]
        public int RSIOverbought { get; set; }

        [NinjaScriptProperty]
        [Range(5, 30)]
        [Display(Name = "RSI Oversold", Order = 4, GroupName = "RSI Settings")]
        public int RSIOversold { get; set; }

        // === Filters ===
        [NinjaScriptProperty]
        [Range(0.1, 10.0)]
        [Display(Name = "Min ATR Filter", Order = 1, GroupName = "Filters")]
        public double MinATRFilter { get; set; }

        [NinjaScriptProperty]
        [Range(0.5, 3.0)]
        [Display(Name = "Volume Multiplier", Order = 2, GroupName = "Filters")]
        public double VolumeMultiplier { get; set; }

        // === Trading Hours ===
        [NinjaScriptProperty]
        [Display(Name = "Enable Morning Session", Order = 1, GroupName = "Trading Hours")]
        public bool EnableMorningSession { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Enable Afternoon Session", Order = 2, GroupName = "Trading Hours")]
        public bool EnableAfternoonSession { get; set; }

        [NinjaScriptProperty]
        [Range(0, 23)]
        [Display(Name = "Morning Start Hour", Order = 3, GroupName = "Trading Hours")]
        public int MorningStartHour { get; set; }

        [NinjaScriptProperty]
        [Range(0, 59)]
        [Display(Name = "Morning Start Minute", Order = 4, GroupName = "Trading Hours")]
        public int MorningStartMinute { get; set; }

        [NinjaScriptProperty]
        [Range(0, 23)]
        [Display(Name = "Morning End Hour", Order = 5, GroupName = "Trading Hours")]
        public int MorningEndHour { get; set; }

        [NinjaScriptProperty]
        [Range(0, 59)]
        [Display(Name = "Morning End Minute", Order = 6, GroupName = "Trading Hours")]
        public int MorningEndMinute { get; set; }

        [NinjaScriptProperty]
        [Range(0, 23)]
        [Display(Name = "Afternoon Start Hour", Order = 7, GroupName = "Trading Hours")]
        public int AfternoonStartHour { get; set; }

        [NinjaScriptProperty]
        [Range(0, 59)]
        [Display(Name = "Afternoon Start Minute", Order = 8, GroupName = "Trading Hours")]
        public int AfternoonStartMinute { get; set; }

        [NinjaScriptProperty]
        [Range(0, 23)]
        [Display(Name = "Afternoon End Hour", Order = 9, GroupName = "Trading Hours")]
        public int AfternoonEndHour { get; set; }

        [NinjaScriptProperty]
        [Range(0, 59)]
        [Display(Name = "Afternoon End Minute", Order = 10, GroupName = "Trading Hours")]
        public int AfternoonEndMinute { get; set; }

        // === Breakout ===
        [NinjaScriptProperty]
        [Range(3, 50)]
        [Display(Name = "Breakout Lookback Bars", Order = 1, GroupName = "Breakout")]
        public int BreakoutLookback { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 2.0)]
        [Display(Name = "Breakout ATR Multiplier", Order = 2, GroupName = "Breakout")]
        public double BreakoutATRMultiplier { get; set; }

        // === Momentum Scoring ===
        [NinjaScriptProperty]
        [Display(Name = "Enable Momentum Scoring", Order = 1, GroupName = "Momentum")]
        public bool EnableMomentumScoring { get; set; }

        [NinjaScriptProperty]
        [Range(1, 7)]
        [Display(Name = "Min Momentum Score", Order = 2, GroupName = "Momentum")]
        public int MinMomentumScore { get; set; }

        #endregion
    }
}
