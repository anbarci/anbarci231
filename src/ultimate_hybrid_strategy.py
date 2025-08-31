import logging
import pandas as pd
import numpy as np
from decimal import Decimal
from typing import Dict, List, Optional, Set
from datetime import datetime, timezone, time, timedelta

from hummingbot.strategy.script_strategy_base import ScriptStrategyBase
from hummingbot.core.data_type.common import OrderType, PriceType, PositionMode
from hummingbot.core.data_type.limit_order import LimitOrder
from hummingbot.core.event.events import (
    BuyOrderCreatedEvent,
    SellOrderCreatedEvent,
    OrderFilledEvent,
    MarketOrderFailureEvent,
    OrderCancelledEvent,
    OrderExpiredEvent,
    BuyOrderCompletedEvent,
    SellOrderCompletedEvent
)
from hummingbot.connector.connector_base import ConnectorBase
from hummingbot.core.utils.market_price import get_mid_price


class UltimateHybridStrategy(ScriptStrategyBase):
    """
    Ultimate Hybrid Trading Strategy for Hummingbot V2
    
    Combines:
    - Professional Grid Trading System (ATR-based)
    - Kaanermi Launch Strategy (NY session)
    - Market Profile Integration (POC/VAH/VAL)
    - Advanced Risk Management
    
    Repository: https://github.com/anbarci/hummingbot-ultimate-hybrid
    Version: 2.0
    Author: anbarci
    License: MIT
    """
    
    # ======================== CONFIGURATION ========================
    
    # Exchange and Trading Pairs
    markets = {"kucoin": {"WLD-USDT"}}
    
    # Strategy Information
    version = "2.0"
    github_repo = "anbarci/hummingbot-ultimate-hybrid"
    
    # Grid Trading Configuration
    enable_grid = True
    grid_mode = "ATR Based"
    base_grid_count = 8
    base_spacing_pct = 1.2
    atr_period = 14
    atr_multiplier = 1.5
    grid_rebalance_threshold = 0.05
    grid_order_amount = 0.1
    grid_max_spread = 0.15
    grid_min_spread = 0.005
    
    # Launch Strategy Configuration (Kaanermi Method)
    enable_launch_strategy = True
    launch_time_start = time(1, 0)  # 01:00 TRT (NY session)
    launch_time_end = time(8, 0)    # 08:00 TRT (NY session)
    needle_body_ratio = 2.0
    launch_cooldown_minutes = 30
    enable_bias_filter = True
    launch_min_range_pct = 0.005
    launch_max_range_pct = 0.050
    
    # Market Profile Configuration
    enable_market_profile = True
    mp_session_length = 24
    mp_tpo_percent = 70.0
    mp_price_levels = 20
    mp_update_frequency = 30
    mp_poc_weight = 0.4
    
    # Risk Management Configuration
    enable_advanced_risk = True
    max_portfolio_risk = 12.0
    max_single_position = 4.0
    max_concurrent_trades = 10
    min_balance_threshold = 50
    stop_loss_atr = 2.0
    take_profit_atr = 3.5
    risk_reward_ratio = 1.75
    emergency_stop_drawdown = 20.0
    daily_loss_limit = 5.0
    max_consecutive_losses = 5
    
    # Advanced Filters
    enable_volatility_filter = True
    volatility_threshold = 1.5
    volatility_period = 20
    high_volatility_threshold = 5.0
    enable_trend_filter = True
    trend_period = 50
    trend_strength_threshold = 0.015
    trend_confirmation_period = 3
    enable_volume_filter = True
    min_volume_ratio = 0.5
    volume_spike_threshold = 3.0
    volume_period = 20
    
    # Performance Settings
    order_refresh_time = 30
    price_update_interval = 5
    status_update_interval = 60
    max_price_history = 500
    max_trade_history = 1000
    
    # ======================== INITIALIZATION ========================
    
    def __init__(self, connectors: Dict[str, ConnectorBase]):
        super().__init__(connectors)
        
        # Core Variables
        self.trading_pairs = list(self.markets.values())[0]  # Get trading pairs
        self.exchange = list(self.markets.keys())[0]         # Get exchange name
        self.connector = self.connectors[self.exchange]      # Get connector
        
        # Session Management
        self.session_start_time = datetime.now()
        self.last_status_update = datetime.now()
        self.performance_log_file = f"logs/ultimate_hybrid_performance_{datetime.now().strftime('%Y%m%d')}.json"
        
        # Market Data Storage
        self.price_history = {}
        self.volume_history = {}
        self.trade_history = []
        self.candle_data = {}
        
        # Strategy State Variables
        self.current_price = Decimal("0")
        self.atr_value = Decimal("0")
        self.volatility_ratio = 0.0
        self.trend_direction = 0  # -1: Down, 0: Sideways, 1: Up
        self.current_bias = 0     # -1: Bearish, 0: Neutral, 1: Bullish
        self.price_momentum = 0.0
        self.sma_20 = Decimal("0")
        self.sma_50 = Decimal("0")
        
        # Grid Trading Variables
        self.grid_initialized = False
        self.grid_base_price = Decimal("0")
        self.grid_spacing = Decimal("0")
        self.active_grid_orders = {}
        self.grid_buy_levels = []
        self.grid_sell_levels = []
        self.total_grid_trades = 0
        self.grid_profit = Decimal("0")
        
        # Launch Strategy Variables
        self.launch_session_active = False
        self.launch_high = None
        self.launch_low = None
        self.launch_range_confirmed = False
        self.last_launch_trade = datetime.now() - timedelta(hours=1)
        self.total_launch_trades = 0
        self.launch_profit = Decimal("0")
        
        # Market Profile Variables
        self.mp_is_valid = False
        self.mp_poc_price = Decimal("0")   # Point of Control
        self.mp_vah_price = Decimal("0")   # Value Area High
        self.mp_val_price = Decimal("0")   # Value Area Low
        self.mp_value_area_range = Decimal("0")
        self.mp_tpo_data = {}
        self.last_mp_update = datetime.now()
        
        # Risk Management Variables
        self.account_balance = Decimal("0")
        self.current_portfolio_risk = 0.0
        self.active_trades_count = 0
        self.total_exposure = Decimal("0")
        self.can_trade = True
        self.restriction_reason = ""
        self.consecutive_losses = 0
        self.daily_pnl = Decimal("0")
        self.max_drawdown = 0.0
        
        # Performance Metrics
        self.total_trades = 0
        self.winning_trades = 0
        self.losing_trades = 0
        self.total_pnl = Decimal("0")
        self.win_rate = 0.0
        
        # Initialize components
        self.initialize_data_structures()
        
        self.logger().info(f"🚀 Ultimate Hybrid Strategy v{self.version} Initialized")
        self.logger().info(f"📦 Repository: github.com/{self.github_repo}")
        self.logger().info(f"🔧 Components: Grid={self.enable_grid}, Launch={self.enable_launch_strategy}, MP={self.enable_market_profile}")
    
    def initialize_data_structures(self):
        """Initialize data structures for each trading pair"""
        for trading_pair in self.trading_pairs:
            self.price_history[trading_pair] = []
            self.volume_history[trading_pair] = []
            self.candle_data[trading_pair] = []
            self.active_grid_orders[trading_pair] = {"buy": {}, "sell": {}}
    
    # ======================== MAIN STRATEGY LOOP ========================
    
    def on_tick(self):
        """Main strategy execution - called every tick"""
        try:
            # Update market data
            self.update_market_data()
            
            # Update account information
            self.update_account_info()
            
            # Run risk management checks
            if not self.risk_management_check():
                return
            
            # Execute strategy components
            if self.enable_market_profile:
                self.update_market_profile()
            
            if self.enable_grid and self.can_trade:
                self.execute_grid_strategy()
            
            if self.enable_launch_strategy and self.can_trade:
                self.execute_launch_strategy()
            
            # Update performance metrics
            self.update_performance_metrics()
            
            # Log performance periodically
            if (datetime.now() - self.last_status_update).total_seconds() > self.status_update_interval:
                self.log_performance_data()
                self.last_status_update = datetime.now()
                
        except Exception as e:
            self.logger().error(f"❌ Error in on_tick: {e}")
    
    # ======================== MARKET DATA MANAGEMENT ========================
    
    def update_market_data(self):
        """Update current market data and indicators"""
        try:
            for trading_pair in self.trading_pairs:
                # Get current price
                mid_price = get_mid_price(self.connector, trading_pair)
                if mid_price and mid_price > 0:
                    self.current_price = Decimal(str(mid_price))
                    
                    # Update price history
                    self.price_history[trading_pair].append({
                        'timestamp': datetime.now(),
                        'price': float(self.current_price),
                        'volume': self.get_current_volume(trading_pair)
                    })
                    
                    # Limit history size
                    if len(self.price_history[trading_pair]) > self.max_price_history:
                        self.price_history[trading_pair] = self.price_history[trading_pair][-self.max_price_history:]
                    
                    # Calculate technical indicators
                    self.calculate_technical_indicators(trading_pair)
                    
        except Exception as e:
            self.logger().error(f"❌ Error updating market data: {e}")
    
    def get_current_volume(self, trading_pair: str) -> float:
        """Get current volume for trading pair"""
        try:
            order_book = self.connector.get_order_book(trading_pair)
            if order_book:
                # Calculate volume from order book depth
                bids = list(order_book.bid_entries())[:10]  # Top 10 levels
                asks = list(order_book.ask_entries())[:10]
                
                total_volume = sum([float(entry.amount) for entry in bids + asks])
                return total_volume
            return 0.0
        except Exception:
            return 0.0
    
    def calculate_technical_indicators(self, trading_pair: str):
        """Calculate ATR, SMA, and other technical indicators"""
        try:
            prices = [item['price'] for item in self.price_history[trading_pair][-100:]]
            
            if len(prices) < 20:
                return
            
            # Calculate Simple Moving Averages
            self.sma_20 = Decimal(str(np.mean(prices[-20:])))
            if len(prices) >= 50:
                self.sma_50 = Decimal(str(np.mean(prices[-50:])))
            
            # Calculate ATR (simplified)
            if len(prices) >= self.atr_period:
                high_low = np.array([abs(prices[i] - prices[i-1]) for i in range(1, len(prices))])
                self.atr_value = Decimal(str(np.mean(high_low[-self.atr_period:])))
            
            # Calculate volatility ratio
            if self.current_price > 0:
                self.volatility_ratio = float(self.atr_value) / float(self.current_price) * 1000
            
            # Calculate trend direction
            if len(prices) >= self.trend_period:
                recent_avg = np.mean(prices[-10:])
                older_avg = np.mean(prices[-self.trend_period:-10])
                price_change = (recent_avg - older_avg) / older_avg
                
                if price_change > self.trend_strength_threshold:
                    self.trend_direction = 1  # Uptrend
                elif price_change < -self.trend_strength_threshold:
                    self.trend_direction = -1  # Downtrend
                else:
                    self.trend_direction = 0  # Sideways
            
            # Calculate momentum
            if len(prices) >= 10:
                self.price_momentum = (prices[-1] - prices[-10]) / prices[-10]
            
            # Calculate bias
            if self.current_price > self.sma_20:
                self.current_bias = 1  # Bullish
            elif self.current_price < self.sma_20:
                self.current_bias = -1  # Bearish
            else:
                self.current_bias = 0  # Neutral
                
        except Exception as e:
            self.logger().error(f"❌ Error calculating indicators: {e}")
    
    # ======================== GRID TRADING SYSTEM ========================
    
    def execute_grid_strategy(self):
        """Execute grid trading logic"""
        try:
            for trading_pair in self.trading_pairs:
                if not self.grid_initialized:
                    self.initialize_grid(trading_pair)
                else:
                    self.manage_grid_orders(trading_pair)
                    
        except Exception as e:
            self.logger().error(f"❌ Error in grid strategy: {e}")
    
    def initialize_grid(self, trading_pair: str):
        """Initialize grid levels based on current market conditions"""
        try:
            if self.current_price <= 0 or self.atr_value <= 0:
                return
            
            # Set grid base price (use Market Profile POC if available)
            if self.enable_market_profile and self.mp_is_valid and self.mp_poc_price > 0:
                # Blend current price with POC
                poc_weight = Decimal(str(self.mp_poc_weight))
                price_weight = Decimal("1") - poc_weight
                self.grid_base_price = (self.current_price * price_weight) + (self.mp_poc_price * poc_weight)
            else:
                self.grid_base_price = self.current_price
            
            # Calculate dynamic grid spacing using ATR
            if self.grid_mode == "ATR Based":
                self.grid_spacing = self.atr_value * Decimal(str(self.atr_multiplier))
            else:
                self.grid_spacing = self.grid_base_price * Decimal(str(self.base_spacing_pct / 100))
            
            # Ensure spacing is within limits
            min_spacing = self.grid_base_price * Decimal(str(self.grid_min_spread))
            max_spacing = self.grid_base_price * Decimal(str(self.grid_max_spread / self.base_grid_count))
            
            self.grid_spacing = max(min_spacing, min(self.grid_spacing, max_spacing))
            
            # Generate grid levels
            self.grid_buy_levels = []
            self.grid_sell_levels = []
            
            for i in range(1, self.base_grid_count + 1):
                buy_price = self.grid_base_price - (self.grid_spacing * Decimal(str(i)))
                sell_price = self.grid_base_price + (self.grid_spacing * Decimal(str(i)))
                
                if buy_price > 0:
                    self.grid_buy_levels.append(buy_price)
                self.grid_sell_levels.append(sell_price)
            
            self.grid_initialized = True
            self.logger().info(f"✅ Grid initialized for {trading_pair}: Base={self.grid_base_price:.6f}, Spacing={self.grid_spacing:.6f}")
            
            # Place initial grid orders
            self.place_grid_orders(trading_pair)
            
        except Exception as e:
            self.logger().error(f"❌ Error initializing grid: {e}")
    
    def place_grid_orders(self, trading_pair: str):
        """Place grid orders at calculated levels"""
        try:
            # Place buy orders
            for level_price in self.grid_buy_levels:
                if level_price not in [order.price for order in self.active_grid_orders[trading_pair]["buy"].values()]:
                    if self.check_order_viability(trading_pair, True, level_price, Decimal(str(self.grid_order_amount))):
                        order_id = self.buy(
                            connector_name=self.exchange,
                            trading_pair=trading_pair,
                            amount=Decimal(str(self.grid_order_amount)),
                            order_type=OrderType.LIMIT,
                            price=level_price
                        )
                        if order_id:
                            self.active_grid_orders[trading_pair]["buy"][order_id] = {
                                'price': level_price,
                                'amount': Decimal(str(self.grid_order_amount)),
                                'timestamp': datetime.now()
                            }
            
            # Place sell orders
            for level_price in self.grid_sell_levels:
                if level_price not in [order.price for order in self.active_grid_orders[trading_pair]["sell"].values()]:
                    if self.check_order_viability(trading_pair, False, level_price, Decimal(str(self.grid_order_amount))):
                        order_id = self.sell(
                            connector_name=self.exchange,
                            trading_pair=trading_pair,
                            amount=Decimal(str(self.grid_order_amount)),
                            order_type=OrderType.LIMIT,
                            price=level_price
                        )
                        if order_id:
                            self.active_grid_orders[trading_pair]["sell"][order_id] = {
                                'price': level_price,
                                'amount': Decimal(str(self.grid_order_amount)),
                                'timestamp': datetime.now()
                            }
                            
        except Exception as e:
            self.logger().error(f"❌ Error placing grid orders: {e}")
    
    def manage_grid_orders(self, trading_pair: str):
        """Manage existing grid orders and rebalance if needed"""
        try:
            # Check if grid needs rebalancing
            if abs(float(self.current_price - self.grid_base_price)) / float(self.grid_base_price) > self.grid_rebalance_threshold:
                self.logger().info(f"🔄 Grid rebalancing triggered for {trading_pair}")
                self.cancel_all_grid_orders(trading_pair)
                self.grid_initialized = False
                return
            
            # Refresh old orders
            self.refresh_old_grid_orders(trading_pair)
            
        except Exception as e:
            self.logger().error(f"❌ Error managing grid orders: {e}")
    
    def cancel_all_grid_orders(self, trading_pair: str):
        """Cancel all active grid orders"""
        try:
            for side in ["buy", "sell"]:
                for order_id in list(self.active_grid_orders[trading_pair][side].keys()):
                    self.cancel(self.exchange, trading_pair, order_id)
            
            self.active_grid_orders[trading_pair] = {"buy": {}, "sell": {}}
            
        except Exception as e:
            self.logger().error(f"❌ Error canceling grid orders: {e}")
    
    def refresh_old_grid_orders(self, trading_pair: str):
        """Refresh orders that are too old"""
        try:
            current_time = datetime.now()
            max_order_age = timedelta(seconds=3600)  # 1 hour
            
            for side in ["buy", "sell"]:
                orders_to_refresh = []
                for order_id, order_data in self.active_grid_orders[trading_pair][side].items():
                    if current_time - order_data['timestamp'] > max_order_age:
                        orders_to_refresh.append(order_id)
                
                for order_id in orders_to_refresh:
                    self.cancel(self.exchange, trading_pair, order_id)
                    
        except Exception as e:
            self.logger().error(f"❌ Error refreshing grid orders: {e}")
    
    # ======================== LAUNCH STRATEGY (KAANERMI METHOD) ========================
    
    def execute_launch_strategy(self):
        """Execute launch strategy based on Kaanermi method"""
        try:
            current_time = datetime.now().time()
            
            # Check if we're in NY session
            self.launch_session_active = self.launch_time_start <= current_time <= self.launch_time_end
            
            if self.launch_session_active:
                self.monitor_launch_levels()
            else:
                self.check_launch_opportunities()
                
        except Exception as e:
            self.logger().error(f"❌ Error in launch strategy: {e}")
    
    def monitor_launch_levels(self):
        """Monitor high/low levels during NY session"""
        try:
            # Update session high/low
            if self.launch_high is None or self.current_price > self.launch_high:
                self.launch_high = self.current_price
            
            if self.launch_low is None or self.current_price < self.launch_low:
                self.launch_low = self.current_price
            
            # Check if we have valid range
            if self.launch_high and self.launch_low:
                launch_range = float(self.launch_high - self.launch_low)
                range_pct = launch_range / float(self.current_price)
                
                if self.launch_min_range_pct <= range_pct <= self.launch_max_range_pct:
                    self.launch_range_confirmed = True
                    
        except Exception as e:
            self.logger().error(f"❌ Error monitoring launch levels: {e}")
    
    def check_launch_opportunities(self):
        """Check for launch trading opportunities after NY session"""
        try:
            if not self.launch_range_confirmed or not self.launch_high or not self.launch_low:
                return
            
            # Check cooldown
            time_since_last_trade = (datetime.now() - self.last_launch_trade).total_seconds() / 60
            if time_since_last_trade < self.launch_cooldown_minutes:
                return
            
            # Check for needle formations (wick rejections)
            launch_signals = self.detect_needle_formations()
            
            for signal in launch_signals:
                if self.validate_launch_signal(signal):
                    self.execute_launch_trade(signal)
                    
        except Exception as e:
            self.logger().error(f"❌ Error checking launch opportunities: {e}")
    
    def detect_needle_formations(self) -> List[Dict]:
        """Detect needle/wick formations at launch levels"""
        signals = []
        
        try:
            # Get recent price action
            recent_prices = self.price_history[list(self.trading_pairs)[0]][-10:]
            
            if len(recent_prices) < 5:
                return signals
            
            current_candle = recent_prices[-1]
            prev_candle = recent_prices[-2]
            
            current_price = current_candle['price']
            prev_price = prev_candle['price']
            
            # Check for rejection at launch high (bearish signal)
            if (current_price >= float(self.launch_high) * 0.995 and
                current_price < prev_price and
                self.calculate_wick_body_ratio(recent_prices, 'high') >= self.needle_body_ratio):
                
                signals.append({
                    'direction': 'sell',
                    'level': self.launch_high,
                    'confidence': self.calculate_signal_confidence('bearish'),
                    'entry_price': self.current_price,
                    'stop_loss': self.launch_high * Decimal("1.01"),
                    'take_profit': self.launch_low
                })
            
            # Check for rejection at launch low (bullish signal)
            if (current_price <= float(self.launch_low) * 1.005 and
                current_price > prev_price and
                self.calculate_wick_body_ratio(recent_prices, 'low') >= self.needle_body_ratio):
                
                signals.append({
                    'direction': 'buy',
                    'level': self.launch_low,
                    'confidence': self.calculate_signal_confidence('bullish'),
                    'entry_price': self.current_price,
                    'stop_loss': self.launch_low * Decimal("0.99"),
                    'take_profit': self.launch_high
                })
            
        except Exception as e:
            self.logger().error(f"❌ Error detecting needle formations: {e}")
        
        return signals
    
    def calculate_wick_body_ratio(self, candles: List[Dict], rejection_type: str) -> float:
        """Calculate wick to body ratio for needle detection"""
        try:
            if len(candles) < 2:
                return 0.0
            
            current = candles[-1]
            prev = candles[-2]
            
            # Simplified calculation - in real implementation, you'd have OHLC data
            body_size = abs(current['price'] - prev['price'])
            
            if rejection_type == 'high':
                # Assuming upper wick rejection
                high_price = max([c['price'] for c in candles[-3:]])
                wick_size = high_price - max(current['price'], prev['price'])
            else:
                # Assuming lower wick rejection
                low_price = min([c['price'] for c in candles[-3:]])
                wick_size = min(current['price'], prev['price']) - low_price
            
            if body_size > 0:
                return wick_size / body_size
            return 0.0
            
        except Exception:
            return 0.0
    
    def calculate_signal_confidence(self, direction: str) -> float:
        """Calculate confidence score for launch signal"""
        try:
            confidence = 0.5  # Base confidence
            
            # Add confidence based on trend alignment
            if self.enable_bias_filter:
                if direction == 'bullish' and self.current_bias >= 0:
                    confidence += 0.2
                elif direction == 'bearish' and self.current_bias <= 0:
                    confidence += 0.2
                else:
                    confidence -= 0.1
            
            # Add confidence based on volatility
            if 1.0 <= self.volatility_ratio <= 3.0:  # Optimal volatility range
                confidence += 0.2
            
            # Add confidence based on volume
            if hasattr(self, 'current_volume_ratio') and self.current_volume_ratio > 1.2:
                confidence += 0.1
            
            return min(1.0, max(0.0, confidence))
            
        except Exception:
            return 0.5
    
    def validate_launch_signal(self, signal: Dict) -> bool:
        """Validate launch signal before execution"""
        try:
            # Check minimum confidence
            if signal['confidence'] < 0.6:
                return False
            
            # Check risk limits
            position_size = self.calculate_position_size(signal)
            if position_size <= 0:
                return False
            
            # Check if signal aligns with current market conditions
            if self.enable_volatility_filter and self.volatility_ratio < self.volatility_threshold:
                return False
            
            return True
            
        except Exception as e:
            self.logger().error(f"❌ Error validating launch signal: {e}")
            return False
    
    def execute_launch_trade(self, signal: Dict):
        """Execute launch trade based on signal"""
        try:
            trading_pair = list(self.trading_pairs)[0]
            
            # Calculate position size
            position_size = self.calculate_position_size(signal)
            
            if position_size <= 0:
                return
            
            # Execute trade
            if signal['direction'] == 'buy':
                order_id = self.buy(
                    connector_name=self.exchange,
                    trading_pair=trading_pair,
                    amount=position_size,
                    order_type=OrderType.MARKET
                )
            else:
                order_id = self.sell(
                    connector_name=self.exchange,
                    trading_pair=trading_pair,
                    amount=position_size,
                    order_type=OrderType.MARKET
                )
            
            if order_id:
                self.last_launch_trade = datetime.now()
                self.total_launch_trades += 1
                
                self.logger().info(f"🎯 Launch trade executed: {signal['direction'].upper()} {position_size} {trading_pair}")
                self.logger().info(f"   Entry: {signal['entry_price']:.6f}, SL: {signal['stop_loss']:.6f}, TP: {signal['take_profit']:.6f}")
                
        except Exception as e:
            self.logger().error(f"❌ Error executing launch trade: {e}")
    
    # ======================== MARKET PROFILE ========================
    
    def update_market_profile(self):
        """Update Market Profile data (POC, VAH, VAL)"""
        try:
            # Only update periodically
            if (datetime.now() - self.last_mp_update).total_seconds() < self.mp_update_frequency * 60:
                return
            
            trading_pair = list(self.trading_pairs)[0]
            
            # Get recent price data for TPO calculation
            recent_data = self.price_history[trading_pair][-self.mp_session_length * 60:]  # Assuming 1-minute data
            
            if len(recent_data) < 100:
                return
            
            # Calculate TPO (Time Price Opportunity) profile
            self.calculate_tpo_profile(recent_data)
            
            # Update market profile values
            self.calculate_market_profile_levels()
            
            self.last_mp_update = datetime.now()
            self.mp_is_valid = True
            
        except Exception as e:
            self.logger().error(f"❌ Error updating market profile: {e}")
    
    def calculate_tpo_profile(self, price_data: List[Dict]):
        """Calculate Time Price Opportunity profile"""
        try:
            if not price_data:
                return
            
            # Get price range
            prices = [item['price'] for item in price_data]
            min_price = min(prices)
            max_price = max(prices)
            
            # Create price levels
            price_step = (max_price - min_price) / self.mp_price_levels
            
            # Initialize TPO counts
            self.mp_tpo_data = {}
            
            for i in range(self.mp_price_levels):
                level_price = min_price + (price_step * i)
                self.mp_tpo_data[level_price] = 0
            
            # Count TPOs (time spent at each price level)
            for data_point in price_data:
                price = data_point['price']
                volume = data_point.get('volume', 1)
                
                # Find closest price level
                closest_level = min(self.mp_tpo_data.keys(), key=lambda x: abs(x - price))
                self.mp_tpo_data[closest_level] += volume
            
        except Exception as e:
            self.logger().error(f"❌ Error calculating TPO profile: {e}")
    
    def calculate_market_profile_levels(self):
        """Calculate POC, VAH, VAL from TPO data"""
        try:
            if not self.mp_tpo_data:
                return
            
            # Find Point of Control (highest volume price level)
            poc_level = max(self.mp_tpo_data.items(), key=lambda x: x[1])
            self.mp_poc_price = Decimal(str(poc_level[0]))
            
            # Calculate Value Area (70% of total volume)
            total_volume = sum(self.mp_tpo_data.values())
            value_area_volume = total_volume * (self.mp_tpo_percent / 100)
            
            # Sort levels by volume
            sorted_levels = sorted(self.mp_tpo_data.items(), key=lambda x: x[1], reverse=True)
            
            # Find Value Area High and Low
            accumulated_volume = 0
            value_area_prices = []
            
            for price, volume in sorted_levels:
                accumulated_volume += volume
                value_area_prices.append(price)
                
                if accumulated_volume >= value_area_volume:
                    break
            
            if value_area_prices:
                self.mp_vah_price = Decimal(str(max(value_area_prices)))
                self.mp_val_price = Decimal(str(min(value_area_prices)))
                self.mp_value_area_range = self.mp_vah_price - self.mp_val_price
                
                self.logger().info(f"📊 Market Profile Updated - POC: {self.mp_poc_price:.6f}, VAH: {self.mp_vah_price:.6f}, VAL: {self.mp_val_price:.6f}")
            
        except Exception as e:
            self.logger().error(f"❌ Error calculating market profile levels: {e}")
    
    # ======================== RISK MANAGEMENT ========================
    
    def risk_management_check(self) -> bool:
        """Comprehensive risk management check"""
        try:
            # Update account info first
            self.update_account_info()
            
            # Check minimum balance
            if self.account_balance < self.min_balance_threshold:
                self.can_trade = False
                self.restriction_reason = f"Balance below minimum: ${self.account_balance:.2f} < ${self.min_balance_threshold}"
                return False
            
            # Check portfolio risk
            if self.current_portfolio_risk > self.max_portfolio_risk:
                self.can_trade = False
                self.restriction_reason = f"Portfolio risk too high: {self.current_portfolio_risk:.1f}% > {self.max_portfolio_risk:.1f}%"
                return False
            
            # Check maximum concurrent trades
            if self.active_trades_count >= self.max_concurrent_trades:
                self.can_trade = False
                self.restriction_reason = f"Too many active trades: {self.active_trades_count} >= {self.max_concurrent_trades}"
                return False
            
            # Check consecutive losses
            if self.consecutive_losses >= self.max_consecutive_losses:
                self.can_trade = False
                self.restriction_reason = f"Too many consecutive losses: {self.consecutive_losses} >= {self.max_consecutive_losses}"
                return False
            
            # Check daily loss limit
            daily_loss_pct = float(abs(self.daily_pnl)) / float(self.account_balance) * 100
            if self.daily_pnl < 0 and daily_loss_pct > self.daily_loss_limit:
                self.can_trade = False
                self.restriction_reason = f"Daily loss limit exceeded: {daily_loss_pct:.1f}% > {self.daily_loss_limit:.1f}%"
                return False
            
            # Check maximum drawdown
            if self.max_drawdown > self.emergency_stop_drawdown:
                self.can_trade = False
                self.restriction_reason = f"Emergency drawdown stop: {self.max_drawdown:.1f}% > {self.emergency_stop_drawdown:.1f}%"
                return False
            
            # All checks passed
            self.can_trade = True
            self.restriction_reason = ""
            return True
            
        except Exception as e:
            self.logger().error(f"❌ Error in risk management check: {e}")
            self.can_trade = False
            self.restriction_reason = f"Risk check error: {e}"
            return False
    
    def update_account_info(self):
        """Update account balance and exposure information"""
        try:
            # Get account balance
            balance_df = self.get_balance_df()
            
            if not balance_df.empty:
                # Calculate total USDT equivalent balance
                usdt_balance = 0
                for _, row in balance_df.iterrows():
                    if row['Asset'] == 'USDT':
                        usdt_balance += float(row['Total Balance'])
                    else:
                        # Convert other assets to USDT (simplified)
                        try:
                            asset_price = self.get_asset_price_in_usdt(row['Asset'])
                            if asset_price > 0:
                                usdt_balance += float(row['Total Balance']) * asset_price
                        except:
                            pass
                
                self.account_balance = Decimal(str(usdt_balance))
            
            # Get active orders info
            active_orders_df = self.active_orders_df()
            self.active_trades_count = len(active_orders_df)
            
            # Calculate total exposure
            if not active_orders_df.empty:
                total_exposure = 0
                for _, order in active_orders_df.iterrows():
                    exposure = float(order['Amount']) * float(order['Price'])
                    total_exposure += exposure
                
                self.total_exposure = Decimal(str(total_exposure))
                
                # Calculate portfolio risk percentage
                if self.account_balance > 0:
                    self.current_portfolio_risk = float(self.total_exposure) / float(self.account_balance) * 100
            else:
                self.total_exposure = Decimal("0")
                self.current_portfolio_risk = 0.0
                
        except Exception as e:
            self.logger().error(f"❌ Error updating account info: {e}")
    
    def get_asset_price_in_usdt(self, asset: str) -> float:
        """Get asset price in USDT terms"""
        try:
            if asset == 'USDT':
                return 1.0
            
            # Try to find a trading pair with USDT
            possible_pairs = [f"{asset}-USDT", f"{asset}USDT"]
            
            for pair in possible_pairs:
                try:
                    mid_price = get_mid_price(self.connector, pair)
                    if mid_price and mid_price > 0:
                        return float(mid_price)
                except:
                    continue
            
            return 0.0
            
        except Exception:
            return 0.0
    
    def calculate_position_size(self, signal: Dict) -> Decimal:
        """Calculate appropriate position size based on risk management"""
        try:
            # Maximum position size based on portfolio risk limits
            max_position_value = self.account_balance * Decimal(str(self.max_single_position / 100))
            
            # Calculate position size based on stop loss distance
            entry_price = signal['entry_price']
            stop_loss_price = signal['stop_loss']
            
            if entry_price > 0 and stop_loss_price > 0:
                risk_per_unit = abs(entry_price - stop_loss_price)
                
                if risk_per_unit > 0:
                    # Position size = Risk Amount / Risk Per Unit
                    risk_amount = self.account_balance * Decimal(str(self.max_single_position / 100))
                    position_size = risk_amount / risk_per_unit
                    
                    # Limit to maximum position value
                    max_units = max_position_value / entry_price
                    position_size = min(position_size, max_units)
                    
                    # Round to appropriate precision
                    return max(Decimal("0"), position_size.quantize(Decimal('0.0001')))
            
            return Decimal("0")
            
        except Exception as e:
            self.logger().error(f"❌ Error calculating position size: {e}")
            return Decimal("0")
    
    def check_order_viability(self, trading_pair: str, is_buy: bool, price: Decimal, amount: Decimal) -> bool:
        """Check if order can be placed given current constraints"""
        try:
            # Check minimum order size
            min_order_size = Decimal("0.001")  # Minimum order size
            if amount < min_order_size:
                return False
            
            # Check if price is reasonable (within 10% of current price)
            price_deviation = abs(float(price - self.current_price)) / float(self.current_price)
            if price_deviation > 0.1:  # 10% deviation limit
                return False
            
            # Check balance availability
            required_balance = amount * price if is_buy else amount
            
            balance_df = self.get_balance_df()
            if not balance_df.empty:
                asset_to_check = 'USDT' if is_buy else trading_pair.split('-')[0]
                available_balance = 0
                
                for _, row in balance_df.iterrows():
                    if row['Asset'] == asset_to_check:
                        available_balance = float(row['Available Balance'])
                        break
                
                if available_balance < float(required_balance) * 1.01:  # 1% buffer
                    return False
            
            return True
            
        except Exception as e:
            self.logger().error(f"❌ Error checking order viability: {e}")
            return False
    
    # ======================== PERFORMANCE TRACKING ========================
    
    def update_performance_metrics(self):
        """Update performance metrics and statistics"""
        try:
            # Calculate win rate
            if self.total_trades > 0:
                self.win_rate = (self.winning_trades / self.total_trades) * 100
            
            # Update daily P&L (simplified)
            # In real implementation, you'd track from session start
            
            # Calculate max drawdown (simplified)
            if hasattr(self, 'peak_balance') and self.account_balance > 0:
                current_drawdown = float((self.peak_balance - self.account_balance) / self.peak_balance * 100)
                self.max_drawdown = max(self.max_drawdown, current_drawdown)
            else:
                self.peak_balance = self.account_balance
                
        except Exception as e:
            self.logger().error(f"❌ Error updating performance metrics: {e}")
    
    def log_performance_data(self):
        """Log performance data to JSON file for analysis"""
        try:
            performance_data = {
                'timestamp': datetime.now().isoformat(),
                'version': self.version,
                'session_runtime_hours': round((datetime.now() - self.session_start_time).total_seconds() / 3600, 2),
                'account_balance': float(self.account_balance),
                'current_price': float(self.current_price),
                'total_trades': self.total_trades,
                'winning_trades': self.winning_trades,
                'losing_trades': self.losing_trades,
                'win_rate': self.win_rate,
                'total_pnl': float(self.total_pnl),
                'daily_pnl': float(self.daily_pnl),
                'portfolio_risk': self.current_portfolio_risk,
                'max_drawdown': self.max_drawdown,
                'grid_trades': self.total_grid_trades,
                'launch_trades': self.total_launch_trades,
                'grid_profit': float(self.grid_profit),
                'launch_profit': float(self.launch_profit),
                'active_trades': self.active_trades_count,
                'can_trade': self.can_trade,
                'restriction_reason': self.restriction_reason,
                'volatility_ratio': self.volatility_ratio,
                'trend_direction': self.trend_direction,
                'current_bias': self.current_bias,
                'atr_value': float(self.atr_value),
                'components': {
                    'grid_enabled': self.enable_grid,
                    'launch_enabled': self.enable_launch_strategy,
                    'market_profile_enabled': self.enable_market_profile,
                    'grid_initialized': self.grid_initialized,
                    'launch_session_active': self.launch_session_active,
                    'mp_valid': self.mp_is_valid
                }
            }
            
            # Write to file (append mode)
            import json
            with open(self.performance_log_file, 'a') as f:
                f.write(json.dumps(performance_data) + '\n')
                
        except Exception as e:
            self.logger().error(f"❌ Error logging performance data: {e}")
    
    # ======================== EVENT HANDLERS ========================
    
    def did_fill_order(self, event: OrderFilledEvent):
        """Handle order fill events"""
        try:
            self.total_trades += 1
            
            # Update profit tracking
            trade_profit = float(event.trade_fee.flat_fees[0].amount) if event.trade_fee.flat_fees else 0
            
            if event.trade_type.name == "BUY":
                self.logger().info(f"✅ Buy order filled: {event.amount} {event.trading_pair} @ {event.price}")
            else:
                self.logger().info(f"✅ Sell order filled: {event.amount} {event.trading_pair} @ {event.price}")
            
            # Update grid order tracking
            self.update_grid_order_tracking(event)
            
        except Exception as e:
            self.logger().error(f"❌ Error handling order fill: {e}")
    
       def did_complete_buy_order(self, event: BuyOrderCompletedEvent):
        """Handle buy order completion"""
        try:
            self.logger().info(f"🟢 Buy order completed: {event.order_id}")
            # Remove from grid tracking if it was a grid order
            self.remove_completed_grid_order(event.order_id, "buy")
            
        except Exception as e:
            self.logger().error(f"❌ Error handling buy order completion: {e}")
    
    def did_complete_sell_order(self, event: SellOrderCompletedEvent):
        """Handle sell order completion"""
        try:
            self.logger().info(f"🔴 Sell order completed: {event.order_id}")
            # Remove from grid tracking if it was a grid order
            self.remove_completed_grid_order(event.order_id, "sell")
            
        except Exception as e:
            self.logger().error(f"❌ Error handling sell order completion: {e}")
    
    def did_fail_order(self, event: MarketOrderFailureEvent):
        """Handle order failures"""
        try:
            self.logger().warning(f"⚠️ Order failed: {event.order_id} - {event.order_type}")
            # Remove failed order from tracking
            self.remove_failed_grid_order(event.order_id)
            
        except Exception as e:
            self.logger().error(f"❌ Error handling order failure: {e}")
    
    def did_cancel_order(self, event: OrderCancelledEvent):
        """Handle order cancellations"""
        try:
            self.logger().info(f"❌ Order cancelled: {event.order_id}")
            # Remove cancelled order from tracking
            self.remove_failed_grid_order(event.order_id)
            
        except Exception as e:
            self.logger().error(f"❌ Error handling order cancellation: {e}")
    
    def update_grid_order_tracking(self, event: OrderFilledEvent):
        """Update grid order tracking after fill"""
        try:
            trading_pair = event.trading_pair
            order_id = event.order_id
            
            # Find and remove filled order from grid tracking
            for side in ["buy", "sell"]:
                if order_id in self.active_grid_orders[trading_pair][side]:
                    del self.active_grid_orders[trading_pair][side][order_id]
                    self.total_grid_trades += 1
                    self.grid_profit += Decimal(str(event.amount)) * Decimal(str(event.price)) * Decimal("0.001")  # Simplified profit calc
                    
                    self.logger().info(f"📊 Grid order filled: {side.upper()} {event.amount} @ {event.price}")
                    break
                    
        except Exception as e:
            self.logger().error(f"❌ Error updating grid order tracking: {e}")
    
    def remove_completed_grid_order(self, order_id: str, side: str):
        """Remove completed order from grid tracking"""
        try:
            for trading_pair in self.trading_pairs:
                if order_id in self.active_grid_orders[trading_pair][side]:
                    del self.active_grid_orders[trading_pair][side][order_id]
                    break
                    
        except Exception as e:
            self.logger().error(f"❌ Error removing completed grid order: {e}")
    
    def remove_failed_grid_order(self, order_id: str):
        """Remove failed order from grid tracking"""
        try:
            for trading_pair in self.trading_pairs:
                for side in ["buy", "sell"]:
                    if order_id in self.active_grid_orders[trading_pair][side]:
                        del self.active_grid_orders[trading_pair][side][order_id]
                        return
                        
        except Exception as e:
            self.logger().error(f"❌ Error removing failed grid order: {e}")
    
    # ======================== STATUS AND DISPLAY ========================
    
    def format_status(self) -> str:
        """Format status display for Hummingbot client"""
        try:
            lines = []
            
            # Header
            lines.append("╔══════════════════════════════════════════════════════════════════════════════╗")
            lines.append(f"║           🚀 ULTIMATE HYBRID STRATEGY v{self.version} - LIVE STATUS 🚀            ║")
            lines.append("╠══════════════════════════════════════════════════════════════════════════════╣")
            
            # Account Information
            lines.append(f"║ 💰 Account Balance: ${self.account_balance:,.2f} USDT")
            lines.append(f"║ 📊 Portfolio Risk: {self.current_portfolio_risk:.1f}% / {self.max_portfolio_risk:.1f}%")
            lines.append(f"║ 🎯 Total Exposure: ${self.total_exposure:,.2f} USDT")
            lines.append(f"║ 📈 Session P&L: ${self.daily_pnl:+,.2f} USDT")
            lines.append(f"║ 📉 Max Drawdown: {self.max_drawdown:.1f}%")
            
            # Market Information
            lines.append("╠══════════════════════════════════════════════════════════════════════════════╣")
            lines.append(f"║ 💹 Current Price: ${self.current_price:.6f}")
            lines.append(f"║ 📊 ATR Value: ${self.atr_value:.6f} ({self.volatility_ratio:.1f}‰)")
            lines.append(f"║ 📈 Trend: {self.get_trend_display()} | Bias: {self.get_bias_display()}")
            lines.append(f"║ ⏱️ Session Runtime: {self.get_runtime_display()}")
            
            # Component Status
            lines.append("╠══════════════════════════════════════════════════════════════════════════════╣")
            lines.append("║ 🔧 STRATEGY COMPONENTS:")
            
            # Grid Status
            grid_status = "🟢 ACTIVE" if self.enable_grid and self.grid_initialized else "🟡 STANDBY" if self.enable_grid else "⚫ DISABLED"
            grid_orders = sum(len(orders) for orders in self.active_grid_orders.get(list(self.trading_pairs)[0], {"buy": {}, "sell": {}}).values())
            lines.append(f"║   🔲 Grid Trading: {grid_status} | Orders: {grid_orders} | Trades: {self.total_grid_trades}")
            
            if self.enable_grid and self.grid_initialized:
                lines.append(f"║      • Base Price: ${self.grid_base_price:.6f} | Spacing: ${self.grid_spacing:.6f}")
                lines.append(f"║      • Profit: ${self.grid_profit:+,.4f} USDT")
            
            # Launch Strategy Status
            launch_status = "🟢 NY SESSION" if self.launch_session_active else "🟡 MONITORING" if self.enable_launch_strategy else "⚫ DISABLED"
            lines.append(f"║   🎯 Launch Strategy: {launch_status} | Trades: {self.total_launch_trades}")
            
            if self.enable_launch_strategy:
                time_to_next = self.get_time_to_next_session()
                lines.append(f"║      • Range: ${self.launch_low:.6f} - ${self.launch_high:.6f} | Next: {time_to_next}")
                lines.append(f"║      • Profit: ${self.launch_profit:+,.4f} USDT")
            
            # Market Profile Status
            mp_status = "🟢 ACTIVE" if self.enable_market_profile and self.mp_is_valid else "🟡 LOADING" if self.enable_market_profile else "⚫ DISABLED"
            lines.append(f"║   📊 Market Profile: {mp_status}")
            
            if self.enable_market_profile and self.mp_is_valid:
                lines.append(f"║      • POC: ${self.mp_poc_price:.6f} | VAH: ${self.mp_vah_price:.6f} | VAL: ${self.mp_val_price:.6f}")
                lines.append(f"║      • Value Area Range: ${self.mp_value_area_range:.6f}")
            
            # Performance Metrics
            lines.append("╠══════════════════════════════════════════════════════════════════════════════╣")
            lines.append("║ 📈 PERFORMANCE METRICS:")
            lines.append(f"║   📊 Total Trades: {self.total_trades} | Win Rate: {self.win_rate:.1f}%")
            lines.append(f"║   💰 Total P&L: ${self.total_pnl:+,.4f} USDT")
            lines.append(f"║   🎯 Wins: {self.winning_trades} | Losses: {self.losing_trades}")
            lines.append(f"║   🔄 Active Orders: {self.active_trades_count}")
            
            # Risk Management Status
            lines.append("╠══════════════════════════════════════════════════════════════════════════════╣")
            lines.append("║ ⚠️ RISK MANAGEMENT:")
            
            risk_status = "🟢 SAFE" if self.can_trade else "🔴 RESTRICTED"
            lines.append(f"║   Status: {risk_status}")
            
            if not self.can_trade:
                lines.append(f"║   Reason: {self.restriction_reason}")
            
            lines.append(f"║   Consecutive Losses: {self.consecutive_losses}/{self.max_consecutive_losses}")
            
            # Footer
            lines.append("╠══════════════════════════════════════════════════════════════════════════════╣")
            lines.append(f"║ 🔗 Repository: github.com/{self.github_repo}")
            lines.append(f"║ ⏰ Last Update: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            lines.append("╚══════════════════════════════════════════════════════════════════════════════╝")
            
            return "\n".join(lines)
            
        except Exception as e:
            self.logger().error(f"❌ Error formatting status: {e}")
            return f"❌ Status display error: {e}"
    
    def get_trend_display(self) -> str:
        """Get trend direction display"""
        if self.trend_direction == 1:
            return "🟢 UP"
        elif self.trend_direction == -1:
            return "🔴 DOWN"
        else:
            return "🟡 SIDEWAYS"
    
    def get_bias_display(self) -> str:
        """Get bias display"""
        if self.current_bias == 1:
            return "🟢 BULLISH"
        elif self.current_bias == -1:
            return "🔴 BEARISH"
        else:
            return "🟡 NEUTRAL"
    
    def get_runtime_display(self) -> str:
        """Get formatted runtime display"""
        runtime = datetime.now() - self.session_start_time
        hours = int(runtime.total_seconds() // 3600)
        minutes = int((runtime.total_seconds() % 3600) // 60)
        return f"{hours:02d}h {minutes:02d}m"
    
    def get_time_to_next_session(self) -> str:
        """Get time to next NY session"""
        try:
            now = datetime.now().time()
            
            if now < self.launch_time_start:
                # Session hasn't started today
                next_session = datetime.combine(datetime.now().date(), self.launch_time_start)
            elif now > self.launch_time_end:
                # Session ended, next is tomorrow
                next_session = datetime.combine(datetime.now().date() + timedelta(days=1), self.launch_time_start)
            else:
                # Currently in session
                return "ACTIVE"
            
            time_diff = next_session - datetime.now()
            hours = int(time_diff.total_seconds() // 3600)
            minutes = int((time_diff.total_seconds() % 3600) // 60)
            
            return f"{hours:02d}h {minutes:02d}m"
            
        except Exception:
            return "Unknown"
    
    # ======================== UTILITY METHODS ========================
    
    def notify_performance_milestone(self, milestone: str):
        """Send notification for performance milestones"""
        try:
            message = f"🎯 Ultimate Hybrid Strategy Milestone: {milestone}"
            self.notify_hb_app_with_timestamp(message)
            
        except Exception as e:
            self.logger().error(f"❌ Error sending notification: {e}")
    
    def emergency_stop(self, reason: str):
        """Emergency stop all trading activities"""
        try:
            self.logger().error(f"🚨 EMERGENCY STOP TRIGGERED: {reason}")
            
            # Cancel all active orders
            for trading_pair in self.trading_pairs:
                self.cancel_all_grid_orders(trading_pair)
            
            # Disable trading
            self.can_trade = False
            self.restriction_reason = f"Emergency stop: {reason}"
            
            # Send notification
            self.notify_hb_app_with_timestamp(f"🚨 Emergency Stop: {reason}")
            
        except Exception as e:
            self.logger().error(f"❌ Error in emergency stop: {e}")
    
    def save_session_summary(self):
        """Save session summary when strategy stops"""
        try:
            summary = {
                'session_start': self.session_start_time.isoformat(),
                'session_end': datetime.now().isoformat(),
                'final_balance': float(self.account_balance),
                'total_trades': self.total_trades,
                'win_rate': self.win_rate,
                'total_pnl': float(self.total_pnl),
                'max_drawdown': self.max_drawdown,
                'grid_trades': self.total_grid_trades,
                'launch_trades': self.total_launch_trades,
                'version': self.version
            }
            
            # Save to file
            import json
            summary_file = f"logs/session_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(summary_file, 'w') as f:
                json.dump(summary, f, indent=2)
            
            self.logger().info(f"💾 Session summary saved: {summary_file}")
            
        except Exception as e:
            self.logger().error(f"❌ Error saving session summary: {e}")
    
    # ======================== CLEANUP AND SHUTDOWN ========================
    
    def on_stop(self):
        """Called when strategy is stopped"""
        try:
            self.logger().info("🛑 Ultimate Hybrid Strategy stopping...")
            
            # Cancel all active orders
            for trading_pair in self.trading_pairs:
                self.cancel_all_grid_orders(trading_pair)
            
            # Save session data
            self.save_session_summary()
            
            # Final performance notification
            final_message = (f"📊 Session Complete | "
                           f"Runtime: {self.get_runtime_display()} | "
                           f"Trades: {self.total_trades} | "
                           f"Win Rate: {self.win_rate:.1f}% | "
                           f"P&L: ${self.total_pnl:+,.2f}")
            
            self.notify_hb_app_with_timestamp(final_message)
            
            self.logger().info("✅ Ultimate Hybrid Strategy stopped successfully")
            
        except Exception as e:
            self.logger().error(f"❌ Error stopping strategy: {e}")
