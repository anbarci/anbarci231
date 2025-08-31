#!/bin/bash

# Ultimate Hybrid Strategy - Automated Installer
# Repository: https://github.com/anbarci/hummingbot-ultimate-hybrid
# Version: 2.0

set -e  # Exit on any error

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
REPO_URL="https://github.com/anbarci/hummingbot-ultimate-hybrid"
RAW_URL="https://raw.githubusercontent.com/anbarci/hummingbot-ultimate-hybrid/main"
HUMMINGBOT_DIR="/root/hummingbot"
TEMP_DIR="/tmp/ultimate_hybrid_install"

# macOS compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    HUMMINGBOT_DIR="$HOME/hummingbot"
fi

# Installation functions
show_banner() {
    clear
    echo -e "${PURPLE}████████████████████████████████████████████████████████████████████████████████"
    echo -e "${WHITE}██                                                                                ██"
    echo -e "${WHITE}██         🚀 ULTIMATE HYBRID STRATEGY - AUTOMATED INSTALLER 🚀            ██"
    echo -e "${WHITE}██                                                                                ██"
    echo -e "${PURPLE}████████████████████████████████████████████████████████████████████████████████${NC}"
    echo ""
    echo -e "${CYAN}📦 Repository: $REPO_URL"
    echo -e "${CYAN}📊 Version: 2.0"
    echo -e "${CYAN}👤 Author: anbarci"
    echo -e "${CYAN}📄 License: MIT"
    echo ""
}

check_requirements() {
    echo -e "${YELLOW}🔍 Checking system requirements...${NC}"
    
    # Check if running as root on Linux
    if [[ "$OSTYPE" != "darwin"* ]] && [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root on Linux systems${NC}"
        echo -e "${CYAN}   Please run: sudo $0${NC}"
        exit 1
    fi
    
    # Check for required commands
    local required_commands=("curl" "python3")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing required commands: ${missing_commands[*]}${NC}"
        echo -e "${YELLOW}📥 Please install missing dependencies and try again${NC}"
        exit 1
    fi
    
    # Check Hummingbot installation
    if [ ! -d "$HUMMINGBOT_DIR" ]; then
        echo -e "${RED}❌ Hummingbot not found at $HUMMINGBOT_DIR${NC}"
        echo ""
        echo -e "${YELLOW}📥 To install Hummingbot, run:${NC}"
        echo -e "${CYAN}   curl -sSL https://install.hummingbot.io | bash${NC}"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}  ✅ System requirements satisfied${NC}"
}

create_temp_directory() {
    echo -e "${YELLOW}📁 Creating temporary installation directory...${NC}"
    
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    mkdir -p "$TEMP_DIR"
    echo -e "${GREEN}  ✅ Temporary directory created${NC}"
}

backup_existing_files() {
    echo -e "${YELLOW}💾 Backing up existing files...${NC}"
    
    local backup_dir="$HUMMINGBOT_DIR/backups/ultimate_hybrid_$(date +%Y%m%d_%H%M%S)"
    
    # Check if strategy already exists
    if [ -f "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py" ]; then
        mkdir -p "$backup_dir"
        cp "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py" "$backup_dir/"
        echo -e "${GREEN}  ✅ Strategy script backed up${NC}"
    fi
    
    # Check if config already exists
    if [ -f "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml" ]; then
        mkdir -p "$backup_dir"
        cp "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml" "$backup_dir/"
        echo -e "${GREEN}  ✅ Configuration file backed up${NC}"
    fi
    
    if [ -d "$backup_dir" ]; then
        echo -e "${CYAN}  📁 Backups saved to: $backup_dir${NC}"
    fi
}

download_strategy_files() {
    echo -e "${YELLOW}⬇️  Downloading Ultimate Hybrid Strategy files...${NC}"
    
    local files=(
        "src/ultimate_hybrid_strategy.py:scripts/ultimate_hybrid_strategy.py"
        "config/ultimate_hybrid_strategy_config.yml:conf/ultimate_hybrid_strategy_config.yml"
        "scripts/launch_ultimate_hybrid.sh:launch_ultimate_hybrid.sh"
        "scripts/monitor_strategy.sh:monitor_strategy.sh"
        "README.md:ultimate_hybrid_README.md"
    )
    
    for file_mapping in "${files[@]}"; do
        local source_file="${file_mapping%%:*}"
        local dest_file="${file_mapping##*:}"
        local dest_path="$TEMP_DIR/$dest_file"
        
        echo -e "${CYAN}    📥 Downloading $source_file...${NC}"
        
        if curl -sSL "$RAW_URL/$source_file" -o "$dest_path"; then
            echo -e "${GREEN}      ✅ Downloaded successfully${NC}"
        else
            echo -e "${RED}      ❌ Download failed${NC}"
            exit 1
        fi
    done
}

install_strategy_files() {
    echo -e "${YELLOW}📦 Installing Ultimate Hybrid Strategy files...${NC}"
    
    # Create necessary directories
    mkdir -p "$HUMMINGBOT_DIR/scripts"
    mkdir -p "$HUMMINGBOT_DIR/conf"
    mkdir -p "$HUMMINGBOT_DIR/logs"
    
    # Install strategy script
    if cp "$TEMP_DIR/scripts/ultimate_hybrid_strategy.py" "$HUMMINGBOT_DIR/scripts/"; then
        echo -e "${GREEN}  ✅ Strategy script installed${NC}"
    else
        echo -e "${RED}  ❌ Failed to install strategy script${NC}"
        exit 1
    fi
    
    # Install config file (don't overwrite existing)
    if [ ! -f "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml" ]; then
        if cp "$TEMP_DIR/conf/ultimate_hybrid_strategy_config.yml" "$HUMMINGBOT_DIR/conf/"; then
            echo -e "${GREEN}  ✅ Configuration file installed${NC}"
        else
            echo -e "${RED}  ❌ Failed to install configuration file${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}  ⚠️  Configuration file exists - keeping current version${NC}"
    fi
    
    # Install launcher scripts
    if cp "$TEMP_DIR/launch_ultimate_hybrid.sh" "$HUMMINGBOT_DIR/"; then
        chmod +x "$HUMMINGBOT_DIR/launch_ultimate_hybrid.sh"
        echo -e "${GREEN}  ✅ Launch script installed${NC}"
    else
        echo -e "${RED}  ❌ Failed to install launch script${NC}"
        exit 1
    fi
    
    if cp "$TEMP_DIR/monitor_strategy.sh" "$HUMMINGBOT_DIR/"; then
        chmod +x "$HUMMINGBOT_DIR/monitor_strategy.sh"
        echo -e "${GREEN}  ✅ Monitor script installed${NC}"
    else
        echo -e "${RED}  ❌ Failed to install monitor script${NC}"
        exit 1
    fi
    
    # Install documentation
    if cp "$TEMP_DIR/ultimate_hybrid_README.md" "$HUMMINGBOT_DIR/"; then
        echo -e "${GREEN}  ✅ Documentation installed${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Documentation install failed (non-critical)${NC}"
    fi
}

setup_permissions() {
    echo -e "${YELLOW}🔐 Setting up file permissions...${NC}"
    
    # Set appropriate permissions
    chmod 644 "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py"
    chmod 644 "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml"
    chmod 755 "$HUMMINGBOT_DIR/launch_ultimate_hybrid.sh"
    chmod 755 "$HUMMINGBOT_DIR/monitor_strategy.sh"
    
    # Ensure log directory is writable
    chmod 755 "$HUMMINGBOT_DIR/logs"
    
    echo -e "${GREEN}  ✅ Permissions configured${NC}"
}

validate_installation() {
    echo -e "${YELLOW}🔍 Validating installation...${NC}"
    
    # Check strategy script
    if [ -f "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py" ] && [ -r "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py" ]; then
        echo -e "${GREEN}  ✅ Strategy script: OK${NC}"
    else
        echo -e "${RED}  ❌ Strategy script: FAILED${NC}"
        exit 1
    fi
    
    # Check config file
    if [ -f "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml" ] && [ -r "$HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml" ]; then
        echo -e "${GREEN}  ✅ Configuration file: OK${NC}"
    else
        echo -e "${RED}  ❌ Configuration file: FAILED${NC}"
        exit 1
    fi
    
    # Check launcher scripts
    if [ -x "$HUMMINGBOT_DIR/launch_ultimate_hybrid.sh" ]; then
        echo -e "${GREEN}  ✅ Launch script: OK${NC}"
    else
        echo -e "${RED}  ❌ Launch script: FAILED${NC}"
        exit 1
    fi
    
    if [ -x "$HUMMINGBOT_DIR/monitor_strategy.sh" ]; then
        echo -e "${GREEN}  ✅ Monitor script: OK${NC}"
    else
        echo -e "${RED}  ❌ Monitor script: FAILED${NC}"
        exit 1
    fi
    
    # Validate Python syntax
    if python3 -m py_compile "$HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py" 2>/dev/null; then
        echo -e "${GREEN}  ✅ Python syntax: VALID${NC}"
    else
        echo -e "${RED}  ❌ Python syntax: INVALID${NC}"
        exit 1
    fi
}

create_desktop_shortcuts() {
    echo -e "${YELLOW}🖥️  Creating desktop shortcuts...${NC}"
    
    # Only create shortcuts on Linux with desktop environment
    if [[ "$OSTYPE" != "darwin"* ]] && [ -d "/home" ] && command -v xdg-user-dir &> /dev/null; then
        local desktop_dir
        desktop_dir=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")
        
        if [ -d "$desktop_dir" ]; then
            # Launch shortcut
            cat > "$desktop_dir/Launch_Ultimate_Hybrid.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Launch Ultimate Hybrid Strategy
Comment=Start Ultimate Hybrid Trading Strategy
Exec=gnome-terminal -- bash -c '$HUMMINGBOT_DIR/launch_ultimate_hybrid.sh; exec bash'
Icon=utilities-terminal
Terminal=false
StartupNotify=false
Categories=Office;Finance;
EOF
            
            # Monitor shortcut
            cat > "$desktop_dir/Monitor_Ultimate_Hybrid.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Monitor Ultimate Hybrid Strategy
Comment=Monitor Ultimate Hybrid Trading Strategy Performance
Exec=gnome-terminal -- bash -c '$HUMMINGBOT_DIR/monitor_strategy.sh; exec bash'
Icon=utilities-system-monitor
Terminal=false
StartupNotify=false
Categories=Office;Finance;
EOF
            
            chmod +x "$desktop_dir"/Launch_Ultimate_Hybrid.desktop
            chmod +x "$desktop_dir"/Monitor_Ultimate_Hybrid.desktop
            
            echo -e "${GREEN}  ✅ Desktop shortcuts created${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Desktop directory not found - shortcuts skipped${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠️  Desktop shortcuts not applicable for this system${NC}"
    fi
}

cleanup_temp_files() {
    echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
    
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        echo -e "${GREEN}  ✅ Temporary files cleaned${NC}"
    fi
}

show_installation_complete() {
    echo ""
    echo -e "${GREEN}████████████████████████████████████████████████████████████████████████████████"
    echo -e "${WHITE}██                                                                                ██"
    echo -e "${WHITE}██               🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉                  ██"
    echo -e "${WHITE}██                                                                                ██"
    echo -e "${GREEN}████████████████████████████████████████████████████████████████████████████████${NC}"
    echo ""
    echo -e "${BLUE}📁 Files installed to:${NC}"
    echo -e "${CYAN}   Strategy: $HUMMINGBOT_DIR/scripts/ultimate_hybrid_strategy.py${NC}"
    echo -e "${CYAN}   Config:   $HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml${NC}"
    echo -e "${CYAN}   Launcher: $HUMMINGBOT_DIR/launch_ultimate_hybrid.sh${NC}"
    echo -e "${CYAN}   Monitor:  $HUMMINGBOT_DIR/monitor_strategy.sh${NC}"
    echo ""
    echo -e "${BLUE}🚀 Quick Start Options:${NC}"
    echo -e "${WHITE}1. Launch with default settings:${NC}"
    echo -e "${CYAN}   cd $HUMMINGBOT_DIR && ./launch_ultimate_hybrid.sh${NC}"
    echo ""
    echo -e "${WHITE}2. Configure strategy first:${NC}"
    echo -e "${CYAN}   nano $HUMMINGBOT_DIR/conf/ultimate_hybrid_strategy_config.yml${NC}"
    echo ""
    echo -e "${WHITE}3. Start Hummingbot manually:${NC}"
    echo -e "${CYAN}   cd $HUMMINGBOT_DIR && ./start${NC}"
    echo -e "${CYAN}   start --script ultimate_hybrid_strategy.py${NC}"
    echo ""
    echo -e "${WHITE}4. Monitor performance:${NC}"
    echo -e "${CYAN}   cd $HUMMINGBOT_DIR && ./monitor_strategy.sh${NC}"
    echo ""
    echo -e "${BLUE}📚 Strategy Components:${NC}"
    echo -e "${WHITE}  🔲 Grid Trading: Dynamic ATR-based 8-level system${NC}"
    echo -e "${WHITE}  🎯 Launch Strategy: NY session needle detection (Kaanermi method)${NC}"
    echo -e "${WHITE}  📊 Market Profile: POC/VAH/VAL integration for better entries${NC}"
    echo -e "${WHITE}  ⚠️  Risk Management: Advanced position sizing and portfolio limits${NC}"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT REMINDERS:${NC}"
    echo -e "${YELLOW}  • Configure your exchange API keys in Hummingbot${NC}"
    echo -e "${YELLOW}  • Start with small position sizes for testing${NC}"
    echo -e "${YELLOW}  • Ensure minimum \$50 balance for optimal operation${NC}"
    echo -e "${YELLOW}  • Monitor performance closely during first few hours${NC}"
    echo -e "${YELLOW}  • Read ultimate_hybrid_README.md for detailed documentation${NC}"
    echo ""
    echo -e "${BLUE}📞 Support & Documentation:${NC}"
    echo -e "${CYAN}  Repository: $REPO_URL${NC}"
    echo -e "${CYAN}  Issues: $REPO_URL/issues${NC}"
    echo -e "${CYAN}  Wiki: $REPO_URL/wiki${NC}"
    echo ""
    echo -e "${GREEN}Happy Trading! 🎯💰${NC}"
    echo ""
}

# Main installation process
main() {
    show_banner
    
    # Confirmation
    echo -e "${WHITE}This will install Ultimate Hybrid Strategy v2.0 for Hummingbot.${NC}"
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${YELLOW}🚀 Starting installation process...${NC}"
    echo ""
    
    # Installation steps
    check_requirements
    create_temp_directory
    backup_existing_files
    download_strategy_files
    install_strategy_files
    setup_permissions
    validate_installation
    create_desktop_shortcuts
    cleanup_temp_files
    
    show_installation_complete
}

# Handle interrupts gracefully
trap 'echo -e "\n${YELLOW}Installation interrupted. Cleaning up...${NC}"; cleanup_temp_files; exit 1' INT TERM

# Run main installation
main "$@"
