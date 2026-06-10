#!/bin/bash

################################################################################
# AUTO TUNNEL VPN PANEL - MAIN MENU
# Professional dashboard interface with real-time system information
################################################################################

set -o pipefail

# Source all libraries
LIBRARY_PATH="${BASH_SOURCE%/*}"
source "${LIBRARY_PATH}/../functions/core.sh" || exit 1
source "${LIBRARY_PATH}/../functions/user.sh" || exit 1
source "${LIBRARY_PATH}/../functions/ssh.sh" || exit 1
source "${LIBRARY_PATH}/../functions/xray.sh" || exit 1
source "${LIBRARY_PATH}/../functions/system.sh" || exit 1
source "${LIBRARY_PATH}/../functions/monitor.sh" || exit 1
source "${LIBRARY_PATH}/../functions/domain.sh" || exit 1

################################################################################
# DISPLAY FUNCTIONS
################################################################################

# Clear screen
clear_screen() {
    clear
}

# Print header
print_header() {
    clear_screen
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         AUTO TUNNEL VPN PANEL - PRODUCTION READY v4.0          ║"
    echo "║                                                                ║"
    echo "║            Advanced VPN Management System                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print footer
print_footer() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Enter choice [0-99] or 'q' to quit:${NC} "
}

# Display system status bar
show_status_bar() {
    local cpu_usage
    local mem_usage
    local disk_usage
    local uptime
    
    cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "N/A")
    mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}' || echo "N/A")
    disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1 || echo "N/A")
    uptime=$(get_uptime)
    
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} CPU: ${cpu_usage}% │ RAM: ${mem_usage}% │ DISK: ${disk_usage}% │ Uptime: ${uptime}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
}

################################################################################
# MENU FUNCTIONS
################################################################################

# Main menu
main_menu() {
    while true; do
        print_header
        show_status_bar
        
        echo ""
        echo -e "${GREEN}VPN MANAGEMENT:${NC}"
        echo "  ${YELLOW}1${NC}  - SSH User Management"
        echo "  ${YELLOW}2${NC}  - VMESS User Management"
        echo "  ${YELLOW}3${NC}  - VLESS User Management"
        echo "  ${YELLOW}4${NC}  - TROJAN User Management"
        echo "  ${YELLOW}5${NC}  - SHADOWSOCKS User Management"
        echo ""
        echo -e "${GREEN}ADDITIONAL PROTOCOLS:${NC}"
        echo "  ${YELLOW}6${NC}  - BadVPN Management"
        echo "  ${YELLOW}7${NC}  - SlowDNS Management"
        echo "  ${YELLOW}8${NC}  - UDP Custom Management"
        echo ""
        echo -e "${GREEN}SYSTEM MANAGEMENT:${NC}"
        echo "  ${YELLOW}9${NC}  - Domain Management"
        echo "  ${YELLOW}10${NC} - SSL Certificate Management"
        echo "  ${YELLOW}11${NC} - Backup & Restore"
        echo "  ${YELLOW}12${NC} - Monitoring Dashboard"
        echo ""
        echo -e "${GREEN}ADMINISTRATION:${NC}"
        echo "  ${YELLOW}13${NC} - Security Settings"
        echo "  ${YELLOW}14${NC} - System Optimization"
        echo "  ${YELLOW}15${NC} - Logs & Diagnostics"
        echo "  ${YELLOW}16${NC} - Settings & Configuration"
        echo ""
        echo -e "${GREEN}INFO:${NC}"
        echo "  ${YELLOW}17${NC} - System Information"
        echo "  ${YELLOW}18${NC} - Service Status"
        echo ""
        print_footer
        read -r choice
        
        case "$choice" in
            1) ssh_menu ;;
            2) vmess_menu ;;
            3) vless_menu ;;
            4) trojan_menu ;;
            5) shadowsocks_menu ;;
            6) badvpn_menu ;;
            7) slowdns_menu ;;
            8) udp_menu ;;
            9) domain_menu ;;
            10) ssl_menu ;;
            11) backup_menu ;;
            12) monitoring_menu ;;
            13) security_menu ;;
            14) optimization_menu ;;
            15) logs_menu ;;
            16) settings_menu ;;
            17) system_info_menu ;;
            18) service_status_menu ;;
            q|Q) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# SSH menu
ssh_menu() {
    while true; do
        print_header
        echo -e "${GREEN}SSH USER MANAGEMENT${NC}"
        echo ""
        echo "  ${YELLOW}1${NC}  - Create SSH User"
        echo "  ${YELLOW}2${NC}  - Create Trial SSH User"
        echo "  ${YELLOW}3${NC}  - Renew SSH User"
        echo "  ${YELLOW}4${NC}  - Delete SSH User"
        echo "  ${YELLOW}5${NC}  - Change Password"
        echo "  ${YELLOW}6${NC}  - Lock User"
        echo "  ${YELLOW}7${NC}  - Unlock User"
        echo "  ${YELLOW}8${NC}  - List SSH Users"
        echo "  ${YELLOW}9${NC}  - Check Online Users"
        echo "  ${YELLOW}10${NC} - User Information"
        echo "  ${YELLOW}0${NC}  - Back to Main Menu"
        echo ""
        print_footer
        read -r choice
        
        case "$choice" in
            1) ssh_create_menu ;;
            2) ssh_trial_menu ;;
            3) ssh_renew_menu ;;
            4) ssh_delete_menu ;;
            5) ssh_change_password_menu ;;
            6) ssh_lock_menu ;;
            7) ssh_unlock_menu ;;
            8) list_users "ssh" ;; read -p "Press enter to continue..."; ;;
            9) check_online_ssh_users "all"; read -p "Press enter to continue..."; ;;
            10) ssh_info_menu ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# SSH create user submenu
ssh_create_menu() {
    print_header
    echo -e "${GREEN}CREATE SSH USER${NC}"
    echo ""
    read -p "Enter username: " username
    read -sp "Enter password: " password
    echo ""
    read -p "Validity in days (default 30): " days
    days=${days:-30}
    
    if create_ssh_user_full "$username" "$password" "$days"; then
        log_success "User $username created successfully"
    else
        log_error "Failed to create user $username"
    fi
    
    read -p "Press enter to continue..."
}

# SSH trial user submenu
ssh_trial_menu() {
    print_header
    echo -e "${GREEN}CREATE TRIAL SSH USER${NC}"
    echo ""
    read -p "Enter username: " username
    read -p "Trial duration in days (default 7): " days
    days=${days:-7}
    
    if create_trial_ssh_user "$username" "$days"; then
        log_success "Trial user $username created successfully"
    else
        log_error "Failed to create trial user $username"
    fi
    
    read -p "Press enter to continue..."
}

# SSH renew user submenu
ssh_renew_menu() {
    print_header
    echo -e "${GREEN}RENEW SSH USER${NC}"
    echo ""
    read -p "Enter username: " username
    read -p "Additional days (default 30): " days
    days=${days:-30}
    
    if renew_ssh_user "$username" "$days"; then
        log_success "User $username renewed successfully"
    else
        log_error "Failed to renew user $username"
    fi
    
    read -p "Press enter to continue..."
}

# SSH delete user submenu
ssh_delete_menu() {
    print_header
    echo -e "${GREEN}DELETE SSH USER${NC}"
    echo ""
    read -p "Enter username: " username
    read -p "Keep home directory? (y/N): " keep_home
    [[ "$keep_home" == "y" ]] && keep_home="true" || keep_home="false"
    
    if delete_ssh_user_full "$username" "$keep_home"; then
        log_success "User $username deleted successfully"
    else
        log_error "Failed to delete user $username"
    fi
    
    read -p "Press enter to continue..."
}

# SSH change password submenu
ssh_change_password_menu() {
    print_header
    echo -e "${GREEN}CHANGE SSH PASSWORD${NC}"
    echo ""
    read -p "Enter username: " username
    read -sp "Enter new password: " password
    echo ""
    
    if change_ssh_password "$username" "$password"; then
        log_success "Password changed for $username"
    else
        log_error "Failed to change password for $username"
    fi
    
    read -p "Press enter to continue..."
}

# SSH lock user submenu
ssh_lock_menu() {
    print_header
    echo -e "${GREEN}LOCK SSH USER${NC}"
    echo ""
    read -p "Enter username: " username
    
    if lock_ssh_user "$username"; then
        log_success "User $username locked"
    else
        log_error "Failed to lock user $username"
    fi
    
    read -p "Press enter to continue..."
}

# SSH unlock user submenu
ssh_unlock_menu() {
    print_header
    echo -e "${GREEN}UNLOCK SSH USER${NC}"
    echo ""
    read -p "Enter username: " username
    
    if unlock_ssh_user "$username"; then
        log_success "User $username unlocked"
    else
        log_error "Failed to unlock user $username"
    fi
    
    read -p "Press enter to continue..."
}

# SSH user info submenu
ssh_info_menu() {
    print_header
    echo -e "${GREEN}SSH USER INFORMATION${NC}"
    echo ""
    read -p "Enter username: " username
    
    get_ssh_user_info "$username"
    
    read -p "Press enter to continue..."
}

# VMESS menu
vmess_menu() {
    print_header
    echo -e "${GREEN}VMESS USER MANAGEMENT${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Create VMESS User"
    echo "  ${YELLOW}2${NC}  - Create Trial VMESS User"
    echo "  ${YELLOW}3${NC}  - Renew VMESS User"
    echo "  ${YELLOW}4${NC}  - Delete VMESS User"
    echo "  ${YELLOW}5${NC}  - List VMESS Users"
    echo "  ${YELLOW}6${NC}  - Generate VMESS Config"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
    
    case "$choice" in
        1)
            read -p "Enter username: " username
            create_vmess_user "$username" 30
            read -p "Press enter to continue..."
            ;;
        2)
            read -p "Enter username: " username
            create_vmess_user "$username" 7
            read -p "Press enter to continue..."
            ;;
        *) return ;;
    esac
}

# VLESS menu
vless_menu() {
    print_header
    echo -e "${GREEN}VLESS USER MANAGEMENT${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Create VLESS User"
    echo "  ${YELLOW}2${NC}  - Create Trial VLESS User"
    echo "  ${YELLOW}3${NC}  - Renew VLESS User"
    echo "  ${YELLOW}4${NC}  - Delete VLESS User"
    echo "  ${YELLOW}5${NC}  - List VLESS Users"
    echo "  ${YELLOW}6${NC}  - Generate VLESS Config"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# Trojan menu
trojan_menu() {
    print_header
    echo -e "${GREEN}TROJAN USER MANAGEMENT${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Create Trojan User"
    echo "  ${YELLOW}2${NC}  - Create Trial Trojan User"
    echo "  ${YELLOW}3${NC}  - Renew Trojan User"
    echo "  ${YELLOW}4${NC}  - Delete Trojan User"
    echo "  ${YELLOW}5${NC}  - List Trojan Users"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# Shadowsocks menu
shadowsocks_menu() {
    print_header
    echo -e "${GREEN}SHADOWSOCKS USER MANAGEMENT${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Create SS User"
    echo "  ${YELLOW}2${NC}  - Create Trial SS User"
    echo "  ${YELLOW}3${NC}  - Renew SS User"
    echo "  ${YELLOW}4${NC}  - Delete SS User"
    echo "  ${YELLOW}5${NC}  - List SS Users"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# BadVPN menu
badvpn_menu() {
    print_header
    echo -e "${GREEN}BADVPN MANAGEMENT${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Check BadVPN Status"
    echo "  ${YELLOW}2${NC}  - Start BadVPN"
    echo "  ${YELLOW}3${NC}  - Stop BadVPN"
    echo "  ${YELLOW}4${NC}  - Restart BadVPN"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# SlowDNS menu
slowdns_menu() {
    print_header
    echo -e "${GREEN}SLOWDNS MANAGEMENT${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Check SlowDNS Status"
    echo "  ${YELLOW}2${NC}  - Install SlowDNS"
    echo "  ${YELLOW}3${NC}  - Configure SlowDNS"
    echo "  ${YELLOW}4${NC}  - Start SlowDNS"
    echo "  ${YELLOW}5${NC}  - Stop SlowDNS"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# UDP menu
udp_menu() {
    print_header
    echo -e "${GREEN}UDP CUSTOM MANAGEMENT${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Check UDP Status"
    echo "  ${YELLOW}2${NC}  - Configure UDP Ports"
    echo "  ${YELLOW}3${NC}  - Add UDP User"
    echo "  ${YELLOW}4${NC}  - Remove UDP User"
    echo "  ${YELLOW}5${NC}  - List UDP Users"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# Domain menu
domain_menu() {
    print_header
    echo -e "${GREEN}DOMAIN MANAGEMENT${NC}"
    echo ""
    echo "  Current Domain: $(get_current_domain)"
    echo ""
    echo "  ${YELLOW}1${NC}  - Set Domain"
    echo "  ${YELLOW}2${NC}  - Verify Domain"
    echo "  ${YELLOW}3${NC}  - Check DNS"
    echo "  ${YELLOW}4${NC}  - Test DNS Propagation"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
    
    case "$choice" in
        1)
            read -p "Enter domain name: " domain
            save_domain "$domain"
            read -p "Press enter to continue..."
            ;;
        2)
            read -p "Enter domain name: " domain
            verify_domain "$domain"
            read -p "Press enter to continue..."
            ;;
        3)
            read -p "Enter domain name: " domain
            check_dns "$domain"
            read -p "Press enter to continue..."
            ;;
        4)
            read -p "Enter domain name: " domain
            test_dns_propagation "$domain"
            read -p "Press enter to continue..."
            ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

# SSL menu
ssl_menu() {
    print_header
    echo -e "${GREEN}SSL CERTIFICATE MANAGEMENT${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Create Self-Signed Certificate"
    echo "  ${YELLOW}2${NC}  - Create Let's Encrypt Certificate"
    echo "  ${YELLOW}3${NC}  - Check Certificate Expiry"
    echo "  ${YELLOW}4${NC}  - Renew Certificate"
    echo "  ${YELLOW}5${NC}  - Setup Auto-Renewal"
    echo "  ${YELLOW}6${NC}  - View Certificate Info"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
    
    case "$choice" in
        1)
            read -p "Enter domain name: " domain
            create_self_signed_cert "$domain" 365
            read -p "Press enter to continue..."
            ;;
        2)
            read -p "Enter domain name: " domain
            read -p "Enter email address: " email
            create_letsencrypt_cert "$domain" "$email"
            read -p "Press enter to continue..."
            ;;
        3)
            read -p "Enter domain name: " domain
            check_cert_expiry "$domain"
            read -p "Press enter to continue..."
            ;;
        *) return ;;
    esac
}

# Backup menu
backup_menu() {
    print_header
    echo -e "${GREEN}BACKUP & RESTORE${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Create Local Backup"
    echo "  ${YELLOW}2${NC}  - Restore from Local Backup"
    echo "  ${YELLOW}3${NC}  - Backup to Google Drive"
    echo "  ${YELLOW}4${NC}  - Backup to FTP"
    echo "  ${YELLOW}5${NC}  - List Backups"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# Monitoring menu
monitoring_menu() {
    print_header
    show_status_bar
    echo ""
    get_resource_report
    echo ""
    get_user_statistics
    echo ""
    get_all_service_status
    echo ""
    read -p "Press enter to continue..."
}

# Security menu
security_menu() {
    print_header
    echo -e "${GREEN}SECURITY SETTINGS${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Enable Fail2Ban"
    echo "  ${YELLOW}2${NC}  - Configure Firewall"
    echo "  ${YELLOW}3${NC}  - SSH Hardening"
    echo "  ${YELLOW}4${NC}  - Enable DDoS Protection"
    echo "  ${YELLOW}5${NC}  - IP Blacklist Management"
    echo "  ${YELLOW}6${NC}  - Port Scanner Protection"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# Optimization menu
optimization_menu() {
    print_header
    echo -e "${GREEN}SYSTEM OPTIMIZATION${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Optimize System"
    echo "  ${YELLOW}2${NC}  - Enable BBR"
    echo "  ${YELLOW}3${NC}  - Create Swap"
    echo "  ${YELLOW}4${NC}  - Update System"
    echo "  ${YELLOW}5${NC}  - Clean System Cache"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
    
    case "$choice" in
        1) optimize_system; read -p "Press enter to continue..."; ;;
        2) enable_bbr; read -p "Press enter to continue..."; ;;
        3) create_swap "1G"; read -p "Press enter to continue..."; ;;
        4) update_system; read -p "Press enter to continue..."; ;;
        5) clean_system; read -p "Press enter to continue..."; ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

# Logs menu
logs_menu() {
    print_header
    echo -e "${GREEN}LOGS & DIAGNOSTICS${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - View System Log"
    echo "  ${YELLOW}2${NC}  - View Error Log"
    echo "  ${YELLOW}3${NC}  - View User Log"
    echo "  ${YELLOW}4${NC}  - View Service Log"
    echo "  ${YELLOW}5${NC}  - Check System Health"
    echo "  ${YELLOW}6${NC}  - Export Logs"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
    
    case "$choice" in
        1) tail -50 "${LOG_DIR}/system.log"; read -p "Press enter to continue..."; ;;
        2) tail -50 "${LOG_DIR}/error.log"; read -p "Press enter to continue..."; ;;
        3) tail -50 "${LOG_DIR}/user.log"; read -p "Press enter to continue..."; ;;
        4) tail -50 "${LOG_DIR}/service.log"; read -p "Press enter to continue..."; ;;
        5) check_system_health; read -p "Press enter to continue..."; ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

# Settings menu
settings_menu() {
    print_header
    echo -e "${GREEN}SETTINGS & CONFIGURATION${NC}"
    echo ""
    echo "  ${YELLOW}1${NC}  - Configure Telegram Bot"
    echo "  ${YELLOW}2${NC}  - Edit System Config"
    echo "  ${YELLOW}3${NC}  - VPS Mode: $(grep VPS_MODE ${CONFIG_DIR}/vps.conf 2>/dev/null | cut -d'=' -f2)"
    echo "  ${YELLOW}4${NC}  - Cache Settings"
    echo "  ${YELLOW}5${NC}  - Logging Settings"
    echo "  ${YELLOW}0${NC}  - Back"
    echo ""
    print_footer
    read -r choice
}

# System info menu
system_info_menu() {
    print_header
    get_system_info
    read -p "Press enter to continue..."
}

# Service status menu
service_status_menu() {
    print_header
    get_all_service_status
    read -p "Press enter to continue..."
}

################################################################################
# MAIN EXECUTION
################################################################################

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Initialize logging
init_log

# Main loop
main_menu
