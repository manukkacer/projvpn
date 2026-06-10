#!/bin/bash

################################################################################
#  AUTO TUNNEL VPN PANEL - INSTALLER
#  Modern, optimized installation script for low and high-spec VPS
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
INSTALL_PATH="/usr/local/autotunnel"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# FUNCTIONS
################################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     AUTO TUNNEL VPN PANEL - INSTALLATION WIZARD               ║"
    echo "║     Version: 3.0 (Refactored)                                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${YELLOW}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    print_success "Root privileges confirmed"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            print_success "Detected: $OS $VERSION"
            PKG_MANAGER="apt-get"
            ;;
        centos|rhel|fedora)
            print_success "Detected: $OS $VERSION"
            PKG_MANAGER="yum"
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

detect_vps_mode() {
    local cpu_count=$(nproc 2>/dev/null || echo "1")
    local ram_mb=$(free -m | awk 'NR==2 {print int($2)}')
    
    if (( cpu_count <= 1 && ram_mb <= 1024 )); then
        VPS_MODE="LOW_SPEC"
        print_success "VPS Mode: LOW SPEC (CPU: $cpu_count, RAM: ${ram_mb}MB)"
    else
        VPS_MODE="HIGH_SPEC"
        print_success "VPS Mode: HIGH SPEC (CPU: $cpu_count, RAM: ${ram_mb}MB)"
    fi
}

check_dependencies() {
    print_step "Checking dependencies..."
    
    local required_commands=("curl" "wget" "openssl" "systemctl" "jq")
    local missing_packages=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            case $cmd in
                curl) missing_packages+=("curl") ;;
                wget) missing_packages+=("wget") ;;
                openssl) missing_packages+=("openssl") ;;
                jq) missing_packages+=("jq") ;;
                *) ;;
            esac
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_step "Installing missing packages: ${missing_packages[*]}"
        if [[ "$PKG_MANAGER" == "apt-get" ]]; then
            apt-get update
            apt-get install -y ${missing_packages[@]}
        else
            yum install -y ${missing_packages[@]}
        fi
    fi
    
    print_success "All dependencies installed"
}

setup_directories() {
    print_step "Setting up directory structure..."
    
    local dirs=(
        "$INSTALL_PATH"
        "$INSTALL_PATH/menu"
        "$INSTALL_PATH/modules"
        "$INSTALL_PATH/functions"
        "$INSTALL_PATH/services"
        "$INSTALL_PATH/cache"
        "$INSTALL_PATH/config"
        "$INSTALL_PATH/logs"
        "$INSTALL_PATH/backup"
        "$INSTALL_PATH/update"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    chmod 755 "$INSTALL_PATH"
    chmod 755 "$INSTALL_PATH"/*
    
    print_success "Directory structure created"
}

copy_files() {
    print_step "Copying application files..."
    
    # Copy menu files
    cp -f "$SCRIPT_PATH/src/menu"/* "$INSTALL_PATH/menu/" 2>/dev/null || true
    
    # Copy modules
    cp -f "$SCRIPT_PATH/src/modules"/* "$INSTALL_PATH/modules/" 2>/dev/null || true
    
    # Copy functions
    cp -f "$SCRIPT_PATH/src/functions"/* "$INSTALL_PATH/functions/" 2>/dev/null || true
    
    # Copy services
    cp -f "$SCRIPT_PATH/src/services"/*.service /etc/systemd/system/ 2>/dev/null || true
    
    # Copy config templates
    if [[ ! -f "$INSTALL_PATH/config/system.conf" ]]; then
        cp -f "$SCRIPT_PATH/src/config/system.conf.template" "$INSTALL_PATH/config/system.conf"
    fi
    if [[ ! -f "$INSTALL_PATH/config/vps.conf" ]]; then
        cp -f "$SCRIPT_PATH/src/config/vps.conf" "$INSTALL_PATH/config/vps.conf"
    fi
    
    # Make scripts executable
    find "$INSTALL_PATH" -type f -name "*.sh" -exec chmod +x {} \;
    find "$INSTALL_PATH/menu" -type f ! -name "*.sh" -exec chmod +x {} \;
    
    print_success "Files copied"
}

setup_configuration() {
    print_step "Setting up configuration..."
    
    # Write VPS mode to config
    cat > "$INSTALL_PATH/config/vps.conf" <<EOF
# Auto Tunnel VPS Configuration
# Generated by installer

VPS_MODE="$VPS_MODE"
CPU_CORES=$(nproc 2>/dev/null || echo "1")
RAM_MB=$(free -m | awk 'NR==2 {print int(\$2)}')
INSTALL_DATE="$(date)"
PANEL_VERSION="3.0"

# Cache refresh intervals (in minutes)
if [[ "$VPS_MODE" == "LOW_SPEC" ]]; then
    CACHE_REFRESH=30
else
    CACHE_REFRESH=10
fi

# Logging level (LOW_SPEC: error, HIGH_SPEC: info)
if [[ "$VPS_MODE" == "LOW_SPEC" ]]; then
    LOG_LEVEL="error"
else
    LOG_LEVEL="info"
fi

# Service features
ENABLE_MONITORING=$([ "$VPS_MODE" = "HIGH_SPEC" ] && echo "1" || echo "0")
ENABLE_DETAILED_STATS=$([ "$VPS_MODE" = "HIGH_SPEC" ] && echo "1" || echo "0")
ENABLE_REAL_TIME_CHECKING=$([ "$VPS_MODE" = "HIGH_SPEC" ] && echo "1" || echo "0")
EOF

    print_success "Configuration created"
}

install_xray() {
    print_step "Installing Xray..."
    
    if command -v xray &> /dev/null; then
        print_info "Xray is already installed"
        return 0
    fi
    
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    systemctl enable xray
    systemctl restart xray
    
    print_success "Xray installed"
}

setup_systemd_services() {
    print_step "Setting up systemd services..."
    
    systemctl daemon-reload
    
    local services=("autotunnel" "autotunnel-monitor" "autotunnel-telegrambot")
    
    for service in "${services[@]}"; do
        if [[ -f "/etc/systemd/system/${service}.service" ]]; then
            systemctl enable "$service"
            systemctl restart "$service"
            print_success "Service $service enabled and started"
        fi
    done
}

final_cleanup() {
    print_step "Final cleanup..."
    
    # Remove cache files
    rm -f "$INSTALL_PATH/cache"/*.db
    rm -f "$INSTALL_PATH/cache"/*.tmp
    
    # Initialize log files
    touch "$INSTALL_PATH/logs/system.log"
    touch "$INSTALL_PATH/logs/error.log"
    touch "$INSTALL_PATH/logs/service.log"
    
    chmod 644 "$INSTALL_PATH/logs"/*
    
    print_success "Cleanup completed"
}

show_summary() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         INSTALLATION COMPLETED SUCCESSFULLY                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}Installation Summary:${NC}"
    echo "  Installation Path: $INSTALL_PATH"
    echo "  VPS Mode: $VPS_MODE"
    echo "  OS: $OS $VERSION"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Access the menu: autotunnel"
    echo "  2. Configure your domain in Domain Menu"
    echo "  3. Create SSL certificate in Certificate Menu"
    echo "  4. Configure Telegram Bot (if needed)"
    echo "  5. Start creating VPN accounts"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  autotunnel              - Main menu"
    echo "  systemctl status autotunnel    - Check main service status"
    echo "  systemctl logs -u autotunnel   - View logs"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  - Full documentation available at: $INSTALL_PATH/docs/"
    echo "  - Configuration guide: $INSTALL_PATH/docs/CONFIG.md"
    echo "  - Troubleshooting: $INSTALL_PATH/docs/TROUBLESHOOTING.md"
    echo ""
}

################################################################################
# MAIN INSTALLATION FLOW
################################################################################

main() {
    print_header
    
    echo -e "${YELLOW}Starting installation...${NC}\n"
    
    check_root
    detect_os
    detect_vps_mode
    check_dependencies
    setup_directories
    copy_files
    setup_configuration
    install_xray
    setup_systemd_services
    final_cleanup
    show_summary
    
    print_success "Installation script finished!"
}

main "$@"
exit 0
