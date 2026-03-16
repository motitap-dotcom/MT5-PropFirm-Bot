//+------------------------------------------------------------------+
//|                                                Dashboard.mqh      |
//|                     REAL-TIME ON-CHART MONITORING PANEL           |
//|                     Shows all critical data at a glance           |
//+------------------------------------------------------------------+
#property copyright "PropFirmBot"
#property version   "2.00"

#include "Guardian.mqh"

//--- Dashboard colors
#define CLR_BG          C'20,20,30'
#define CLR_BORDER      C'60,60,80'
#define CLR_TITLE       clrGold
#define CLR_LABEL       C'150,150,170'
#define CLR_VALUE       clrWhite
#define CLR_GOOD        clrLime
#define CLR_WARN        clrOrange
#define CLR_DANGER      clrRed
#define CLR_PROFIT      clrLime
#define CLR_LOSS        clrRed

//+------------------------------------------------------------------+
class CDashboard
{
private:
   string   m_prefix;
   int      m_x;
   int      m_y;
   int      m_width;
   int      m_line_height;
   string   m_font;
   int      m_font_size;
   double   m_hard_daily_dd;   // 0 = disabled (Stellar Instant)
   double   m_hard_total_dd;   // 6% for Stellar Instant
   double   m_profit_target;   // 0 = no target

   void     CreateLabel(string name, int x, int y, string text,
                         color clr, int size = 0, string font = "");
   void     UpdateLabel(string name, string text, color clr = CLR_VALUE);
   void     DeleteAll();
   color    DDColor(double dd_pct, double soft, double crit);
   string   BarGraph(double value, double max_val, int bar_len = 20);

public:
            CDashboard();
           ~CDashboard();

   void     Init(int x = 10, int y = 30, double hard_daily_dd = 0, double hard_total_dd = 6.0, double profit_target = 0);
   void     Update(CGuardian &guardian, int open_positions, double floating_pnl);
   void     Destroy();
};

//+------------------------------------------------------------------+
CDashboard::CDashboard()
{
   m_prefix = "PFB_";
   m_x = 10;
   m_y = 25;
   m_width = 260;
   m_line_height = 15;
   m_font = "Consolas";
   m_font_size = 8;
   m_hard_daily_dd = 0;
   m_hard_total_dd = 6.0;
   m_profit_target = 0;
}

//+------------------------------------------------------------------+
CDashboard::~CDashboard()
{
   Destroy();
}

//+------------------------------------------------------------------+
void CDashboard::Init(int x, int y, double hard_daily_dd, double hard_total_dd, double profit_target)
{
   m_x = x;
   m_y = y;
   m_hard_daily_dd = hard_daily_dd;
   m_hard_total_dd = hard_total_dd;
   m_profit_target = profit_target;

   // Background rectangle
   string bg_name = m_prefix + "BG";
   ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, m_x - 5);
   ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, m_y - 5);
   ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, m_width);
   ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, m_line_height * 11 + 10);
   ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR, CLR_BG);
   ObjectSetInteger(0, bg_name, OBJPROP_BORDER_COLOR, CLR_BORDER);
   ObjectSetInteger(0, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg_name, OBJPROP_SELECTABLE, false);

   int row = 0;

   // Title + State on same concept
   CreateLabel("TITLE", m_x + 5, m_y + row * m_line_height,
               "PropFirmBot v2.0", CLR_TITLE, 9, "Consolas Bold");
   CreateLabel("STATE_V", m_x + 155, m_y + row * m_line_height, "---", CLR_VALUE);
   row += 2;

   // Balance / Equity on two lines
   CreateLabel("BAL_L", m_x + 5,   m_y + row * m_line_height, "Bal:", CLR_LABEL);
   CreateLabel("BAL_V", m_x + 70,  m_y + row * m_line_height, "---", CLR_VALUE);
   row++;

   CreateLabel("EQ_L",  m_x + 5,   m_y + row * m_line_height, "Eq:", CLR_LABEL);
   CreateLabel("EQ_V",  m_x + 70,  m_y + row * m_line_height, "---", CLR_VALUE);
   row++;

   // Profit
   CreateLabel("PNL_L", m_x + 5,   m_y + row * m_line_height, "P/L:", CLR_LABEL);
   CreateLabel("PNL_V", m_x + 70,  m_y + row * m_line_height, "---", CLR_VALUE);
   row++;

   // Daily DD
   CreateLabel("DDD_L", m_x + 5,   m_y + row * m_line_height, "DayDD:", CLR_LABEL);
   CreateLabel("DDD_V", m_x + 70,  m_y + row * m_line_height, "---", CLR_VALUE);
   row++;

   // Total DD
   CreateLabel("TDD_L", m_x + 5,   m_y + row * m_line_height, "TotDD:", CLR_LABEL);
   CreateLabel("TDD_V", m_x + 70,  m_y + row * m_line_height, "---", CLR_VALUE);
   row++;

   // Positions + Today combined
   CreateLabel("POS_L", m_x + 5,   m_y + row * m_line_height, "Pos:", CLR_LABEL);
   CreateLabel("POS_V", m_x + 70,  m_y + row * m_line_height, "---", CLR_VALUE);
   row++;

   CreateLabel("TODAY_L", m_x + 5,   m_y + row * m_line_height, "Today:", CLR_LABEL);
   CreateLabel("TODAY_V", m_x + 70,  m_y + row * m_line_height, "---", CLR_VALUE);
   row++;

   // Connection + ConsecLoss combined
   CreateLabel("CONN_L", m_x + 5,   m_y + row * m_line_height, "Conn:", CLR_LABEL);
   CreateLabel("CONN_V", m_x + 70,  m_y + row * m_line_height, "---", CLR_VALUE);
   CreateLabel("CL_L",   m_x + 130, m_y + row * m_line_height, "CL:", CLR_LABEL);
   CreateLabel("CL_V",   m_x + 165, m_y + row * m_line_height, "---", CLR_VALUE);
   row++;

   // Halt message (only shown when needed)
   CreateLabel("HALT_L", m_x + 5, m_y + row * m_line_height, "", CLR_DANGER);

   // Hidden labels for removed elements (keep Update() compatible)
   CreateLabel("DDD_BAR", -100, -100, "", CLR_LABEL);
   CreateLabel("TDD_BAR", -100, -100, "", CLR_LABEL);
   CreateLabel("TIME_V",  -100, -100, "", CLR_BORDER);

   ChartRedraw();
}

//+------------------------------------------------------------------+
void CDashboard::Update(CGuardian &guardian, int open_positions, double floating_pnl)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double daily_dd = guardian.DailyDD();
   double total_dd = guardian.TotalDD();
   double profit_pct = guardian.ProfitPct();

   // State
   string state_text;
   color state_clr;
   switch(guardian.GetState())
   {
      case GUARDIAN_ACTIVE:    state_text = ">> ACTIVE <<";    state_clr = CLR_GOOD;   break;
      case GUARDIAN_CAUTION:   state_text = "!! CAUTION !!";   state_clr = CLR_WARN;   break;
      case GUARDIAN_HALTED:    state_text = "XX HALTED XX";    state_clr = CLR_DANGER; break;
      case GUARDIAN_EMERGENCY: state_text = "!! EMERGENCY !!"; state_clr = CLR_DANGER; break;
      case GUARDIAN_SHUTDOWN:  state_text = "== SHUTDOWN ==";  state_clr = CLR_DANGER; break;
      default:                state_text = "???";              state_clr = CLR_VALUE;  break;
   }
   UpdateLabel("STATE_V", state_text, state_clr);

   // Balance / Equity
   UpdateLabel("BAL_V", StringFormat("$%.2f", balance), CLR_VALUE);
   UpdateLabel("EQ_V",  StringFormat("$%.2f (float %+.2f)", equity, floating_pnl),
               floating_pnl >= 0 ? CLR_PROFIT : CLR_LOSS);

   // Profit
   double total_pnl = equity - guardian.InitialBalance();
   if(m_profit_target > 0)
      UpdateLabel("PNL_V", StringFormat("%+.2f%% ($%+.2f) / %.1f%%",
                  profit_pct, total_pnl, m_profit_target),
                  profit_pct >= 0 ? CLR_PROFIT : CLR_LOSS);
   else
      UpdateLabel("PNL_V", StringFormat("%+.2f%% ($%+.2f) NO TARGET",
                  profit_pct, total_pnl),
                  profit_pct >= 0 ? CLR_PROFIT : CLR_LOSS);

   // Daily DD
   if(m_hard_daily_dd > 0)
   {
      UpdateLabel("DDD_V", StringFormat("%.2f%% ($%.2f) / %.1f%%",
                  daily_dd, guardian.DailyOpenBalance() - equity, m_hard_daily_dd),
                  DDColor(daily_dd, m_hard_daily_dd * 0.6, m_hard_daily_dd * 0.8));
      UpdateLabel("DDD_BAR", BarGraph(daily_dd, m_hard_daily_dd),
                  DDColor(daily_dd, m_hard_daily_dd * 0.6, m_hard_daily_dd * 0.8));
   }
   else
   {
      UpdateLabel("DDD_V", "N/A (no daily limit)", CLR_GOOD);
      UpdateLabel("DDD_BAR", "", CLR_GOOD);
   }

   // Total DD (trailing from equity high water mark for Stellar Instant)
   double dd_display = MathMax(0, guardian.EquityHighWater() - equity);
   UpdateLabel("TDD_V", StringFormat("%.2f%% ($%.2f) / %.1f%% TRAILING",
               total_dd, dd_display, m_hard_total_dd),
               DDColor(total_dd, m_hard_total_dd * 0.58, m_hard_total_dd * 0.83));
   UpdateLabel("TDD_BAR", BarGraph(total_dd, m_hard_total_dd),
               DDColor(total_dd, m_hard_total_dd * 0.58, m_hard_total_dd * 0.83));

   // Positions
   UpdateLabel("POS_V", StringFormat("%d open | %d trades today",
               open_positions, guardian.DailyTrades()), CLR_VALUE);

   // Today
   UpdateLabel("TODAY_V", StringFormat("W%d L%d | +$%.2f -$%.2f",
               guardian.TodayWins(), guardian.TodayLosses(),
               guardian.TodayProfit(), guardian.TodayLoss()),
               guardian.TodayProfit() >= guardian.TodayLoss() ? CLR_PROFIT : CLR_LOSS);

   // Consecutive losses
   int cl = guardian.ConsecLosses();
   color cl_clr = cl >= 4 ? CLR_DANGER : (cl >= 2 ? CLR_WARN : CLR_GOOD);
   UpdateLabel("CL_V", StringFormat("%d / 5", cl), cl_clr);

   // Connection
   UpdateLabel("CONN_V", guardian.ConnectionOK() ? "OK" : "UNSTABLE",
               guardian.ConnectionOK() ? CLR_GOOD : CLR_DANGER);

   // Halt message
   string halt = guardian.GetHaltMessage();
   UpdateLabel("HALT_L", halt != "" ? ">> " + halt : "", CLR_DANGER);

   // Time
   UpdateLabel("TIME_V",
      StringFormat("Server: %s | GMT: %s",
                   TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                   TimeToString(TimeGMT(), TIME_MINUTES)),
      CLR_BORDER);

   ChartRedraw();
}

//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, int x, int y, string text,
                              color clr, int size, string font)
{
   string obj_name = m_prefix + name;
   ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
   ObjectSetString(0, obj_name, OBJPROP_FONT, font != "" ? font : m_font);
   ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, size > 0 ? size : m_font_size);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void CDashboard::UpdateLabel(string name, string text, color clr)
{
   string obj_name = m_prefix + name;
   ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
color CDashboard::DDColor(double dd_pct, double soft, double crit)
{
   if(dd_pct >= crit) return CLR_DANGER;
   if(dd_pct >= soft) return CLR_WARN;
   return CLR_GOOD;
}

//+------------------------------------------------------------------+
string CDashboard::BarGraph(double value, double max_val, int bar_len)
{
   int filled = (int)MathRound((value / max_val) * bar_len);
   if(filled > bar_len) filled = bar_len;
   if(filled < 0) filled = 0;

   string bar = "[";
   for(int i = 0; i < bar_len; i++)
   {
      if(i < filled) bar += "|";
      else           bar += ".";
   }
   bar += "]";
   return bar;
}

//+------------------------------------------------------------------+
void CDashboard::Destroy()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, m_prefix) == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw();
}
//+------------------------------------------------------------------+
