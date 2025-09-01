package dnm

import (
    "fmt"
    "math"
    "github.com/banbox/banbot/config"
    "github.com/banbox/banbot/core"
    "github.com/banbox/banbot/strat"
    ta "github.com/banbox/banta"
)

// Yalnızca grid stratejilerini ekleyin - mevcut fonksiyonları değiştirmeyin
func init() {
    // Yeni bir strateji grubu oluştur
    strat.AddStratGroup("gridpro", map[string]strat.FuncMakeStrat{
        "professional": ProfessionalGrid,
        "adaptive":     AdaptiveGrid,
        "fixed":        FixedGrid,
        "mp":           MarketProfileGrid,
    })
}

// Professional Grid Strategy - Pine Script uyarlaması
func ProfessionalGrid(pol *config.RunPolicyConfig) *strat.TradeStrat {
    // === GRID PARAMETERS ===
    enableGrid := pol.Def("enable_grid", 1, core.PNorm(0, 1)) > 0.5
    gridMode := int(pol.Def("grid_mode", 1, core.PNorm(1, 3))) // 1=Fixed, 2=ATR, 3=MP
    baseGridCount := int(pol.Def("base_grid_count", 8, core.PNorm(3, 15)))
    baseSpacingPct := pol.Def("base_spacing_pct", 1.0, core.PNorm(0.2, 3.0))
    atrPeriod := int(pol.Def("atr_period", 14, core.PNorm(5, 50)))
    atrMultiplier := pol.Def("atr_multiplier", 1.5, core.PNorm(0.5, 3.0))
    
    // === RISK MANAGEMENT ===
    maxPortfolioRisk := pol.Def("max_portfolio_risk", 15.0, core.PNorm(5.0, 30.0))
    maxSinglePosition := pol.Def("max_single_position", 5.0, core.PNorm(1.0, 10.0))
    maxConcurrentTrades := int(pol.Def("max_concurrent_trades", 8, core.PNorm(3, 20)))
    stopLossATR := pol.Def("stop_loss_atr", 2.0, core.PNorm(1.0, 5.0))
    takeProfitATR := pol.Def("take_profit_atr", 3.0, core.PNorm(1.5, 8.0))
    
    // === ADVANCED FEATURES ===
    enableVolatilityFilter := pol.Def("enable_volatility_filter", 1, core.PNorm(0, 1)) > 0.5
    volatilityThreshold := pol.Def("volatility_threshold", 2.0, core.PNorm(1.0, 5.0))
    enableTrendFilter := pol.Def("enable_trend_filter", 1, core.PNorm(0, 1)) > 0.5
    trendPeriod := int(pol.Def("trend_period", 50, core.PNorm(20, 200)))

    return &strat.TradeStrat{
        WarmupNum: 200,
        StopEnterBars: 999999, // Grid sürekli aktif
        
        OnStartUp: func(s *strat.StratJob) {
            // Grid durumu başlat
            s.SetVar("grid_base_price", 0.0)
            s.SetVar("grid_initialized", false)
            s.SetVar("total_grid_trades", 0)
            s.SetVar("grid_levels", make(map[string]GridLevel))
            s.SetVar("can_trade", true)
            s.SetVar("portfolio_risk", 0.0)
        },
        
        OnBar: func(s *strat.StratJob) {
            e := s.Env
            if e.Close.Len() < 200 {
                return
            }
            
            currentPrice := e.Close.Get(0)
            currentHigh := e.High.Get(0)
            currentLow := e.Low.Get(0)
            
            // Değişkenleri al
            gridBasePrice := s.GetVar("grid_base_price").(float64)
            gridInitialized := s.GetVar("grid_initialized").(bool)
            totalGridTrades := s.GetVar("total_grid_trades").(int)
            gridLevels := s.GetVar("grid_levels").(map[string]GridLevel)
            canTrade := s.GetVar("can_trade").(bool)
            
            // === TECHNICAL INDICATORS ===
            atr := ta.ATR(e.High, e.Low, e.Close, atrPeriod)
            if atr.Len() == 0 {
                return
            }
            atrValue := atr.Get(0)
            
            // Trend analizi
            trendMA := ta.EMA(e.Close, trendPeriod)
            if trendMA.Len() == 0 {
                return
            }
            isUpTrend := currentPrice > trendMA.Get(0)
            trendStrength := (currentPrice - trendMA.Get(0)) / trendMA.Get(0) * 100
            
            // Volatilite analizi
            atrSeries := ta.ATR(e.High, e.Low, e.Close, atrPeriod)
            atrMA := ta.SMA(atrSeries, 20)
            if atrMA.Len() == 0 {
                return
            }
            volatilityRegime := atrValue / atrMA.Get(0)
            isHighVolatility := volatilityRegime > volatilityThreshold
            
            // RSI ve market stress
            rsi := ta.RSI(e.Close, 14)
            if rsi.Len() == 0 {
                return
            }
            rsiValue := rsi.Get(0)
            
            // Bollinger Bands (düzeltilmiş)
            bbUpper := ta.SMA(e.Close, 20)
            bbStd := ta.STDDEV(e.Close, 20)
            if bbStd.Len() == 0 {
                return
            }
            upperBand := bbUpper.Get(0) + (2.0 * bbStd.Get(0))
            lowerBand := bbUpper.Get(0) - (2.0 * bbStd.Get(0))
            bbSqueeze := (upperBand - lowerBand) / bbUpper.Get(0) < 0.05
            
            marketStress := bbSqueeze || (rsiValue > 80 || rsiValue < 20)
            
            // NaN kontrolleri
            if math.IsNaN(atrValue) || math.IsNaN(trendMA.Get(0)) || 
               math.IsNaN(rsiValue) || math.IsNaN(upperBand) || math.IsNaN(lowerBand) {
                return
            }
            
            // === TRADING STATE CALCULATION ===
            canTrade = true
            restrictionReason := ""
            
            // Risk kontrolleri
            currentPortfolioRisk := calculatePortfolioRisk(s)
            activeTrades := len(s.LongOrders) + len(s.ShortOrders)
            
            if currentPortfolioRisk > maxPortfolioRisk {
                canTrade = false
                restrictionReason += "Portfolio risk exceeded. "
            }
            
            if activeTrades >= maxConcurrentTrades {
                canTrade = false
                restrictionReason += "Max concurrent trades reached. "
            }
            
            if enableVolatilityFilter && isHighVolatility {
                canTrade = false
                restrictionReason += "High volatility detected. "
            }
            
            if enableTrendFilter && gridMode == 3 && math.Abs(trendStrength) > 5 {
                canTrade = false
                restrictionReason += "Strong trend detected. "
            }
            
            if marketStress {
                canTrade = false
                restrictionReason += "Market stress detected. "
            }
            
            // === GRID INITIALIZATION ===
            if !gridInitialized && enableGrid && canTrade {
                gridBasePrice = currentPrice
                gridInitialized = true
                
                // Grid seviyelerini oluştur
                gridLevels = createGridLevels(gridBasePrice, baseGridCount, 
                                            getGridSpacing(gridMode, currentPrice, atrValue, 
                                            baseSpacingPct, atrMultiplier))
                
                s.Infof("Professional Grid initialized at %.4f with %d levels", 
                       gridBasePrice, len(gridLevels))
            }
            
            // === GRID REBALANCING ===
            if shouldRebalanceGrid(gridBasePrice, currentPrice, baseSpacingPct, baseGridCount) {
                // Tüm pozisyonları kapat
                if len(s.LongOrders) > 0 {
                    s.CloseOrders(&strat.ExitReq{
                        Tag: "grid_rebalance_long",
                        Dirt: core.OdDirtLong,
                    })
                }
                if len(s.ShortOrders) > 0 {
                    s.CloseOrders(&strat.ExitReq{
                        Tag: "grid_rebalance_short", 
                        Dirt: core.OdDirtShort,
                    })
                }
                
                // Yeni grid base price
                gridBasePrice = currentPrice
                gridLevels = createGridLevels(gridBasePrice, baseGridCount,
                                            getGridSpacing(gridMode, currentPrice, atrValue,
                                            baseSpacingPct, atrMultiplier))
                
                s.Infof("Grid rebalanced at %.4f", gridBasePrice)
            }
            
            // === GRID EXECUTION ===
            if enableGrid && canTrade && gridInitialized && len(gridLevels) > 0 {
                basePositionSize := calculatePositionSize(maxSinglePosition, baseGridCount)
                
                // Grid seviyelerini kontrol et
                for levelName, level := range gridLevels {
                    if level.Active && !level.Executed {
                        if level.Type == "buy" && currentLow <= level.Price {
                            // Buy order
                            stopLoss := level.Price - (atrValue * stopLossATR)
                            takeProfit := level.Price + (atrValue * takeProfitATR)
                            
                            err := s.OpenOrder(&strat.EnterReq{
                                Tag:        fmt.Sprintf("GridBuy_%s", levelName),
                                StopLoss:   stopLoss,
                                TakeProfit: takeProfit,
                                CostRate:   basePositionSize,
                            })
                            
                            if err == nil {
                                level.Executed = true
                                gridLevels[levelName] = level
                                totalGridTrades++
                                s.Infof("Grid Buy executed: %s at %.4f", levelName, level.Price)
                            }
                            
                        } else if level.Type == "sell" && currentHigh >= level.Price {
                            // Sell order (sadece futures için)
                            if core.Market != core.MarketSpot {
                                stopLoss := level.Price + (atrValue * stopLossATR)
                                takeProfit := level.Price - (atrValue * takeProfitATR)
                                
                                err := s.OpenOrder(&strat.EnterReq{
                                    Tag:        fmt.Sprintf("GridSell_%s", levelName),
                                    Short:      true,
                                    StopLoss:   stopLoss,
                                    TakeProfit: takeProfit,
                                    CostRate:   basePositionSize,
                                })
                                
                                if err == nil {
                                    level.Executed = true
                                    gridLevels[levelName] = level
                                    totalGridTrades++
                                    s.Infof("Grid Sell executed: %s at %.4f", levelName, level.Price)
                                }
                            }
                        }
                    }
                }
            }
            
            // === PERIODIC STATUS ===
            if e.BarIndex%100 == 0 {
                trend := "DOWN"
                if isUpTrend {
                    trend = "UP"
                }
                s.Infof("Grid Status: Price=%.4f, Base=%.4f, Trades=%d, Trend=%s, Risk=%.2f%%, CanTrade=%v", 
                       currentPrice, gridBasePrice, totalGridTrades, trend, currentPortfolioRisk, canTrade)
                
                if !canTrade && restrictionReason != "" {
                    s.Infof("Trading suspended: %s", restrictionReason)
                }
            }
            
            // Değişkenleri kaydet
            s.SetVar("grid_base_price", gridBasePrice)
            s.SetVar("grid_initialized", gridInitialized)
            s.SetVar("total_grid_trades", totalGridTrades)
            s.SetVar("grid_levels", gridLevels)
            s.SetVar("can_trade", canTrade)
            s.SetVar("portfolio_risk", currentPortfolioRisk)
        },
        
        OnCheckExit: func(s *strat.StratJob, od *core.Order) *strat.ExitReq {
            // Market stress durumunda pozisyon kapat
            if marketStress := s.GetVar("market_stress"); marketStress != nil && marketStress.(bool) {
                return &strat.ExitReq{
                    Tag:      "market_stress_exit",
                    ExitRate: 0.5, // %50 kapat
                }
            }
            
            // Risk limiti aşılırsa
            if portfolioRisk := s.GetVar("portfolio_risk"); portfolioRisk != nil {
                if portfolioRisk.(float64) > maxPortfolioRisk*0.9 {
                    return &strat.ExitReq{
                        Tag:      "risk_limit_exit",
                        ExitRate: 0.3, // %30 kapat
                    }
                }
            }
            
            return nil
        },
    }
}

// === GRID STRUCTURES ===
type GridLevel struct {
    Price    float64
    Type     string // "buy" or "sell"
    Level    int
    Active   bool
    Executed bool
}

// === HELPER FUNCTIONS ===

// Grid spacing hesaplama
func getGridSpacing(gridMode int, currentPrice, atrValue, baseSpacingPct, atrMultiplier float64) float64 {
    switch gridMode {
    case 1: // Fixed Spacing
        return currentPrice * baseSpacingPct / 100
    case 2: // ATR Based
        return atrValue * atrMultiplier
    case 3: // Market Profile Adaptive (basitleştirilmiş)
        return atrValue * atrMultiplier * 1.2
    default:
        return atrValue * atrMultiplier
    }
}

// Grid seviyelerini oluştur
func createGridLevels(basePrice float64, gridCount int, spacing float64) map[string]GridLevel {
    levels := make(map[string]GridLevel)
    
    // Buy seviyelerini oluştur (fiyat düştükçe)
    for i := 1; i <= gridCount; i++ {
        levelName := fmt.Sprintf("B%d", i)
        levels[levelName] = GridLevel{
            Price:    basePrice - (spacing * float64(i)),
            Type:     "buy",
            Level:    i,
            Active:   true,
            Executed: false,
        }
    }
    
    // Sell seviyelerini oluştur (fiyat yükseldikçe)
    for i := 1; i <= gridCount; i++ {
        levelName := fmt.Sprintf("S%d", i)
        levels[levelName] = GridLevel{
            Price:    basePrice + (spacing * float64(i)),
            Type:     "sell",
            Level:    i,
            Active:   true,
            Executed: false,
        }
    }
    
    return levels
}

// Grid yeniden dengeleme gerekli mi?
func shouldRebalanceGrid(gridBase, currentPrice, baseSpacingPct float64, baseGridCount int) bool {
    if gridBase == 0 {
        return false
    }
    
    priceDeviation := math.Abs(currentPrice-gridBase) / gridBase * 100
    maxDeviation := baseSpacingPct * float64(baseGridCount) * 1.5
    
    return priceDeviation > maxDeviation
}

// Position size hesaplama
func calculatePositionSize(maxSinglePosition float64, baseGridCount int) float64 {
    baseSize := maxSinglePosition / 100 / float64(baseGridCount)
    return math.Max(0.01, math.Min(0.1, baseSize))
}

// Portfolio risk hesaplama (basitleştirilmiş)
func calculatePortfolioRisk(s *strat.StratJob) float64 {
    totalPositions := len(s.LongOrders) + len(s.ShortOrders)
    return float64(totalPositions) * 2.0 // Her pozisyon %2 risk varsayımı
}

// === ADDITIONAL STRATEGIES ===

// Adaptive Grid Strategy
func AdaptiveGrid(pol *config.RunPolicyConfig) *strat.TradeStrat {
    base := ProfessionalGrid(pol)
    // Adaptive özellikler eklenebilir
    return base
}

// Fixed Grid Strategy
func FixedGrid(pol *config.RunPolicyConfig) *strat.TradeStrat {
    spacing := pol.Def("spacing", 1.0, core.PNorm(0.5, 3.0))
    levels := int(pol.Def("levels", 5, core.PNorm(3, 10)))
    
    return &strat.TradeStrat{
        WarmupNum: 50,
        
        OnBar: func(s *strat.StratJob) {
            e := s.Env
            if e.Close.Len() < 50 {
                return
            }
            
            currentPrice := e.Close.Get(0)
            gridSpacing := currentPrice * spacing / 100
            
            // Basit grid mantığı
            for i := 1; i <= levels; i++ {
                buyLevel := currentPrice - (gridSpacing * float64(i))
                if e.Low.Get(0) <= buyLevel {
                    tag := fmt.Sprintf("FixedBuy_%d", i)
                    if !hasActiveOrder(s, tag) {
                        s.OpenOrder(&strat.EnterReq{
                            Tag: tag,
                            TakeProfit: currentPrice + (gridSpacing * float64(i)),
                        })
                    }
                }
            }
        },
    }
}

// Market Profile Grid Strategy
func MarketProfileGrid(pol *config.RunPolicyConfig) *strat.TradeStrat {
    return &strat.TradeStrat{
        WarmupNum: 100,
        
        OnBar: func(s *strat.StratJob) {
            e := s.Env
            if e.Close.Len() < 100 {
                return
            }
            
            // VWAP kullanarak basit MP grid
            vwap := ta.VWAP(e.High, e.Low, e.Close, e.Volume)
            if vwap.Len() == 0 {
                return
            }
            
            currentPrice := e.Close.Get(0)
            vwapValue := vwap.Get(0)
            atr := ta.ATR(e.High, e.Low, e.Close, 14).Get(0)
            
            if math.IsNaN(vwapValue) || math.IsNaN(atr) {
                return
            }
            
            // VWAP etrafında grid
            if currentPrice < vwapValue-atr && len(s.LongOrders) < 3 {
                s.OpenOrder(&strat.EnterReq{
                    Tag: "MPBuy",
                    TakeProfit: vwapValue + atr,
                })
            }
        },
    }
}

// Yardımcı fonksiyon
func hasActiveOrder(s *strat.StratJob, tag string) bool {
    for _, order := range s.LongOrders {
        if order.EnterTag == tag {
            return true
        }
    }
    for _, order := range s.ShortOrders {
        if order.EnterTag == tag {
            return true
        }
    }
    return false
}
