#!/bin/bash

################################################################################
#  AUTO TUNNEL MAIN MENU - Professional dashboard for VPN panel management
################################################################################

set -e
PANEL_PATH="/usr/local/autotunnel"

# Load core functions
source "$PANEL_PATH/functions/core.sh"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear_screen() {
    printf '\033[H\033[2J'
}

print_header() {
    local hostname=$(get_vps_hostname)
    local domain=$(get_vps_domain)
    local ip=$(get_vps_ip)
    local isp=$(get_isp_info)
    local cpu_info=$(get_cpu_info)
    local ram_info=$(get_ram_info)
    local uptime=$(get_uptime)
    
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║            AUTO TUNNEL VPN PANEL v3.0 (Refactored)             ║"
    echo "║                     Optimized for All VPS                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}System Information:${NC}"
    printf "  %-20s: %s\\n" "Hostname" "$hostname"
    printf "  %-20s: %s\\n" "Domain" "${domain:-Not Set}"
    printf "  %-20s: %s\\n" "VPS IP" "$ip"
    printf "  %-20s: %s\\n" "ISP" "$isp"
    echo ""
    echo -e "${BLUE}Resource Usage:${NC}"
    printf "  %-20s: %s\\n" "CPU" "$cpu_info"
    printf "  %-20s: %s\\n" "RAM" "$ram_info"
    printf "  %-20s: %s\\n" "Uptime" "$uptime"
    printf "  %-20s: %s\\n" "Mode" "$VPS_MODE"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

print_menu() {
    echo -e "${CYAN}VPN MANAGEMENT${NC}"
    echo "  [1] SSH Management"
    echo "  [2] VMESS Management"
    echo "  [3] VLESS Management"
    echo "  [4] TROJAN Management"
    echo "  [5] SHADOWSOCKS Management"
    echo "  [6] XRAY Management"
    echo ""
    echo -e "${CYAN}SYSTEM MANAGEMENT${NC}"
    echo "  [7] Backup and Restore"
    echo "  [8] Telegram Bot"
    echo "  [9] Domain Management"
    echo "  [10] Certificate Management"
    echo "  [11] Monitoring"
    echo "  [12] System Settings"
    echo ""
    echo -e "${CYAN}ADMINISTRATION${NC}"
    echo "  [13] Service Control"
    echo "  [14] Clear Cache"
    echo "  [15] View Logs"
    echo "  [16] Update Panel"
    echo "  [17] Diagnostics"
    echo ""
    echo -e "${YELLOW}  [0] Exit${NC}"
}

handle_menu_selection() {
    local choice="$1"
    case $choice in
        0) exit 0 ;;
        14)
            cache_clear_all
            echo -e "${GREEN}Cache cleared${NC}"
            sleep 1
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
}

main() {
    while true; do
        clear_screen
        print_header
        print_menu
        read -p "Choose option: " choice
        handle_menu_selection "$choice"
    done
}

main "$@"
