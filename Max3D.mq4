//+------------------------------------------------------------------+
//|                                                        Max3D.mq4 |
//|                                                           RMNNMR |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "RMNNMR"
#property version   "7.0"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

input double MaxDailyDrawdownPercent = 2.5;
input double MaxOpenPositionsDrawdownPercent = 1.8;
input bool EnableOpenPositionsDrawdownAlert = true;
input bool CloseMostInLossTradeEnabled = false;
double MaxDailyBalance;
bool AlertTriggered = false;
bool OpenPositionsDrawdownAlertTriggered = false;
datetime LastAlertTime;
int AlertCount = 0;
int previousOrdersCount;
bool DisplayTextInitialized = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetMaxDailyAccountBalance()
{
    datetime today = TimeCurrent();
    double startingBalance = GetBalanceBeforeFirstTradeToday();
    double dailyBalances[];
    ArrayResize(dailyBalances, OrdersHistoryTotal() + 1);
    dailyBalances[0] = startingBalance;

    for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            if (TimeDay(OrderCloseTime()) == TimeDay(today) && TimeMonth(OrderCloseTime()) == TimeMonth(today) && TimeYear(OrderCloseTime()) == TimeYear(today))
            {
                double orderTotal = OrderProfit() + OrderSwap() + OrderCommission();
                startingBalance += orderTotal;
                dailyBalances[OrdersHistoryTotal() - i] = startingBalance;
            }
        }
    }

    ArraySort(dailyBalances);
    MaxDailyBalance = dailyBalances[ArraySize(dailyBalances) - 1];
    return MaxDailyBalance;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeDisplayText()
{
    if (ObjectFind("DisplayText") == -1)
    {
        ObjectCreate("DisplayText", OBJ_LABEL, 0, 0, 0);
        ObjectSet("DisplayText", OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSet("DisplayText", OBJPROP_XDISTANCE, 10);
        ObjectSet("DisplayText", OBJPROP_YDISTANCE, 40);
        ObjectSet("DisplayText", OBJPROP_BACK, true); // Add background color to make the text more visible
    }
    
    // Extend the width of the label object
    ObjectSet("DisplayText", OBJPROP_WIDTH, 600);
    
    DisplayTextInitialized = true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetBalanceBeforeFirstTradeToday()
{
    datetime today = TimeCurrent();
    double startingBalance = AccountBalance();
    for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            if (TimeDay(OrderOpenTime()) == TimeDay(today) && TimeMonth(OrderOpenTime()) == TimeMonth(today) && TimeYear(OrderOpenTime()) == TimeYear(today))
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
    previousOrdersCount = OrdersTotal();
    InitializeDisplayText();
    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int ratesTotal,
                const int previousCalculated,
                const datetime &times[],
                const double &opens[],
                const double &highs[],
                const double &lows[],
                const double &closes[],
                const long &tickVolumes[],
                const long &volumes[],
                const int &spreads[])
{
    double currentBalance = AccountBalance();
    if (currentBalance > MaxDailyBalance)
    {
        MaxDailyBalance = currentBalance;
    }

    if (!DisplayTextInitialized)
    {
        InitializeDisplayText();
    }

    double maxBalance = MaxDailyBalance;
    double minAllowableBalance = maxBalance * (1 - MaxDailyDrawdownPercent / 100);
    minAllowableBalance = MathCeil(minAllowableBalance / 10.0) * 10;
    double drawdown = maxBalance - AccountEquity();

    double openPositionsDrawdown = (1 - AccountEquity() / currentBalance) * 100;

    string displayText = "";
    displayText += "Max: " + DoubleToString(MathFloor(maxBalance / 10) * 10, 0) + " ";
    displayText += "(Lim: " + DoubleToString(MathCeil(minAllowableBalance / 10) * 10, 0) + ") || ";
    displayText += "Eq: " + DoubleToString(AccountEquity(), 0) + " ";
    displayText += "(" + DoubleToString(-drawdown / maxBalance * 100, 1) + " %) || ";
    displayText += "DD: (" + DoubleToString(-openPositionsDrawdown, 1) + " %)";

    ObjectSetText("DisplayText", displayText, 12, "Arial", clrYellow); // Decrease font size and change text color
    ObjectSet("DisplayText", OBJPROP_WIDTH, 800); // Extend the width of the label object

    if (drawdown / maxBalance * 100 >= MaxDailyDrawdownPercent && AlertCount < 10 && TimeCurrent() - LastAlertTime >= 3600)
    {
        Alert("Account Equity has reached the Maximum Daily Drawdown!");
        AlertTriggered = true;
        LastAlertTime = TimeCurrent();
        AlertCount++;
    }

    if (EnableOpenPositionsDrawdownAlert && openPositionsDrawdown >= MaxOpenPositionsDrawdownPercent && AlertCount < 10 && TimeCurrent() - LastAlertTime >= 3600 && !OpenPositionsDrawdownAlertTriggered)
    {
        Alert("Open Positions Drawdown has reached the Maximum Open Positions Drawdown!");
        OpenPositionsDrawdownAlertTriggered = true;
        LastAlertTime = TimeCurrent();
        AlertCount++;
    }

    return (ratesTotal);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
{
    int currentOrdersCount = OrdersTotal();
    if (currentOrdersCount < previousOrdersCount)
    {
        MaxDailyBalance = GetMaxDailyAccountBalance();
    }
    previousOrdersCount = currentOrdersCount;

    if (CloseMostInLossTradeEnabled)
    {
        double maxLoss = 0.0;
        int maxLossTradeIndex = -1;
        for (int i = 0; i < OrdersTotal(); i++)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                if (OrderProfit() < maxLoss)
                {
                    maxLoss = OrderProfit();
                    maxLossTradeIndex = i;
                }
            }
        }
        if (maxLossTradeIndex != -1)
        {
            if (OrderSelect(maxLossTradeIndex, SELECT_BY_POS, MODE_TRADES))
            {
                if (OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 5))
                {
                    Print("Closed trade with ticket ", OrderTicket(), " in loss");
                }
                else
                {
                    Print("Failed to close trade with ticket ", OrderTicket(), " in loss: Error ", GetLastError());
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
