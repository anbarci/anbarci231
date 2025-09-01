package ma

import (
	"fmt"
	"math"
	"time"

	"github.com/banbox/banbot/config"
	"github.com/banbox/banbot/core"
	"github.com/banbox/banbot/strat"
	ta "github.com/banbox/banta"
)

func init() {
	// Grid Pro stratejisini ma grubuna ekle
	strat.AddStratGroup("ma", map[string]strat.FuncMakeStrat{
		"demo":       Demo,
		"demo_er":    DemoER,
		"demo2":      DemoInfo,
		"demo_batch": BatchDemo,
		"demo_exit":  CustomExitDemo,
		"edit_pairs": editPairs,
		"ws":         ws,
		"postApi":    PostApi,
		"grid_pro":   GridPro, // YENİ STRATEJİ EKLENDİ
	})
}

// GridPro - Professional Grid Trading System with Market Profile
func GridPro(pol *config.RunPolicyConfig) *strat.TradeStrat {
	
	// Pine Script input parametrelerini Banbot formatına çevir
	enableGrid := bool(pol.Def("enable_grid", true))
	gridMode := string(pol.Def("grid_mode", "Fixed Spacing"))
	baseGridCount := int(pol.Def("base_grid_count", 8, core.PNorm(3, 15)))
	baseSpacingPct := float64(pol.Def("base_spacing_pct", 1.0, core.PNorm(0.2, 3.0)))
	atrPeriod := int(pol.Def("atr_period", 14, core.PNorm(5, 50)))
	atrMultiplier := float64(pol.Def("atr_multiplier", 1.5, core.PNorm(0.5, 3.0)))
	
	// Risk Management
	enableAdvancedRisk := bool(pol.Def("enable_advanced_risk", true))
	maxPortfolioRisk := float64(pol.Def("max_portfolio_risk", 15.0, core.PNorm(5.0, 30.0)))
	maxSinglePosition := float64(pol.Def("max_single_position", 5.0, core.PNorm(1.0, 10.0)))
	maxConcurrentTrades := int(pol.Def("max_concurrent_trades", 8, core.PNorm(3, 20)))
	stopLossATR := float64(pol.Def("stop_loss_atr", 2.0, core.PNorm(1.0, 5.0)))
	takeProfitATR := float64(pol.Def("take_profit_atr", 3.0, core.PNorm(1.5, 8.0)))
	
	// Market Profile
	enableMarketProfile := bool(pol.Def("enable_market_profile", true))
	mpTPOPercent := float64(pol.Def("mp_tpo_percent", 70.0, core.PNorm(50.0, 90.0)))
	
	// Advanced Features
	enableVolatilityFilter := bool(pol.Def("enable_volatility_filter", true))
	volatilityThreshold := float64(pol.Def("volatility_threshold", 2.0, core.PNorm(1.0, 5.0)))
	enableTrendFilter := bool(pol.Def("enable_trend_filter", true))
	trendPeriod := int(pol.Def("trend_period", 50, core.PNorm(20, 200)))
	
	// Strategy variables (Pine Script var equivalent)
	var gridBasePrice float64 = 0
	var gridInitialized bool = false
	var totalGridTrades int = 0
	var cumulativeGridPNL float64 = 0
	
	// Market Profile variables
	var mpPOCPrice float64 = 0
	var mpVAHPrice float64 = 0
	var mpVALPrice float64 = 0
	var mpVARangePct float64 = 0
	var mpIsValid bool = false
	
	// Risk metrics
	var currentPortfolioRisk float64 = 0
	var largestPositionRisk float64 = 0
	var activeTradesCount int = 0
	var dailyPNL float64 = 0
	var winRate float64 = 0
	
	// Trading state
	var canTrade bool = true
	var restrictionReason string = ""
	var basePositionSize float64 = 0
	var volatilityAdjustment float64 = 1.0
	var marketStressDetected bool = false
	
	// Grid levels (8 seviye)
	var gridBuyLevels [8]float64
	var gridSellLevels [8]float64
	var gridLevelUsed [16]bool // 8 buy + 8 sell
	
	// Session tracking for Market Profile
	var sessionHigh float64 = 0
	var sessionLow float64 = 0
	var sessionBars int = 0
	var lastSessionTime int64 = 0
	
	return &strat.TradeStrat{
		WarmupNum: 200, // Pine Script max_bars_back=2000 benzeri
		
		OnBar: func(s *strat.StratJob) {
			e := s.Env
			
			// Pine Script'teki close, high, low, open değerleri
			currentPrice := e.Close.Last(0)
			currentHigh := e.High.Last(0)
			currentLow := e.Low.Last(0)
			currentTime := e.BarTime
			
			// Yeterli veri var mı kontrol et
			if e.Close.Len() < trendPeriod {
				return
			}
			
			// Technical Indicators (Pine Script ta.* fonksiyonları)
			atrValue := ta.ATR(e.High, e.Low, e.Close, atrPeriod)
			atrNormalized := atrValue / currentPrice * 100
			trendMA := ta.EMA(e.Close, trendPeriod)
			isUptrend := currentPrice > trendMA
			trendStrength := (currentPrice - trendMA) / trendMA * 100
			
			// Volatility calculation
			volatilityMA := calculateVolatilityMA(e, 20, atrPeriod)
			volatilityRegime := atrNormalized / volatilityMA
			isHighVolatility := volatilityRegime > volatilityThreshold
			
			// RSI ve Bollinger Bands (market stress detection)
			rsiValue := ta.RSI(e.Close, 14)
			bbUpper, bbMiddle, bbLower := ta.BOLL(e.Close, 20, 2.0)
			bbSqueeze := (bbUpper-bbLower)/ta.SMA(e.Close, 20) < 0.05
			
			// Market Profile güncelle
			updateMarketProfile(e, currentHigh, currentLow, currentPrice, currentTime, 
				&sessionHigh, &sessionLow, &sessionBars, &lastSessionTime, 
				&mpPOCPrice, &mpVAHPrice, &mpVALPrice, &mpVARangePct, &mpIsValid, 
				enableMarketProfile, mpTPOPercent)
			
			// Risk metrics güncelle
			updateRiskMetrics(s, maxSinglePosition, baseGridCount,
				&currentPortfolioRisk, &largestPositionRisk, &activeTradesCount, 
				&dailyPNL, &winRate, &basePositionSize)
			
			// Trading state güncelle
			updateTradingState(enableAdvancedRisk, maxPortfolioRisk, maxSinglePosition, 
				maxConcurrentTrades, enableVolatilityFilter, isHighVolatility,
				enableTrendFilter, gridMode, trendStrength, rsiValue, bbSqueeze,
				currentPortfolioRisk, largestPositionRisk, activeTradesCount,
				&canTrade, &restrictionReason, &volatilityAdjustment, &marketStressDetected)
			
			// Grid initialize (Pine Script'teki grid initialization mantığı)
			if !gridInitialized && enableGrid && canTrade {
				if enableMarketProfile && mpIsValid && mpPOCPrice > 0 {
					gridBasePrice = mpPOCPrice
				} else {
					gridBasePrice = currentPrice
				}
				gridInitialized = true
				s.Infof("Professional Grid Bot Initialized - Mode: %s - Base Price: %.4f", gridMode, gridBasePrice)
			}
			
			// Grid levels güncelle
			if enableGrid && canTrade && gridInitialized {
				spacing := calculateGridSpacing(currentPrice, atrValue, gridMode, baseSpacingPct, atrMultiplier, 
					mpVAHPrice, mpVALPrice, mpIsValid)
				updateGridLevels(gridBasePrice, spacing, baseGridCount, &gridBuyLevels, &gridSellLevels)
			}
			
			// Grid execution (Pine Script'teki crossunder/crossover mantığı)
			if enableGrid && canTrade && gridInitialized {
				executeGridTrades(s, e, currentPrice, currentHigh, currentLow, atrValue, 
					basePositionSize, volatilityAdjustment, stopLossATR, takeProfitATR,
					baseGridCount, &gridBuyLevels, &gridSellLevels, &gridLevelUsed, &totalGridTrades)
			}
			
			// Grid rebalancing check
			if shouldRebalanceGrid(currentPrice, gridBasePrice, gridInitialized, enableGrid,
				baseSpacingPct, baseGridCount, enableMarketProfile, mpIsValid, mpPOCPrice) {
				
				s.Infof("Grid Rebalancing triggered at price: %.4f", currentPrice)
				s.CloseOrders(&strat.ExitReq{Tag: "grid_rebalance", ExitRate: 1.0})
				
				// Reset grid
				for i := range gridLevelUsed {
					gridLevelUsed[i] = false
				}
				
				// Reinitialize
				if enableMarketProfile && mpIsValid && mpPOCPrice > 0 {
					gridBasePrice = mpPOCPrice
				} else {
					gridBasePrice = currentPrice
				}
				gridInitialized = true
			}
			
			// Periodic status logging (Pine Script table benzeri)
			if e.BarIndex%100 == 0 {
				logGridStatus(s, currentPrice, atrValue, isUptrend, canTrade, restrictionReason,
					gridInitialized, gridMode, totalGridTrades, currentPortfolioRisk, 
					activeTradesCount, winRate, mpPOCPrice, mpVARangePct, mpIsValid, dailyPNL)
			}
		},
	}
}

// Helper functions (Pine Script functions benzeri)

func calculateVolatilityMA(e *strat.StratEnv, period, atrPeriod int) float64 {
	if e.Close.Len() < period {
		return 1.0
	}
	
	sum := 0.0
	for i := 0; i < period; i++ {
		atr := ta.ATR(e.High, e.Low, e.Close, atrPeriod)
		normalized := atr / e.Close.Last(i) * 100
		sum += normalized
	}
	return sum / float64(period)
}

func updateMarketProfile(e *strat.StratEnv, high, low, close float64, currentTime int64,
	sessionHigh, sessionLow *float64, sessionBars *int, lastSessionTime *int64,
	pocPrice, vahPrice, valPrice, vaRangePct *float64, isValid *bool,
	enableMP bool, tpoPercent float64) {
	
	if !enableMP {
		return
	}
	
	// Pine Script session_changed mantığı
	currentDay := time.Unix(currentTime, 0).Day()
	lastDay := time.Unix(*lastSessionTime, 0).Day()
	
	if currentDay != lastDay || *sessionBars == 0 {
		// New session (Pine Script ta.change(time("D")) != 0 benzeri)
		*sessionHigh = high
		*sessionLow = low
		*sessionBars = 1
		*lastSessionTime = currentTime
	} else {
		// Update session data
		*sessionHigh = math.Max(*sessionHigh, high)
		*sessionLow = math.Min(*sessionLow, low)
		*sessionBars++
	}
	
	// Market Profile calculation (Pine Script get_market_profile_data() benzeri)
	if *sessionBars > 10 {
		sessionRange := *sessionHigh - *sessionLow
		if sessionRange <= 0 {
			return
		}
		
		tpoSize := sessionRange / 20
		tpoCounts := make([]int, 20)
		
		// TPO frequency calculation
		maxBars := int(math.Min(float64(*sessionBars), float64(e.Close.Len())))
		for i := 0; i < maxBars; i++ {
			price := e.Close.Last(i)
			tpoIndex := int((*sessionHigh - price) / tpoSize)
			if tpoIndex >= 0 && tpoIndex < 20 {
				tpoCounts[tpoIndex]++
			}
		}
		
		// Find POC (Point of Control)
		maxCount := 0
		pocIndex := 0
		for i, count := range tpoCounts {
			if count > maxCount {
				maxCount = count
				pocIndex = i
			}
		}
		
		*pocPrice = *sessionHigh - (tpoSize * (float64(pocIndex) + 0.5))
		
		// Calculate Value Area (Pine Script while loop benzeri)
		totalTPO := 0
		for _, count := range tpoCounts {
			totalTPO += count
		}
		
		targetTPO := float64(totalTPO) * (tpoPercent / 100.0)
		currentTPO := float64(maxCount)
		vahIndex := pocIndex
		valIndex := pocIndex
		
		for currentTPO < targetTPO && (vahIndex > 0 || valIndex < 19) {
			vahCandidate := 0
			valCandidate := 0
			
			if vahIndex > 0 {
				vahCandidate = tpoCounts[vahIndex-1]
			}
			if valIndex < 19 {
				valCandidate = tpoCounts[valIndex+1]
			}
			
			if vahCandidate >= valCandidate && vahIndex > 0 {
				vahIndex--
				currentTPO += float64(vahCandidate)
			} else if valIndex < 19 {
				valIndex++
				currentTPO += float64(valCandidate)
			} else {
				break
			}
		}
		
		*vahPrice = *sessionHigh - (tpoSize * float64(vahIndex))
		*valPrice = *sessionHigh - (tpoSize * float64(valIndex+1))
		*vaRangePct = (*vahPrice - *valPrice) / *valPrice * 100
		*isValid = true
	}
}

func updateRiskMetrics(s *strat.StratJob, maxSinglePosition float64, baseGridCount int,
	portfolioRisk, largestPosRisk *float64, activeTradesCount *int, 
	dailyPNL, winRate, basePositionSize *float64) {
	
	// Pine Script get_risk_metrics() benzeri
	totalExposure := 0.0
	largestPosition := 0.0
	activePositions := 0
	
	// Banbot'ta açık pozisyonları kontrol et
	if len(s.LongOrders) > 0 || len(s.ShortOrders) > 0 {
		// Approximate calculation
		for _, order := range s.LongOrders {
			positionValue := order.Amount * order.AvgPrice
			totalExposure += positionValue
			largestPosition = math.Max(largestPosition, positionValue)
			activePositions++
		}
		for _, order := range s.ShortOrders {
			positionValue := math.Abs(order.Amount * order.AvgPrice)
			totalExposure += positionValue
			largestPosition = math.Max(largestPosition, positionValue)
			activePositions++
		}
	}
	
	// Account equity simulation (Pine Script strategy.equity benzeri)
	accountEquity := 10000.0 // Bu değer gerçek hesap bilgisinden alınmalı
	
	*portfolioRisk = totalExposure / accountEquity * 100
	*largestPosRisk = largestPosition / accountEquity * 100
	*activeTradesCount = activePositions
	
	// Base position size calculation
	*basePositionSize = accountEquity * (maxSinglePosition / 100) / float64(baseGridCount)
	
	// Win rate calculation (Pine Script strategy.wintrades/total_trades benzeri)
	// Bu basitleştirilmiş bir hesaplama - gerçekte daha karmaşık olmalı
	*winRate = 65.0 // Placeholder değer
	*dailyPNL = 0.0  // Placeholder değer
}

func updateTradingState(enableAdvancedRisk bool, maxPortfolioRisk, maxSinglePosition float64,
	maxConcurrentTrades int, enableVolatilityFilter, isHighVolatility, enableTrendFilter bool,
	gridMode string, trendStrength, rsiValue float64, bbSqueeze bool,
	currentPortfolioRisk, largestPositionRisk float64, activeTradesCount int,
	canTrade *bool, restrictionReason *string, volatilityAdjustment *float64, marketStressDetected *bool) {
	
	// Pine Script get_trading_state() benzeri
	*canTrade = true
	*restrictionReason = ""
	
	if enableAdvancedRisk {
		if currentPortfolioRisk > maxPortfolioRisk {
			*canTrade = false
			*restrictionReason += "Portfolio risk exceeded. "
		}
		if largestPositionRisk > maxSinglePosition {
			*canTrade = false
			*restrictionReason += "Single position risk exceeded. "
		}
		if activeTradesCount >= maxConcurrentTrades {
			*canTrade = false
			*restrictionReason += "Max concurrent trades reached. "
		}
	}
	
	if enableVolatilityFilter && isHighVolatility {
		*canTrade = false
		*restrictionReason += "High volatility detected. "
	}
	
	if enableTrendFilter && gridMode == "Market Profile Adaptive" {
		if math.Abs(trendStrength) > 5.0 {
			*canTrade = false
			*restrictionReason += "Strong trend detected. "
		}
	}
	
	// Market stress detection (Pine Script bb_squeeze or rsi conditions)
	*marketStressDetected = bbSqueeze || (rsiValue > 80 || rsiValue < 20)
	if *marketStressDetected {
		*volatilityAdjustment = 0.5
	} else {
		*volatilityAdjustment = 1.0
	}
}

func calculateGridSpacing(currentPrice, atrValue float64, gridMode string, baseSpacingPct, atrMultiplier,
	vahPrice, valPrice float64, mpIsValid bool) float64 {
	
	// Pine Script get_grid_spacing() benzeri
	switch gridMode {
	case "Fixed Spacing":
		return currentPrice * baseSpacingPct / 100
	case "ATR Based":
		return atrValue * atrMultiplier
	case "Market Profile Adaptive":
		if mpIsValid {
			vaRange := vahPrice - valPrice
			return math.Max(atrValue, vaRange/4)
		}
		return atrValue * atrMultiplier
	default:
		return atrValue * atrMultiplier
	}
}

func updateGridLevels(gridBasePrice, spacing float64, baseGridCount int,
	buyLevels, sellLevels *[8]float64) {
	
	// Pine Script grid level calculation benzeri
	for i := 0; i < baseGridCount && i < 8; i++ {
		buyLevels[i] = gridBasePrice - (spacing * float64(i+1))
		sellLevels[i] = gridBasePrice + (spacing * float64(i+1))
	}
}

func executeGridTrades(s *strat.StratJob, e *strat.StratEnv, currentPrice, currentHigh, currentLow, atrValue,
	basePositionSize, volatilityAdjustment, stopLossATR, takeProfitATR float64,
	baseGridCount int, buyLevels, sellLevels *[8]float64, levelUsed *[16]bool, totalGridTrades *int) {
	
	// Pine Script grid execution mantığı (crossunder/crossover benzeri)
	
	// Buy level executions (ta.crossunder(low, level_buy) benzeri)
	for i := 0; i < baseGridCount && i < 8; i++ {
		if !levelUsed[i] && currentLow <= buyLevels[i] {
			adjustedSize := basePositionSize * volatilityAdjustment
			tag := fmt.Sprintf("GridBuy_%d", i+1)
			
			s.OpenOrder(&strat.EnterReq{
				Tag:    tag,
				Short:  false,
				Amount: adjustedSize,
			})
			
			levelUsed[i] = true
			*totalGridTrades++
			
			s.Infof("Grid Buy Level %d executed: Price=%.4f, Size=%.4f", 
				i+1, buyLevels[i], adjustedSize)
		}
	}
	
	// Sell level executions (ta.crossover(high, level_sell) benzeri)
	for i := 0; i < baseGridCount && i < 8; i++ {
		levelIndex := i + 8 // Offset for sell levels
		if !levelUsed[levelIndex] && currentHigh >= sellLevels[i] {
			adjustedSize := basePositionSize * volatilityAdjustment
			tag := fmt.Sprintf("GridSell_%d", i+1)
			
			s.OpenOrder(&strat.EnterReq{
				Tag:    tag,
				Short:  true,
				Amount: adjustedSize,
			})
			
			levelUsed[levelIndex] = true
			*totalGridTrades++
			
			s.Infof("Grid Sell Level %d executed: Price=%.4f, Size=%.4f", 
				i+1, sellLevels[i], adjustedSize)
		}
	}
}

func shouldRebalanceGrid(currentPrice, gridBasePrice float64, gridInitialized, enableGrid bool,
	baseSpacingPct float64, baseGridCount int, enableMarketProfile, mpIsValid bool, mpPOCPrice float64) bool {
	
	// Pine Script should_rebalance_grid() benzeri
	if !enableGrid || !gridInitialized {
		return false
	}
	
	// Price deviation check
	priceDeviation := math.Abs(currentPrice-gridBasePrice) / gridBasePrice * 100
	maxDeviation := baseSpacingPct * float64(baseGridCount) * 1.5
	
	if priceDeviation > maxDeviation {
		return true
	}
	
	// POC deviation check
	if enableMarketProfile && mpIsValid && mpPOCPrice > 0 {
		pocDeviation := math.Abs(mpPOCPrice-gridBasePrice) / gridBasePrice * 100
		if pocDeviation > 3.0 {
			return true
		}
	}
	
	return false
}

func logGridStatus(s *strat.StratJob, currentPrice, atrValue float64, isUptrend, canTrade bool,
	restrictionReason string, gridInitialized bool, gridMode string, totalGridTrades int,
	portfolioRisk float64, activeTradesCount int, winRate, pocPrice, vaRangePct float64,
	mpIsValid bool, dailyPNL float64) {
	
	// Pine Script statistics table benzeri logging
	trend := "DOWN"
	if isUptrend {
		trend = "UP"
	}
	
	status := "ACTIVE"
	if !canTrade {
		status = "INACTIVE"
	}
	
	s.Infof("=== PROFESSIONAL GRID BOT STATUS ===")
	s.Infof("Grid Status: %s | Mode: %s | Base Price: %.4f", status, gridMode, currentPrice)
	s.Infof("Grid Trades: %d | Portfolio Risk: %.1f%% | Active Trades: %d", 
		totalGridTrades, portfolioRisk, activeTradesCount)
	s.Infof("Current Price: %.4f | ATR: %.4f | Trend: %s | Win Rate: %.1f%%", 
		currentPrice, atrValue, trend, winRate)
	
	if mpIsValid {
		s.Infof("Market Profile - POC: %.4f | VA Range: %.2f%%", pocPrice, vaRangePct)
	}
	
	if !canTrade && restrictionReason != "" {
		s.Infof("Trading Restricted: %s", restrictionReason)
	}
	
	s.Infof("========================================")
}
