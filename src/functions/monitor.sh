#!/bin/bash

################################################################################
# AUTO TUNNEL VPN PANEL - MONITORING LIBRARY
# Handles real-time monitoring, statistics, and alerts
################################################################################

set -o pipefail

# Source core library
source "${BASH_SOURCE%/*}/core.sh" || exit 1

readonly MONITOR_INTERVAL=5  # seconds
readonly MONITOR_LOG="${LOG_DIR}/monitor.log"

################################################################################
# SERVICE MONITORING
################################################################################

# Monitor all services
monitor_services() {
    local services=("sshd" "xray" "autotunnel")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! is_service_running "$service"; then
            failed_services+=("$service")
        fi
    done
    
    if (( ${#failed_services[@]} > 0 )); then
        log_error "Failed services: ${failed_services[*]}" "$MONITOR_LOG"
        return 1
    fi
    
    log_debug "All services running" "$MONITOR_LOG"
    return 0
}

# Get service status for all protocols
get_all_service_status() {
    echo -e "\n${BLUE}=== Service Status ===${NC}"
    
    local services=("sshd" "xray" "autotunnel" "autotunnel-monitor")
    
    for service in "${services[@]}"; do
        local status
        status=$(get_service_status "$service")
        
        if [[ "$status" == "running" ]]; then
            echo -e "${service}: ${GREEN}${status}${NC}"
        else
            echo -e "${service}: ${RED}${status}${NC}"
        fi
    done
}

################################################################################
# RESOURCE MONITORING
################################################################################

# Monitor CPU usage
monitor_cpu() {
    local threshold="${1:-85}"
    local cpu_usage
    
    cpu_usage=$(get_cpu_usage | cut -d'%' -f1)
    
    if (( $(echo "$cpu_usage > $threshold" | bc -l) )); then
        log_warn "CPU usage high: ${cpu_usage}%" "$MONITOR_LOG"
        return 1
    fi
    
    log_debug "CPU usage: ${cpu_usage}%" "$MONITOR_LOG"
    return 0
}

# Monitor memory usage
monitor_memory() {
    local threshold="${1:-85}"
    local mem_usage
    
    mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}')
    
    if (( mem_usage > threshold )); then
        log_warn "Memory usage high: ${mem_usage}%" "$MONITOR_LOG"
        return 1
    fi
    
    log_debug "Memory usage: ${mem_usage}%" "$MONITOR_LOG"
    return 0
}

# Monitor disk usage
monitor_disk() {
    local threshold="${1:-85}"
    local disk_usage
    
    disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    
    if (( disk_usage > threshold )); then
        log_warn "Disk usage high: ${disk_usage}%" "$MONITOR_LOG"
        return 1
    fi
    
    log_debug "Disk usage: ${disk_usage}%" "$MONITOR_LOG"
    return 0
}

# Get full resource report
get_resource_report() {
    echo -e "\n${BLUE}=== Resource Usage Report ===${NC}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "${CYAN}CPU:${NC}"
    echo "  Usage: $(get_cpu_usage)"
    echo ""
    echo -e "${CYAN}Memory:${NC}"
    echo "  $(get_ram_info)"
    echo ""
    echo -e "${CYAN}Disk:${NC}"
    echo "  Root: $(get_disk_usage /)"
    echo ""
    echo -e "${CYAN}System:${NC}"
    echo "  Uptime: $(get_uptime)"
    echo "  Load Average: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
}

################################################################################
# USER MONITORING
################################################################################

# Monitor online users
count_total_online_users() {
    local count=0
    
    # SSH users
    count=$((count + $(ps aux | grep "sshd:" | grep -v "^root" | awk '{print $1}' | sort -u | wc -l)))
    
    # Xray users would be counted from Xray stats
    # This is a placeholder
    
    echo "$count"
}

# Get user statistics
get_user_statistics() {
    echo -e "\n${BLUE}=== User Statistics ===${NC}"
    
    local total_ssh
    local active_ssh
    local total_vmess
    local active_vmess
    local total_vless
    local active_vless
    
    # SSH stats
    total_ssh=$(count_users "ssh" 2>/dev/null || echo 0)
    active_ssh=$(count_active_users "ssh" 2>/dev/null || echo 0)
    
    echo "SSH Users: $active_ssh/$total_ssh active"
    
    # VMESS stats
    total_vmess=$(count_users "vmess" 2>/dev/null || echo 0)
    active_vmess=$(count_active_users "vmess" 2>/dev/null || echo 0)
    
    echo "VMESS Users: $active_vmess/$total_vmess active"
    
    # VLESS stats
    total_vless=$(count_users "vless" 2>/dev/null || echo 0)
    active_vless=$(count_active_users "vless" 2>/dev/null || echo 0)
    
    echo "VLESS Users: $active_vless/$total_vless active"
}

################################################################################
# NETWORK MONITORING
################################################################################

# Get network statistics
get_network_stats() {
    echo -e "\n${BLUE}=== Network Statistics ===${NC}"
    
    if command -v ss &>/dev/null; then
        echo "Active Connections: $(ss -tan | grep ESTAB | wc -l)"
        echo "Listen Ports: $(ss -tln | grep LISTEN | wc -l)"
    elif command -v netstat &>/dev/null; then
        echo "Active Connections: $(netstat -tan | grep ESTABLISHED | wc -l)"
        echo "Listen Ports: $(netstat -tln | grep LISTEN | wc -l)"
    fi
}

# Monitor bandwidth usage (simple)
get_bandwidth_usage() {
    local interface="${1:-eth0}"
    
    if [[ ! -f "/sys/class/net/${interface}/statistics/rx_bytes" ]]; then
        log_error "Interface not found: $interface"
        return 1
    fi
    
    local rx_bytes
    local tx_bytes
    
    rx_bytes=$(cat "/sys/class/net/${interface}/statistics/rx_bytes")
    tx_bytes=$(cat "/sys/class/net/${interface}/statistics/tx_bytes")
    
    echo "RX: $(format_bytes "$rx_bytes")"
    echo "TX: $(format_bytes "$tx_bytes")"
}

################################################################################
# AUTO-RESTART SERVICE
################################################################################

# Auto-restart failed service
auto_restart_service() {
    local service="$1"
    
    if ! is_service_running "$service"; then
        log_warn "Service $service is down, attempting restart..." "$MONITOR_LOG"
        
        if start_service "$service"; then
            log_success "Service $service restarted" "$MONITOR_LOG"
            return 0
        else
            log_error "Failed to restart service $service" "$MONITOR_LOG"
            return 1
        fi
    fi
    
    return 0
}

# Check and restart all services
auto_restart_all_services() {
    local services=("sshd" "xray" "autotunnel")
    
    for service in "${services[@]}"; do
        auto_restart_service "$service"
    done
}

################################################################################
# CONTINUOUS MONITORING
################################################################################

# Start monitoring loop
start_monitoring_loop() {
    local interval="${1:-60}"  # seconds
    
    log_info "Starting monitoring loop (interval: ${interval}s)"
    
    while true; do
        # Monitor services
        monitor_services
        
        # Monitor resources
        monitor_cpu 85
        monitor_memory 85
        monitor_disk 90
        
        # Auto-restart failed services
        auto_restart_all_services
        
        sleep "$interval"
    done
}

# Create monitoring report
create_monitoring_report() {
    local report_file="${MONITOR_LOG}.report"
    
    {
        echo "=== Monitoring Report ==="
        date
        echo ""
        get_all_service_status
        echo ""
        get_resource_report
        echo ""
        get_user_statistics
        echo ""
        get_network_stats
    } > "$report_file"
    
    echo "Report saved: $report_file"
}

return 0 2>/dev/null || true
