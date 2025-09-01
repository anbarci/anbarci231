package dnm

import (
	"fmt"
	"math"
	"time"

	"github.com/banbox/banbot/config"
	"github.com/banbox/banbot/core"
	"github.com/banbox/banbot/strat"
	ta "github.com/banbox/banta"
)

// Sadece grid_pro stratejisini ekle, mevcut fonksiyonları değiştirme
func init() {
	// Mevcut map'e sadece grid_pro'yu ekle
	if existingMap := strat.GetStratGroup("ma"); existingMap != nil {
		existingMap["grid_pro"] = GridPro
	}
}

// GridPro - Professional Grid Trading System
func GridPro(pol *config.RunPolicyConfig) *strat.TradeStrat {
	
	// Pine Script parametreleri
	enableGrid := bool(pol.Def("enable_grid", true))
	gridMode := string(pol.Def("grid_mode", "Fixed Spacing"))
	baseGridCount := int(pol.Def("base_grid_count", 8, core.PNorm(3, 15)))
	baseSpacingPct := float64(pol.Def("base_spacing_pct", 1.0, core.PNorm(0.2, 3.0)))
	atrPeriod := int(pol.Def("atr_period", 14, core.PNorm(5, 50)))
	atrMultiplier := float64(pol.Def("atr_multiplier", 1.5, core.PNorm(0.5, 3.0)))
	
	// Risk Management
	maxPortfolioRisk := float64(pol.Def("max_portfolio_risk", 15.0, core.PNorm(5.0, 30.0)))
	maxSinglePosition := float64(pol.Def("max_single_position", 5.0, core.PNorm(1.0, 10.0)))
	stopLossATR := float64(pol.Def("stop_loss_atr", 2.0, core.PNorm(1.0, 5.0)))
	takeProfitATR := float64(pol.Def("take_profit_atr", 3.0, core.PNorm(1.5, 8.0)))
	
	// Strategy state
	var gridBasePrice float64 = 0
	var gridInitialized bool = false
	var totalGridTrades int = 0
	var gridBuyLevels [8]float64
	var gridSellLevels [8]float64
	var gridLevelUsed [16]bool
	
	return &strat.TradeStrat{
		WarmupNum: 100,
		
		OnBar: func(s *strat.StratJob) {
			e := s.Env
			
			// Yeterli veri kontrolü
			if e.Close.Len() < atrPeriod {
				return
			}
			
			currentPrice := e.Close.Last(0)
			currentHigh := e.High.Last(0)
			currentLow := e.Low.Last(0)
			
			// Technical indicators
			atrValue := ta.ATR(e.High, e.Low, e.Close, atrPeriod)
			trendMA := ta.EMA(e.Close, 50)
			isUptrend := currentPrice > trendMA
			
			// Grid initialization
			if !gridInitialized && enableGrid {
				gridBasePrice = currentPrice
				gridInitialized = true
				s.Infof("Grid initialized at price: %.4f", gridBasePrice)
			}
			
			// Grid spacing calculation
			var spacing float64
			switch gridMode {
			case "Fixed Spacing":
				spacing = currentPrice * baseSpacingPct / 100
			case "ATR Based":
				spacing = atrValue * atrMultiplier
			default:
				spacing = atrValue * atrMultiplier
			}
			
			// Update grid levels
			if gridInitialized {
				for i := 0; i < baseGridCount && i < 8; i++ {
					gridBuyLevels[i] = gridBasePrice - (spacing * float64(i+1))
					gridSellLevels[i] = gridBasePrice + (spacing * float64(i+1))
				}
			}
			
			// Position size calculation
			accountEquity := 10000.0 // Gerçek hesaptan alınmalı
			basePositionSize := accountEquity * (maxSinglePosition / 100) / float64(baseGridCount)
			
			// Grid execution - Buy levels
			for i := 0; i < baseGridCount && i < 8; i++ {
				if !gridLevelUsed[i] && currentLow <= gridBuyLevels[i] {
					tag := fmt.Sprintf("GridBuy_%d", i+1)
					
					s.OpenOrder(&strat.EnterReq{
						Tag:    tag,
						Short:  false,
						Amount: basePositionSize,
					})
					
					gridLevelUsed[i] = true
					totalGridTrades++
					
					s.Infof("Grid Buy Level %d: %.4f (Size: %.2f)", i+1, gridBuyLevels[i], basePositionSize)
				}
			}
			
			// Grid execution - Sell levels
			for i := 0; i < baseGridCount && i < 8; i++ {
				levelIndex := i + 8
				if !gridLevelUsed[levelIndex] && currentHigh >= gridSellLevels[i] {
					tag := fmt.Sprintf("GridSell_%d", i+1)
					
					s.OpenOrder(&strat.EnterReq{
						Tag:    tag,
						Short:  true,
						Amount: basePositionSize,
					})
					
					gridLevelUsed[levelIndex] = true
					totalGridTrades++
					
					s.Infof("Grid Sell Level %d: %.4f (Size: %.2f)", i+1, gridSellLevels[i], basePositionSize)
				}
			}
			
			// Stop-loss and take-profit management
			manageTradingOrders(s, atrValue, stopLossATR, takeProfitATR)
			
			// Periodic status
			if e.BarIndex%50 == 0 {
				trend := "DOWN"
				if isUptrend {
					trend = "UP"
				}
				s.Infof("Grid Status: Price=%.4f, Base=%.4f, Trades=%d, Trend=%s", 
					currentPrice, gridBasePrice, totalGridTrades, trend)
			}
		},
	}
}

// Helper function for trade management
func manageTradingOrders(s *strat.StratJob, atrValue, stopLossATR, takeProfitATR float64) {
	// Long positions için stop-loss ve take-profit
	for _, order := range s.LongOrders {
		if order.Status == core.OdStatusFull {
			stopPrice := order.AvgPrice - (atrValue * stopLossATR)
			profitPrice := order.AvgPrice + (atrValue * takeProfitATR)
			
			currentPrice := s.Env.Close.Last(0)
			
			if currentPrice <= stopPrice {
				s.CloseOrders(&strat.ExitReq{
					Tag:    "stop_loss_" + order.Tag,
					Orders: []*core.Order{order},
				})
				s.Infof("Stop-loss triggered for %s at %.4f", order.Tag, currentPrice)
			} else if currentPrice >= profitPrice {
				s.CloseOrders(&strat.ExitReq{
					Tag:    "take_profit_" + order.Tag,
					Orders: []*core.Order{order},
				})
				s.Infof("Take-profit triggered for %s at %.4f", order.Tag, currentPrice)
			}
		}
	}
	
	// Short positions için stop-loss ve take-profit
	for _, order := range s.ShortOrders {
		if order.Status == core.OdStatusFull {
			stopPrice := order.AvgPrice + (atrValue * stopLossATR)
			profitPrice := order.AvgPrice - (atrValue * takeProfitATR)
			
			currentPrice := s.Env.Close.Last(0)
			
			if currentPrice >= stopPrice {
				s.CloseOrders(&strat.ExitReq{
					Tag:    "stop_loss_" + order.Tag,
					Orders: []*core.Order{order},
				})
				s.Infof("Stop-loss triggered for %s at %.4f", order.Tag, currentPrice)
			} else if currentPrice <= profitPrice {
				s.CloseOrders(&strat.ExitReq{
					Tag:    "take_profit_" + order.Tag,
					Orders: []*core.Order{order},
				})
				s.Infof("Take-profit triggered for %s at %.4f", order.Tag, currentPrice)
			}
		}
	}
}
