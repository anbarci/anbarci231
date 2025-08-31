#!/bin/bash

# Ultimate Hybrid Strategy - Quick Launcher
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
STRATEGY_SCRIPT="ultimate_hybrid_strategy.py"
CONFIG_FILE="ultimate_hybrid_strategy_config.yml"

# macOS compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    HUMMINGBOT_DIR="$HOME/hummingbot"
fi

echo -e "${PURPLE}=============================================================="
echo -e "${WHITE}🚀      ULTIMATE HYBRID STRATEGY - QUICK LAUNCHER      🚀"
echo -e "${PURPLE}==============================================================${NC}"
echo ""
echo -e "${CYAN}📦 Repository: https://github.com/anbarci/hummingbot-ultimate-hybrid"
echo -e "${CYAN}📊 Version: 2.0"
echo -e "${CYAN}👤 Author: anbarci"
echo ""

# Check if Hummingbot directory exists
if [ ! -d "$HUMMINGBOT_DIR" ]; then
    echo -e "${RED}❌ Error: Hummingbot not found at $HUMMINGBOT_DIR${NC}"
    echo ""
    echo -e "${YELLOW}📥 Please install Hummingbot first:${NC}"
    echo -e "${CYAN}   curl -sSL https://install.hummingbot.io | bash${NC}"
    echo ""
    exit 1
fi

# Check if strategy files exist
if [ ! -f "$HUMMINGBOT_DIR/scripts/$STRATEGY_SCRIPT" ]; then
    echo -e "${RED}❌ Error: Strategy script not found${NC}"
    echo -e "${YELLOW}📥 Please install Ultimate Hybrid Strategy first:${NC}"
    echo -e "${CYAN}   curl -sSL https://raw.githubusercontent.com/anbarci/hummingbot-ultimate-hybrid/main/install.sh | bash${NC}"
    echo ""
    exit 1
fi

# Pre-flight checks
echo -e "${YELLOW}🔍 Running pre-flight checks...${NC}"

# Check strategy file
if [ -f "$HUMMINGBOT_DIR/scripts/$STRATEGY_SCRIPT" ]; then
    echo -e "${GREEN}  ✅ Strategy script found${NC}"
else
    echo -e "${RED}  ❌ Strategy script missing${NC}"
    exit 1
fi

# Check config file
if [ -f "$HUMMINGBOT_DIR/conf/$CONFIG_FILE" ]; then
    echo -e "${GREEN}  ✅ Configuration file found${NC}"
else
    echo -e "${YELLOW}  ⚠️  Configuration file not found - will use defaults${NC}"
fi

# Check if Hummingbot is already running
if pgrep -f "hummingbot" > /dev/null; then
    echo -e "${YELLOW}  ⚠️  Hummingbot appears to be already running${NC}"
    echo -e "${CYAN}     If you want to restart, stop the existing instance first${NC}"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}  ✅ Pre-flight checks completed${NC}"
echo ""

# Display strategy information
echo -e "${BLUE}🎯 STRATEGY OVERVIEW:${NC}"
echo -e "${WHITE}  🔲 Grid Trading: ATR-based 8-level dynamic system${NC}"
echo -e "${WHITE}  🎯 Launch Strategy: NY session needle detection${NC}"
echo -e "${WHITE}  📊 Market Profile: POC/VAH/VAL integration${NC}"
echo -e "${WHITE}  ⚠️  Risk Management: 12% portfolio, 4% position limits${NC}"
echo -e "${WHITE}  📈 Expected Performance: 55-70% win rate combined${NC}"
echo ""

# Warning message
echo -e "${RED}⚠️  IMPORTANT TRADING WARNINGS:${NC}"
echo -e "${YELLOW}  • Ensure API keys are configured in Hummingbot${NC}"
echo -e "${YELLOW}  • Have minimum \$50 balance available${NC}"
echo -e "${YELLOW}  • Start with small position sizes${NC}"
echo -e "${YELLOW}  • Monitor closely for first few hours${NC}"
echo -e "${YELLOW}  • Cryptocurrency trading involves risk of loss${NC}"
echo ""

# Confirmation
echo -e "${WHITE}🚀 Ready to launch Ultimate Hybrid Strategy?${NC}"
read -p "Press ENTER to continue or Ctrl+C to cancel..."
echo ""

# Change to Hummingbot directory
cd "$HUMMINGBOT_DIR" || {
    echo -e "${RED}❌ Error: Cannot access Hummingbot directory${NC}"
    exit 1
}

echo -e "${YELLOW}🚀 Starting Ultimate Hybrid Strategy...${NC}"
echo ""

# Launch strategy
if [ -f "conf/$CONFIG_FILE" ]; then
    echo -e "${CYAN}📊 Using configuration file: $CONFIG_FILE${NC}"
    echo -e "${CYAN}🔧 Starting Hummingbot with Ultimate Hybrid Strategy...${NC}"
    echo ""
    ./bin/hummingbot start --script "$STRATEGY_SCRIPT" --conf "$CONFIG_FILE"
else
    echo -e "${CYAN}📊 Using default configuration${NC}"
    echo -e "${CYAN}🔧 Starting Hummingbot with Ultimate Hybrid Strategy...${NC}"
    echo ""
    ./bin/hummingbot start --script "$STRATEGY_SCRIPT"
fi

# Post-launch message
echo ""
echo -e "${GREEN}🎉 Ultimate Hybrid Strategy launch sequence completed!${NC}"
echo ""
echo -e "${BLUE}📊 For real-time monitoring:${NC}"
echo -e "${CYAN}   $HUMMINGBOT_DIR/monitor_strategy.sh${NC}"
echo ""
echo -e "${BLUE}📚 Documentation and support:${NC}"
echo -e "${CYAN}   https://github.com/anbarci/hummingbot-ultimate-hybrid${NC}"
echo ""
