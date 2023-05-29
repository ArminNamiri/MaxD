//+------------------------------------------------------------------+
//|                                                       MaxDDD.mq4 |
//|                                                           RMNNMR |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "RMNNMR"
#property version   "10.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

input double MaxDailyDrawDown = 2.5;
double MaxDailyBalance;
bool AlertTriggered = false;
datetime LastAlertTime;
int AlertCount = 0;
int prevOrdersCount;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetMaxDailyAccountBalance()
  {
   datetime today = TimeCurrent();
   double startingBalance = GetBalanceBeforeFirstTradeToday();
   double dailyBalance[];
   ArrayResize(dailyBalance, OrdersHistoryTotal() + 1);
   dailyBalance[0] = startingBalance;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(TimeDay(OrderCloseTime()) == TimeDay(today) && TimeMonth(OrderCloseTime()) == TimeMonth(today) && TimeYear(OrderCloseTime()) == TimeYear(today))
           {
            double orderTotal = OrderProfit() + OrderSwap() + OrderCommission();
            startingBalance += orderTotal;
            dailyBalance[OrdersHistoryTotal() - i] = startingBalance;
           }
        }
     }

   ArraySort(dailyBalance);
   MaxDailyBalance = dailyBalance[ArraySize(dailyBalance) - 1];
   return MaxDailyBalance;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DisplayText(string text, color textColor)
  {
   if(ObjectFind("DisplayText") == -1)
     {
      ObjectCreate("DisplayText", OBJ_LABEL, 0, 0, 0);
      ObjectSet("DisplayText", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSet("DisplayText", OBJPROP_XDISTANCE, 10);
      ObjectSet("DisplayText", OBJPROP_YDISTANCE, 30);
     }

   ObjectSetText("DisplayText", text, 11, "Arial", textColor);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetBalanceBeforeFirstTradeToday()
  {
   datetime today = TimeCurrent();
   double startingBalance = AccountBalance();
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(TimeDay(OrderOpenTime()) == TimeDay(today) && TimeMonth(OrderOpenTime()) == TimeMonth(today) && TimeYear(OrderOpenTime()) == TimeYear(today))
           {
            double orderTotal = OrderProfit() + OrderSwap() + OrderCommission();
            startingBalance -= orderTotal;
           }
         else
           {
            break;
           }
        }
     }
   return startingBalance;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorBuffers(1);
   MaxDailyBalance = GetBalanceBeforeFirstTradeToday();
   prevOrdersCount = OrdersTotal();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   double CurrentBalance = AccountBalance();
   if(CurrentBalance > MaxDailyBalance)
     {
      MaxDailyBalance = CurrentBalance;
     }

   double MaxBalance = MaxDailyBalance;
   double MinAllowableBalance = MaxBalance * (1 - MaxDailyDrawDown / 100);
   MinAllowableBalance = MathCeil(MinAllowableBalance / 10.0) * 10;
   double drawdown = MaxBalance - AccountEquity();

   string displayText = "";
   displayText += "Max: " + DoubleToString(MathFloor(MaxBalance / 10) * 10, 0) + " || ";
   displayText += "Limit: " + DoubleToString(MathCeil(MinAllowableBalance / 10) * 10, 0) + " ";
   displayText += "(-" + DoubleToString(MaxDailyDrawDown, 2) + " %) || ";
   displayText += "Equity: " + DoubleToString(AccountEquity(), 0) + " ";
   displayText += "(" + DoubleToString(-drawdown / MaxBalance * 100, 2) + " %) ";

   DisplayText(displayText, clrYellow);

   if(drawdown / MaxBalance * 100 >= MaxDailyDrawDown && AlertCount < 10 && TimeCurrent() - LastAlertTime >= 3600)
     {
      Alert("Account Equity has reached the Maximum Daily DrawDown!");
      AlertTriggered = true;
      LastAlertTime = TimeCurrent();
      AlertCount++;
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   int currentOrdersCount = OrdersTotal();
   if(currentOrdersCount < prevOrdersCount)
     {
      MaxDailyBalance = GetMaxDailyAccountBalance();
     }
   prevOrdersCount = currentOrdersCount;
  }
//+------------------------------------------------------------------+
