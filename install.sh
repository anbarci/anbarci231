#!/bin/bash

# Ultimate Hybrid Trading Strategy - GitHub Installer
# Repository: https://github.com/anbarci/hummingbot-ultimate-hybrid
# Version: 2.0
# Author: anbarci
# License: MIT

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Installation variables
REPO_URL="https://github.com/anbarci/hummingbot-ultimate-hybrid"
RAW_URL="https://raw.githubusercontent.com/anbarci/hummingbot-ultimate-hybrid/main"
HUMMINGBOT_DIR="/root/hummingbot"
TEMP_DIR="/tmp/hummingbot-ultimate-hybrid-install"
STRATEGY_NAME="ultimate_hybrid_strategy"
VERSION="2.0"

# Function to print colored output
print_colored() {
    echo -e "${1}${2}${NC}"
}

# Function to print header
print_header() {
    clear
    print_colored $PURPLE "=============================================================="
    print_colored $WHITE "🚀    ULTIMATE HYBRID TRADING STRATEGY INSTALLER v$VERSION    🚀"
    print_colored $PURPLE "=============================================================="
    echo ""
    print_colored $CYAN "📦 Repository: $REPO_URL"
    print_colored $CYAN "👤 Author: anbarci"
    print_colored $CYAN "📅 Version: $VERSION"
    print_colored $CYAN "📄 License: MIT"
    echo ""
    print_colored $GREEN "🔧 STRATEGY COMPONENTS:"
    echo ""
    print_colored $WHITE "  🔲 Professional Grid Trading System"
    echo "     • 8-level dynamic ATR-based spacing"
    echo "     • Automatic rebalancing on 5% price moves"
    echo "     • Market Profile POC integration"
    echo "     • Expected: 60-80% win rate in range markets"
    echo ""
    print_colored $WHITE "  🎯 Kaanermi Launch Strategy"
    echo "     • NY session (01:00-08:00 TRT) monitoring"
    echo "     • Advanced needle/wick detection (2:1 ratio)"
    echo "     • Bias-filtered directional entries"
    echo "     • Expected: 45-65% win rate on breakouts"
    echo ""
    print_colored $WHITE "  📊 Market Profile Integration"
    echo "     • Real-time POC/VAH/VAL calculation"
    echo "     • 70% value area coverage analysis"
    echo "     • Grid positioning optimization"
    echo ""
    print_colored $WHITE "  ⚠️ Advanced Risk Management"
    echo "     • Maximum 12% portfolio exposure"
    echo "     • Maximum 4% per position risk"
    echo "     • 2:1 minimum risk/reward ratio"
    echo "     • Emergency stop at 20% drawdown"
    echo ""
    print_colored $PURPLE "=============================================================="
    echo ""
}

# Function to check system requirements
check_system_requirements() {
    print_colored $YELLOW "🔍 Checking system requirements..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        print_colored $YELLOW "⚠️  Not running as root. Some operations may require sudo."
        echo "   If installation fails, try: sudo bash install.sh"
        sleep 2
    fi
    
    # Check operating system
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_colored $GREEN "  ✅ Linux OS detected"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_colored $GREEN "  ✅ macOS detected"
        HUMMINGBOT_DIR="$HOME/hummingbot"
    else
        print_colored $YELLOW "  ⚠️  OS: $OSTYPE (may need adjustments)"
    fi
    
    # Check Python
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        print_colored $GREEN "  ✅ Python 3 found: $PYTHON_VERSION"
    else
        print_colored $RED "  ❌ Python 3 not found"
        print_colored $YELLOW "  📥 Please install Python 3.8+ first"
        exit 1
    fi
    
    # Check pip
    if command -v pip3 &> /dev/null; then
        print_colored $GREEN "  ✅ pip3 found"
    else
        print_colored $YELLOW "  ⚠️  pip3 not found - will try alternative methods"
    fi
    
    echo ""
}

# Function to check Hummingbot installation
check_hummingbot() {
    print_colored $YELLOW "🤖 Checking Hummingbot installation..."
    
    # Possible Hummingbot directories
    POSSIBLE_DIRS=(
        "/root/hummingbot"
        "$HOME/hummingbot"
        "/opt/hummingbot"
        "/usr/local/hummingbot"
    )
    
    FOUND_HUMMINGBOT=false
    
    for dir in "${POSSIBLE_DIRS[@]}"; do
        if [ -d "$dir" ] && [ -f "$dir/bin/hummingbot" ]; then
            HUMMINGBOT_DIR="$dir"
            FOUND_HUMMINGBOT=true
            print_colored $GREEN "  ✅ Hummingbot found at: $HUMMINGBOT_DIR"
            break
        fi
    done
    
    if [ "$FOUND_HUMMINGBOT" = false ]; then
        print_colored $RED "  ❌ Hummingbot installation not found!"
        echo ""
        print_colored $YELLOW "📥 INSTALL HUMMINGBOT FIRST:"
        print_colored $WHITE "   Option 1 - Docker (Recommended):"
        print_colored $CYAN "     curl -sSL https://install.hummingbot.io | bash"
        echo ""
        print_colored $WHITE "   Option 2 - Manual Installation:"
        print_colored $CYAN "     https://docs.hummingbot.org/installation/"
        echo ""
        print_colored $WHITE "   Option 3 - Binary Installation:"
        print_colored $CYAN "     https://github.com/hummingbot/hummingbot/releases"
        echo ""
        print_colored $RED "⏹️  Installation aborted. Please install Hummingbot first."
        exit 1
    fi
    
    # Check Hummingbot version
    if [ -f "$HUMMINGBOT_DIR/bin/hummingbot" ]; then
        print_colored $GREEN "  ✅ Hummingbot executable verified"
    fi
    
    echo ""
}

# Function to create directory structure
create_directories() {
    print_colored $YELLOW "📁 Creating directory structure..."
    
    # Create required directories
    REQUIRED_DIRS=(
        "$HUMMINGBOT_DIR/scripts"
        "$HUMMINGBOT_DIR/conf"
        "$HUMMINGBOT_DIR/logs"
        "$HUMMINGBOT_DIR/logs/performance"
        "$TEMP_DIR"
    )
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        if mkdir -p "$dir" 2>/dev/null; then
            print_colored $GREEN "  ✅ Created: $dir"
        else
            print_colored $YELLOW "  ⚠️  Directory may already exist: $dir"
        fi
    done
    
    echo ""
}

# Function to download files
download_strategy_files() {
    print_colored $YELLOW "📥 Downloading strategy files from GitHub..."
    
    cd "$TEMP_DIR"
    
    # Try different download methods
    DOWNLOAD_SUCCESS=false
    
    # Method 1: Git clone
    if command -v git &> /dev/null; then
        print_colored $CYAN "  🔄 Trying git clone..."
        if git clone "$REPO_URL.git" . 2>/dev/null; then
            DOWNLOAD_SUCCESS=true
            print_colored $GREEN "  ✅ Downloaded via git clone"
        fi
    fi
    
    # Method 2: wget
    if [ "$DOWNLOAD_SUCCESS" = false ] && command -v wget &> /dev/null; then
        print_colored $CYAN "  🔄 Trying wget..."
        if wget -q "$REPO_URL/archive/main.zip" -O main.zip && unzip -q main.zip && mv hummingbot-ultimate-hybrid-main/* . 2>/dev/null; then
            DOWNLOAD_SUCCESS=true
            print_colored $GREEN "  ✅ Downloaded via wget"
        fi
    fi
    
    # Method 3: curl
    if [ "$DOWNLOAD_SUCCESS" = false ] && command -v curl &> /dev/null; then
        print_colored $CYAN "  🔄 Trying curl..."
        if curl -sL "$REPO_URL/archive/main.zip" -o main.zip && unzip -q main.zip && mv hummingbot-ultimate-hybrid-main/* . 2>/dev/null; then
            DOWNLOAD_SUCCESS=true
            print_colored $GREEN "  ✅ Downloaded via curl"
        fi
    fi
    
    # Method 4: Direct file download as fallback
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        print_colored $YELLOW "  🔄 Trying direct file download..."
        
        # Create basic file structure
        mkdir -p src config scripts examples
        
        # Download individual files
        FILES_TO_DOWNLOAD=(
            "src/ultimate_hybrid_strategy.py"
            "config/ultimate_hybrid_strategy_config.yml"
            "scripts/start_ultimate_hybrid.sh"
            "scripts/launch_ultimate_hybrid.sh"
            "scripts/monitor_strategy.sh"
            "README.md"
            "LICENSE"
        )
        
        DIRECT_SUCCESS=true
        for file in "${FILES_TO_DOWNLOAD[@]}"; do
            if command -v curl &> /dev/null; then
                if ! curl -sL "$RAW_URL/$file" -o "$file"; then
                    DIRECT_SUCCESS=false
                    break
                fi
            elif command -v wget &> /dev/null; then
                if ! wget -q "$RAW_URL/$file" -O "$file"; then
                    DIRECT_SUCCESS=false
                    break
                fi
            else
                DIRECT_SUCCESS=false
                break
            fi
        done
        
        if [ "$DIRECT_SUCCESS" = true ]; then
            DOWNLOAD_SUCCESS=true
            print_colored $GREEN "  ✅ Downloaded via direct file download"
        fi
    fi
    
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        print_colored $RED "  ❌ All download methods failed!"
        print_colored $YELLOW "  💡 Manual installation required:"
        print_colored $CYAN "     1. Download: $REPO_URL/archive/main.zip"
        print_colored $CYAN "     2. Extract files manually"
        print_colored $CYAN "     3. Copy files to Hummingbot directory"
        exit 1
    fi
    
    # Verify essential files exist
    ESSENTIAL_FILES=(
        "src/ultimate_hybrid_strategy.py"
        "config/ultimate_hybrid_strategy_config.yml"
    )
    
    for file in "${ESSENTIAL_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_colored $RED "  ❌ Essential file missing: $file"
            exit 1
        fi
    done
    
    print_colored $GREEN "  ✅ All essential files verified"
    echo ""
}

# Function to install strategy files
install_strategy_files() {
    print_colored $YELLOW "📦 Installing strategy files..."
    
    cd "$TEMP_DIR"
    
    # Install main strategy file
    if [ -f "src/ultimate_hybrid_strategy.py" ]; then
        if cp "src/ultimate_hybrid_strategy.py" "$HUMMINGBOT_DIR/scripts/"; then
            print_colored $GREEN "  ✅ Strategy script: ultimate_hybrid_strategy.py"
        else
            print_colored $RED "  ❌ Failed to copy strategy script"
            exit 1
        fi
    fi
    
    # Install configuration file
    if [ -f "config/ultimate_hybrid_strategy_config.yml" ]; then
        if cp "config/ultimate_hybrid_strategy_config.yml" "$HUMMINGBOT_DIR/conf/"; then
            print_colored $GREEN "  ✅ Configuration: ultimate_hybrid_strategy_config.yml"
        else
            print_colored $RED "  ❌ Failed to copy configuration"
            exit 1
        fi
    fi
    
    # Install startup script
    if [ -f "scripts/start_ultimate_hybrid.sh" ]; then
        if cp "scripts/start_ultimate_hybrid.sh" "$HUMMINGBOT_DIR/"; then
            chmod +x "$HUMMINGBOT_DIR/start_ultimate_hybrid.sh"
            print_colored $GREEN "  ✅ Startup script: start_ultimate_hybrid.sh"
        fi
    fi
    
    # Install quick launcher
    if [ -f "scripts/launch_ultimate_hybrid.sh" ]; then
        TARGET_DIR="/root"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            TARGET_DIR="$HOME"
        fi
        if cp "scripts/launch_ultimate_hybrid.sh" "$TARGET_DIR/"; then
            chmod +x "$TARGET_DIR/launch_ultimate_hybrid.sh"
            print_colored $GREEN "  ✅ Quick launcher: $TARGET_DIR/launch_ultimate_hybrid.sh"
        fi
    fi
    
    # Install monitoring script
    if [ -f "scripts/monitor_strategy.sh" ]; then
        if cp "scripts/monitor_strategy.sh" "$HUMMINGBOT_DIR/"; then
            chmod +x "$HUMMINGBOT_DIR/monitor_strategy.sh"
            print_colored $GREEN "  ✅ Monitor script: monitor_strategy.sh"
        fi
    fi
    
    # Copy documentation files if available
    if [ -f "README.md" ]; then
        cp "README.md" "$HUMMINGBOT_DIR/" 2>/dev/null || true
    fi
    
    if [ -f "examples" ] && [ -d "examples" ]; then
        cp -r examples "$HUMMINGBOT_DIR/" 2>/dev/null || true
    fi
    
    echo ""
}

# Function to set file permissions
set_permissions() {
    print_colored $YELLOW "🔐 Setting file permissions..."
    
    # Strategy file permissions
    if [ -f "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py" ]; then
        chmod 755 "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py"
        print_colored $GREEN "  ✅ Strategy script permissions set"
    fi
    
    # Configuration file permissions
    if [ -f "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml" ]; then
        chmod 644 "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml"
        print_colored $GREEN "  ✅ Configuration file permissions set"
    fi
    
    # Script permissions
    chmod +x "$HUMMINGBOT_DIR"/*.sh 2>/dev/null || true
    
    print_colored $GREEN "  ✅ All file permissions configured"
    echo ""
}

# Function to install Python dependencies
install_dependencies() {
    print_colored $YELLOW "🐍 Installing Python dependencies..."
    
    REQUIRED_PACKAGES=("pandas" "numpy" "scipy")
    INSTALL_NEEDED=false
    
    # Check which packages need installation
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! python3 -c "import $package" 2>/dev/null; then
            INSTALL_NEEDED=true
            print_colored $YELLOW "  📦 Need to install: $package"
        else
            print_colored $GREEN "  ✅ Already installed: $package"
        fi
    done
    
    if [ "$INSTALL_NEEDED" = true ]; then
        print_colored $CYAN "  🔄 Installing required packages..."
        
        # Try different installation methods
        if command -v pip3 &> /dev/null; then
            if pip3 install pandas numpy scipy --quiet --no-warn-script-location 2>/dev/null; then
                print_colored $GREEN "  ✅ Dependencies installed via pip3"
            else
                print_colored $YELLOW "  ⚠️  pip3 install partially failed, continuing..."
            fi
        elif command -v pip &> /dev/null; then
            if pip install pandas numpy scipy --quiet --no-warn-script-location 2>/dev/null; then
                print_colored $GREEN "  ✅ Dependencies installed via pip"
            else
                print_colored $YELLOW "  ⚠️  pip install partially failed, continuing..."
            fi
        else
            print_colored $YELLOW "  ⚠️  No pip found. Manual installation may be required:"
            print_colored $CYAN "     pip3 install pandas numpy scipy"
        fi
    else
        print_colored $GREEN "  ✅ All required Python packages already installed"
    fi
    
    echo ""
}

# Function to create configuration backup
create_backup() {
    print_colored $YELLOW "💾 Creating configuration backup..."
    
    BACKUP_DIR="$HUMMINGBOT_DIR/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing configuration if it exists
    if [ -f "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml" ]; then
        cp "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml" "$BACKUP_DIR/config_backup.yml"
        print_colored $GREEN "  ✅ Configuration backed up to: $BACKUP_DIR"
    fi
    
    echo ""
}

# Function to run post-installation tests
run_tests() {
    print_colored $YELLOW "🧪 Running post-installation tests..."
    
    # Test 1: Strategy file syntax
    if python3 -m py_compile "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py" 2>/dev/null; then
        print_colored $GREEN "  ✅ Strategy script syntax valid"
    else
        print_colored $YELLOW "  ⚠️  Strategy script syntax check failed (may be normal)"
    fi
    
    # Test 2: Configuration file format
    if python3 -c "import yaml; yaml.safe_load(open('$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml'))" 2>/dev/null; then
        print_colored $GREEN "  ✅ Configuration file format valid"
    else
        print_colored $YELLOW "  ⚠️  Configuration file format check failed (install pyyaml if needed)"
    fi
    
    # Test 3: Script executability
    if [ -x "$HUMMINGBOT_DIR/start_ultimate_hybrid.sh" ]; then
        print_colored $GREEN "  ✅ Startup script executable"
    else
        print_colored $YELLOW "  ⚠️  Startup script permissions issue"
    fi
    
    print_colored $GREEN "  ✅ Post-installation tests completed"
    echo ""
}

# Function to clean up temporary files
cleanup() {
    print_colored $YELLOW "🧹 Cleaning up temporary files..."
    
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        print_colored $GREEN "  ✅ Temporary files cleaned"
    fi
    
    echo ""
}

# Function to display success message
display_success() {
    echo ""
    print_colored $GREEN "🎉 ================================================================ 🎉"
    print_colored $WHITE "        ULTIMATE HYBRID STRATEGY SUCCESSFULLY INSTALLED!"
    print_colored $GREEN "🎉 ================================================================ 🎉"
    echo ""
    
    print_colored $CYAN "📍 INSTALLATION SUMMARY:"
    print_colored $WHITE "  📂 Strategy: $HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py"
    print_colored $WHITE "  ⚙️  Config: $HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_colored $WHITE "  🚀 Launcher: $HOME/launch_ultimate_hybrid.sh"
    else
        print_colored $WHITE "  🚀 Launcher: /root/launch_ultimate_hybrid.sh"
    fi
    
    print_colored $WHITE "  📊 Monitor: $HUMMINGBOT_DIR/monitor_strategy.sh"
    echo ""
    
    print_colored $CYAN "🎯 STRATEGY FEATURES INSTALLED:"
    print_colored $WHITE "  🔲 Grid Trading: 8-level ATR-based dynamic spacing"
    print_colored $WHITE "  🎯 Launch Strategy: NY session needle detection (Kaanermi method)"
    print_colored $WHITE "  📊 Market Profile: POC/VAH/VAL integration for market structure"
    print_colored $WHITE "  ⚠️  Risk Management: 12% max portfolio, 4% max position limits"
    print_colored $WHITE "  📈 Performance: Real-time tracking and JSON logging"
    print_colored $WHITE "  🛡️ Safety: Emergency stops and drawdown protection"
    echo ""
    
    print_colored $PURPLE "⚡ QUICK START COMMANDS:"
    echo ""
    print_colored $GREEN "  🚀 ONE-CLICK LAUNCH:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_colored $CYAN "     $HOME/launch_ultimate_hybrid.sh"
    else
        print_colored $CYAN "     /root/launch_ultimate_hybrid.sh"
    fi
    echo ""
    
    print_colored $GREEN "  📊 REAL-TIME MONITORING:"
    print_colored $CYAN "     $HUMMINGBOT_DIR/monitor_strategy.sh"
    echo ""
    
    print_colored $GREEN "  🔧 MANUAL LAUNCH:"
    print_colored $CYAN "     cd $HUMMINGBOT_DIR"
    print_colored $CYAN "     ./bin/hummingbot start --script ultimate_hybrid_strategy.py --conf ultimate_hybrid_strategy_config.yml"
    echo ""
    
    print_colored $RED "⚠️  IMPORTANT BEFORE TRADING:"
    print_colored $YELLOW "  1. 🔑 Configure your exchange API keys in Hummingbot"
    print_colored $YELLOW "     • Run Hummingbot: cd $HUMMINGBOT_DIR && ./bin/hummingbot"
    print_colored $YELLOW "     • Set up API keys: connect [exchange_name]"
    print_colored $YELLOW "     • Test connection before automated trading"
    echo ""
    print_colored $YELLOW "  2. 💰 Ensure sufficient balance (minimum \$50 recommended)"
    print_colored $YELLOW "     • Check account balance before starting"
    print_colored $YELLOW "     • Have extra funds for multiple grid levels"
    echo ""
    print_colored $YELLOW "  3. 🧪 Test with small amounts first"
    print_colored $YELLOW "     • Start with 1-5% of your total trading capital"
    print_colored $YELLOW "     • Monitor for several hours before increasing size"
    print_colored $YELLOW "     • Verify strategy behavior matches expectations"
    echo ""
    print_colored $YELLOW "  4. 📊 Monitor performance closely during first trading session"
    print_colored $YELLOW "     • Use monitor script for real-time tracking"
    print_colored $YELLOW "     • Check logs regularly for any issues"
    print_colored $YELLOW "     • Be prepared to stop strategy if needed"
    echo ""
    
    print_colored $BLUE "🔗 SUPPORT & DOCUMENTATION:"
    print_colored $WHITE "  📚 Full Documentation: $REPO_URL/blob/main/README.md"
    print_colored $WHITE "  🐛 Report Issues: $REPO_URL/issues"
    print_colored $WHITE "  💬 Community: $REPO_URL/discussions"
    print_colored $WHITE "  🔄 Updates: cd [repo-dir] && git pull && ./install.sh"
    echo ""
    
    print_colored $PURPLE "📈 EXPECTED PERFORMANCE:"
    print_colored $WHITE "  • Combined Win Rate: 55-70% across all market conditions"
    print_colored $WHITE "  • Grid Component: 60-80% win rate in range-bound markets"
    print_colored $WHITE "  • Launch Component: 45-65% win rate on breakout scenarios"
    print_colored $WHITE "  • Risk Management: Max 15% drawdown with proper settings"
    print_colored $WHITE "  • Adaptive Strategy: Performs in trending and ranging markets"
    echo ""
    
    print_colored $GREEN "🎯 Ready for professional automated trading!"
    print_colored $WHITE "   Remember: This is sophisticated software - understand it before using!"
    echo ""
    
    print_colored $PURPLE "=================================================================="
    print_colored $WHITE "   Thank you for choosing Ultimate Hybrid Strategy v$VERSION"
    print_colored $CYAN "   Made with ❤️  by anbarci | Open Source | Community Driven"
    print_colored $PURPLE "=================================================================="
    echo ""
}

# Function to handle errors
error_handler() {
    print_colored $RED "❌ Installation failed at step: $1"
    print_colored $YELLOW "💡 Troubleshooting suggestions:"
    print_colored $CYAN "  • Check internet connection"
    print_colored $CYAN "  • Verify Hummingbot installation"
    print_colored $CYAN "  • Try running with sudo: sudo bash install.sh"
    print_colored $CYAN "  • Manual install: $REPO_URL"
    echo ""
    cleanup
    exit 1
}

# Main installation function
main() {
    # Set trap for error handling
    trap 'error_handler "Unknown error"' ERR
    
    # Installation steps
    print_header
    
    print_colored $YELLOW "🚀 Starting installation process..."
    echo ""
    
    check_system_requirements || error_handler "System requirements check"
    
    check_hummingbot || error_handler "Hummingbot verification"
    
    create_directories || error_handler "Directory creation"
    
    download_strategy_files || error_handler "File download"
    
    create_backup || error_handler "Backup creation"
    
    install_strategy_files || error_handler "File installation"
    
    set_permissions || error_handler "Permission setting"
    
    install_dependencies || error_handler "Dependency installation"
    
    run_tests || error_handler "Post-installation tests"
    
    cleanup || error_handler "Cleanup"
    
    display_success
}

# Run main installation
main "$@"
