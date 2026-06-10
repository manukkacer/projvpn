#!/bin/bash

################################################################################
# AUTO TUNNEL VPN PANEL - SYSTEM MANAGEMENT LIBRARY
# Handles system administration, optimization, and maintenance
################################################################################

set -o pipefail

# Source core library
source "${BASH_SOURCE%/*}/core.sh" || exit 1

################################################################################
# SYSTEM INFORMATION
################################################################################

# Get detailed system info
get_system_info() {
    echo -e "\n${BLUE}=== System Information ===${NC}"
    echo "Hostname: $(get_hostname)"
    echo "Uptime: $(get_uptime)"
    echo "Kernel: $(uname -r)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
    echo -e "\n${BLUE}CPU:${NC}"
    echo "Cores: $(nproc)"
    echo "Usage: $(get_cpu_usage)"
    echo -e "\n${BLUE}Memory:${NC}"
    echo "$(get_ram_info)"
    echo -e "\n${BLUE}Disk:${NC}"
    echo "Root: $(get_disk_usage /)"
}

# Get server specification
get_server_spec() {
    local cpu_count
    local ram_mb
    
    cpu_count=$(nproc 2>/dev/null || echo "1")
    ram_mb=$(free -m | awk 'NR==2 {print int($2)}')
    
    echo "CPU: ${cpu_count} cores"
    echo "RAM: ${ram_mb}MB"
    echo "Disk: $(get_disk_usage /)"
}

################################################################################
# SYSTEM OPTIMIZATION
################################################################################

# Optimize system for VPS
optimize_system() {
    log_info "Optimizing system..."
    
    # Increase file descriptors
    echo "* soft nofile 1000000" >> /etc/security/limits.conf 2>/dev/null || true
    echo "* hard nofile 1000000" >> /etc/security/limits.conf 2>/dev/null || true
    
    # Optimize sysctl
    cat >> /etc/sysctl.conf <<EOF
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.ip_local_port_range = 10000 65000
EOF
    
    sysctl -p >/dev/null 2>&1 || true
    
    log_success "System optimized"
}

# Enable BBR congestion control
enable_bbr() {
    log_info "Enabling BBR congestion control..."
    
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf 2>/dev/null || true
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf 2>/dev/null || true
    
    sysctl -p >/dev/null 2>&1 || true
    
    log_success "BBR enabled"
}

################################################################################
# SYSTEM MAINTENANCE
################################################################################

# Clean system cache and temporary files
clean_system() {
    log_info "Cleaning system..."
    
    # Clean apt cache
    apt-get clean 2>/dev/null || true
    apt-get autoclean 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    
    # Clean temp files
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true
    
    # Clean log files
    journalctl --vacuum=30d 2>/dev/null || true
    
    log_success "System cleaned"
}

# Update system
update_system() {
    log_info "Updating system..."
    
    apt-get update || {
        log_error "Failed to update package list"
        return 1
    }
    
    # Only upgrade packages (not full-upgrade to avoid breaking changes)
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || {
        log_error "Failed to upgrade packages"
        return 1
    }
    
    log_success "System updated"
}

# Check system health
check_system_health() {
    local cpu_usage
    local ram_usage
    local disk_usage
    
    echo -e "\n${BLUE}=== System Health Check ===${NC}"
    
    # CPU check
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        echo -e "${YELLOW}CPU: ${cpu_usage}% (HIGH)${NC}"
    else
        echo -e "${GREEN}CPU: ${cpu_usage}% (OK)${NC}"
    fi
    
    # RAM check
    ram_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}')
    if (( ram_usage > 80 )); then
        echo -e "${YELLOW}RAM: ${ram_usage}% (HIGH)${NC}"
    else
        echo -e "${GREEN}RAM: ${ram_usage}% (OK)${NC}"
    fi
    
    # Disk check
    disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    if (( disk_usage > 80 )); then
        echo -e "${YELLOW}Disk: ${disk_usage}% (HIGH)${NC}"
    else
        echo -e "${GREEN}Disk: ${disk_usage}% (OK)${NC}"
    fi
}

################################################################################
# SWAP MANAGEMENT
################################################################################

# Create swap space
create_swap() {
    local size="${1:-1G}"
    
    if grep -q "swapfile" /etc/fstab; then
        log_info "Swap already configured"
        return 0
    fi
    
    log_info "Creating swap space: $size"
    
    fallocate -l "$size" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1G count=${size%G} 2>/dev/null
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    
    log_success "Swap created: $size"
}

################################################################################
# PACKAGE MANAGEMENT
################################################################################

# Install package
install_package() {
    local package="$1"
    
    if dpkg -l | grep -q " $package "; then
        log_info "Package already installed: $package"
        return 0
    fi
    
    log_info "Installing package: $package"
    
    if apt-get install -y "$package" >/dev/null 2>&1; then
        log_success "Package installed: $package"
        return 0
    else
        log_error "Failed to install package: $package"
        return 1
    fi
}

# Remove package
remove_package() {
    local package="$1"
    
    if ! dpkg -l | grep -q " $package "; then
        log_info "Package not installed: $package"
        return 0
    fi
    
    log_info "Removing package: $package"
    
    if apt-get remove -y "$package" >/dev/null 2>&1; then
        log_success "Package removed: $package"
        return 0
    else
        log_error "Failed to remove package: $package"
        return 1
    fi
}

################################################################################
# SYSTEM REBOOT
################################################################################

# Schedule reboot
schedule_reboot() {
    local delay="${1:-5}"  # minutes
    
    log_info "Reboot scheduled in $delay minutes"
    shutdown -r +"$delay" "System will reboot in $delay minutes" 2>/dev/null || true
}

# Cancel scheduled reboot
cancel_reboot() {
    shutdown -c 2>/dev/null || true
    log_info "Reboot cancelled"
}

# Reboot now
reboot_now() {
    log_warn "Rebooting system..."
    sleep 2
    shutdown -r now
}

return 0 2>/dev/null || true
