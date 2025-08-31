#!/bin/bash

# Ultimate Hybrid Strategy - Real-Time Monitor
# Repository: https://github.com/anbarci/hummingbot-ultimate-hybrid
# Version: 2.0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
HUMMINGBOT_DIR="/root/hummingbot"
LOG_DIR="$HUMMINGBOT_DIR/logs"
PERFORMANCE_LOG="$LOG_DIR/ultimate_hybrid_performance_$(date +%Y%m%d).json"
REFRESH_INTERVAL=10

# macOS compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    HUMMINGBOT_DIR="$HOME/hummingbot"
    LOG_DIR="$HUMMINGBOT_DIR/logs"
    PERFORMANCE_LOG="$LOG_DIR/ultimate_hybrid_performance_$(date +%Y%m%d).json"
fi

# Function to display header
show_header() {
    clear
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${WHITE}📊           ULTIMATE HYBRID STRATEGY - REAL-TIME MONITOR           📊"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🕐 Monitoring Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}📁 Log Directory: $LOG_DIR"
    echo -e "${CYAN}🔄 Refresh Rate: ${REFRESH_INTERVAL} seconds"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to get latest log file
get_latest_log() {
    find "$LOG_DIR" -name "hummingbot_logs_*.log" -type f -exec ls -t {} + | head -n 1
}

# Function to show live performance data
show_performance() {
    echo -e "${BLUE}📈 LIVE PERFORMANCE DATA:${NC}"
    echo -e "${WHITE}─────────────────────────────────────────${NC}"
    
    if [ -f "$PERFORMANCE_LOG" ]; then
        # Get latest performance entry
        latest_data=$(tail -n 1 "$PERFORMANCE_LOG" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    print(f\"Balance: \${data.get('account_balance', 0):.2f} USDT\")
    print(f\"Total Trades: {data.get('total_trades', 0)}\")
    print(f\"Win Rate: {data.get('win_rate', 0):.1f}%\")
    print(f\"Portfolio Risk: {data.get('portfolio_risk', 0):.1f}%\")
    print(f\"Session P&L: \${data.get('daily_pnl', 0):+.2f}\")
    print(f\"Max Drawdown: {data.get('max_drawdown', 0):.1f}%\")
    print(f\"Runtime: {data.get('session_runtime_hours', 0):.1f}h\")
    print(f\"Can Trade: {'✅ YES' if data.get('can_trade', False) else '❌ NO'}\")
    if not data.get('can_trade', True):
        print(f\"Restriction: {data.get('restriction_reason', 'Unknown')}\")
except:
    print('No performance data available yet')
" 2>/dev/null)
        
        if [ -n "$latest_data" ]; then
            echo "$latest_data"
        else
            echo -e "${YELLOW}⏳ Waiting for performance data...${NC}"
        fi
    else
        echo -e "${YELLOW}⏳ Performance log not found - strategy may be starting up${NC}"
    fi
    echo ""
}

# Function to show recent trades
show_recent_trades() {
    echo -e "${BLUE}💰 RECENT TRADES (Last 10):${NC}"
    echo -e "${WHITE}─────────────────────────────────────────${NC}"
    
    LATEST_LOG=$(get_latest_log)
    
    if [ -f "$LATEST_LOG" ]; then
        # Extract recent trade information
        recent_trades=$(grep -E "(Buy order filled|Sell order filled|Trade executed)" "$LATEST_LOG" | tail -n 10 | while read line; do
            timestamp=$(echo "$line" | cut -d',' -f1)
            trade_info=$(echo "$line" | cut -d'-' -f2- | xargs)
            echo "  $timestamp: $trade_info"
        done)
        
        if [ -n "$recent_trades" ]; then
            echo "$recent_trades"
        else
            echo -e "${YELLOW}  No recent trades found${NC}"
        fi
    else
        echo -e "${YELLOW}  Log file not found${NC}"
    fi
    echo ""
}

# Function to show active orders
show_active_orders() {
    echo -e "${BLUE}📋 ACTIVE ORDERS STATUS:${NC}"
    echo -e "${WHITE}─────────────────────────────────────────${NC}"
    
    LATEST_LOG=$(get_latest_log)
    
    if [ -f "$LATEST_LOG" ]; then
        # Count active orders from recent logs
        grid_orders=$(grep -c "Grid order placed" "$LATEST_LOG" 2>/dev/null || echo "0")
        launch_orders=$(grep -c "Launch trade executed" "$LATEST_LOG" 2>/dev/null || echo "0")
        
        echo -e "${WHITE}  🔲 Grid Orders: $grid_orders${NC}"
        echo -e "${WHITE}  🎯 Launch Orders: $launch_orders${NC}"
        
        # Show recent order activity
        recent_orders=$(grep -E "(order placed|order filled|order cancelled)" "$LATEST_LOG" | tail -n 5 | while read line; do
            timestamp=$(echo "$line" | awk '{print $1}')
            order_info=$(echo "$line" | cut -d'-' -f2- | xargs)
            echo "    $timestamp: $order_info"
        done)
        
        if [ -n "$recent_orders" ]; then
            echo -e "${CYAN}  Recent Order Activity:${NC}"
            echo "$recent_orders"
        fi
    else
        echo -e "${YELLOW}  Log file not accessible${NC}"
    fi
    echo ""
}

# Function to show system status
show_system_status() {
    echo -e "${BLUE}🖥️ SYSTEM STATUS:${NC}"
    echo -e "${WHITE}─────────────────────────────────────────${NC}"
    
    # Check if Hummingbot is running
    if pgrep -f "hummingbot" > /dev/null; then
        echo -e "${GREEN}  ✅ Hummingbot: RUNNING${NC}"
    else
        echo -e "${RED}  ❌ Hummingbot: NOT RUNNING${NC}"
    fi
    
    # Check log file age
    LATEST_LOG=$(get_latest_log)
    if [ -f "$LATEST_LOG" ]; then
        log_age=$(( $(date +%s) - $(stat -c %Y "$LATEST_LOG" 2>/dev/null || stat -f %m "$LATEST_LOG" 2>/dev/null || echo "0") ))
        if [ $log_age -lt 300 ]; then
            echo -e "${GREEN}  ✅ Log Activity: ACTIVE (${log_age}s ago)${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Log Activity: STALE (${log_age}s ago)${NC}"
        fi
    else
        echo -e "${RED}  ❌ Log Activity: NO LOGS FOUND${NC}"
    fi
    
    # Check disk space
    disk_usage=$(df "$HUMMINGBOT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 90 ]; then
        echo -e "${GREEN}  ✅ Disk Space: ${disk_usage}% used${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Disk Space: ${disk_usage}% used${NC}"
    fi
    
    # Check memory usage
    if command -v free &> /dev/null; then
        memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        echo -e "${GREEN}  ✅ Memory Usage: ${memory_usage}%${NC}"
    fi
    
    echo ""
}

# Function to show control options
show_controls() {
    echo -e "${BLUE}🎮 CONTROL OPTIONS:${NC}"
    echo -e "${WHITE}─────────────────────────────────────────${NC}"
    echo -e "${CYAN}  [ENTER] Refresh Display${NC}"
    echo -e "${CYAN}  [Q] Quit Monitor${NC}"
    echo -e "${CYAN}  [L] View Live Logs${NC}"
    echo -e "${CYAN}  [P] View Performance Log${NC}"
    echo -e "${CYAN}  [S] Show Strategy Status${NC}"
    echo -e "${CYAN}  [E] Export Performance Data${NC}"
    echo ""
}

# Function to view live logs
view_live_logs() {
    clear
    echo -e "${PURPLE}📋 LIVE LOGS - Press Ctrl+C to return to monitor${NC}"
    echo -e "${WHITE}═════════════════════════════════════════════════════════════${NC}"
    
    LATEST_LOG=$(get_latest_log)
    if [ -f "$LATEST_LOG" ]; then
        tail -f "$LATEST_LOG" | grep -E "(Ultimate|Grid|Launch|ERROR|WARNING)"
    else
        echo -e "${RED}❌ No log file found${NC}"
        sleep 3
    fi
}

# Function to view performance log
view_performance_log() {
    clear
    echo -e "${PURPLE}📈 PERFORMANCE LOG - Last 10 entries${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════${NC}"
    
    if [ -f "$PERFORMANCE_LOG" ]; then
        tail -n 10 "$PERFORMANCE_LOG" | python3 -c "
import json, sys
for line in sys.stdin:
    try:
        data = json.loads(line.strip())
        timestamp = data.get('timestamp', 'Unknown')[:19]
        balance = data.get('account_balance', 0)
        trades = data.get('total_trades', 0)
        win_rate = data.get('win_rate', 0)
        pnl = data.get('daily_pnl', 0)
        print(f'{timestamp} | Balance: \${balance:.2f} | Trades: {trades} | Win Rate: {win_rate:.1f}% | P&L: \${pnl:+.2f}')
    except:
        pass
"
    else
        echo -e "${YELLOW}No performance log found${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Press ENTER to return to monitor...${NC}"
    read
}

# Function to export performance data
export_performance_data() {
    echo -e "${YELLOW}📤 Exporting performance data...${NC}"
    
    export_file="/tmp/ultimate_hybrid_export_$(date +%Y%m%d_%H%M%S).json"
    
    if [ -f "$PERFORMANCE_LOG" ]; then
        cp "$PERFORMANCE_LOG" "$export_file"
        echo -e "${GREEN}✅ Performance data exported to: $export_file${NC}"
    else
        echo -e "${RED}❌ No performance data to export${NC}"
    fi
    
    sleep 2
}

# Function to show strategy status from Hummingbot
show_strategy_status() {
    clear
    echo -e "${PURPLE}📊 STRATEGY STATUS FROM HUMMINGBOT${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    
    # Try to get status from running Hummingbot instance
    # This is a simplified version - in reality you'd need to interact with Hummingbot's API
    echo -e "${YELLOW}💡 To get detailed strategy status:${NC}"
    echo -e "${CYAN}   1. Open Hummingbot terminal${NC}"
    echo -e "${CYAN}   2. Type: status${NC}"
    echo -e "${CYAN}   3. View comprehensive strategy information${NC}"
    echo ""
    
    # Show what we can from logs
    LATEST_LOG=$(get_latest_log)
    if [ -f "$LATEST_LOG" ]; then
        echo -e "${BLUE}Recent Strategy Messages:${NC}"
        grep -E "(Ultimate Hybrid|Grid initialized|Launch trade|Market Profile)" "$LATEST_LOG" | tail -n 10 | while read line; do
            timestamp=$(echo "$line" | awk '{print $1}')
            message=$(echo "$line" | cut -d'-' -f2- | xargs)
            echo "  $timestamp: $message"
        done
    fi
    
    echo ""
    echo -e "${CYAN}Press ENTER to return to monitor...${NC}"
    read
}

# Main monitoring loop
main_monitor() {
    trap 'echo -e "\n${YELLOW}👋 Monitor stopped. Happy trading!${NC}"; exit 0' INT
    
    while true; do
        show_header
        show_performance
        show_recent_trades
        show_active_orders
        show_system_status
        show_controls
        
        # Wait for user input or timeout
        echo -e "${WHITE}🔄 Auto-refresh in ${REFRESH_INTERVAL}s | Press key for options...${NC}"
        
        if read -t $REFRESH_INTERVAL -n 1 -s input; then
            case $input in
                [Qq]|[Qq]* )
                    echo -e "\n${YELLOW}👋 Exiting monitor. Strategy continues running.${NC}"
                    exit 0
                    ;;
                [Ll]|[Ll]* )
                    view_live_logs
                    ;;
                [Pp]|[Pp]* )
                    view_performance_log
                    ;;
                [Ss]|[Ss]* )
                    show_strategy_status
                    ;;
                [Ee]|[Ee]* )
                    export_performance_data
                    ;;
                * )
                    # Refresh immediately
                    continue
                    ;;
            esac
        fi
    done
}

# Check if Hummingbot directory exists
if [ ! -d "$HUMMINGBOT_DIR" ]; then
    echo -e "${RED}❌ Error: Hummingbot directory not found at $HUMMINGBOT_DIR${NC}"
       echo -e "${YELLOW}📥 Please ensure Hummingbot is installed and Ultimate Hybrid Strategy is configured${NC}"
    exit 1
fi

# Check if log directory exists
if [ ! -d "$LOG_DIR" ]; then
    echo -e "${YELLOW}⚠️  Log directory not found. Creating...${NC}"
    mkdir -p "$LOG_DIR"
fi

# Start monitoring
echo -e "${GREEN}🚀 Starting Ultimate Hybrid Strategy Monitor...${NC}"
sleep 2

main_monitor
