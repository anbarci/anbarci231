cat > scripts/monitor_strategy.sh << 'MONITOR_EOF'
#!/bin/bash

echo "📊 Ultimate Hybrid Strategy Monitor v2.0"
echo "========================================"
echo "GitHub Repository: hummingbot-ultimate-hybrid"
echo ""

while true; do
    clear
    echo "📊 ULTIMATE HYBRID STRATEGY MONITOR - $(date)"
    echo "=============================================="
    echo "Version: 2.0 | GitHub: hummingbot-ultimate-hybrid"
    echo ""
    
    # Check if Hummingbot is running
    if pgrep -f "hummingbot" > /dev/null; then
        echo "✅ STATUS: Hummingbot is RUNNING"
        echo ""
        
        # Show recent strategy activity
        echo "📋 RECENT ACTIVITY:"
        echo "-------------------"
        tail -n 15 /root/hummingbot/logs/hummingbot_logs_*.log 2>/dev/null | \
        grep -E "(Ultimate|Grid|Launch|filled|executed|P&L)" | tail -10 || \
        echo "No recent strategy activity found"
        
        echo ""
        echo "📈 PERFORMANCE DATA:"
        echo "--------------------"
        if [ -f "/root/hummingbot/logs/ultimate_hybrid_performance.json" ]; then
            echo "Last performance update:"
            tail -n 1 /root/hummingbot/logs/ultimate_hybrid_performance.json 2>/dev/null | \
            python3 -m json.tool 2>/dev/null || echo "Performance data formatting error"
        else
            echo "Performance log not yet created"
        fi
        
    else
        echo "❌ STATUS: Hummingbot is NOT RUNNING"
        echo ""
        echo "🚀 TO START:"
        echo "  /root/launch_ultimate_hybrid.sh"
        echo ""
        echo "📚 TO INSTALL/UPDATE:"
        echo "  git clone https://github.com/your-username/hummingbot-ultimate-hybrid"
        echo "  cd hummingbot-ultimate-hybrid && ./install.sh"
    fi
    
    echo ""
    echo "=============================================="
    echo "📊 SYSTEM STATUS:"
    echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% usage"
    echo "  Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
    echo "  Disk: $(df -h /root | awk 'NR==2{print $5}') used"
    echo ""
    echo "🔗 GITHUB COMMANDS:"
    echo "  • Check updates: cd hummingbot-ultimate-hybrid && git pull"
    echo "  • View config: cat /root/hummingbot/conf/ultimate_hybrid_strategy_config.yml"
    echo "  • View logs: tail -f /root/hummingbot/logs/hummingbot_logs_*.log"
    echo ""
    echo "Press Ctrl+C to exit monitoring"
    echo "Refreshing in 30 seconds..."
    
    sleep 30
done
MONITOR_EOF
