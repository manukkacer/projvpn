#!/bin/bash

################################################################################
#  MONITORING & STATISTICS FUNCTIONS
#  Real-time system and service monitoring with adaptive mode support
################################################################################

[[ -z "$MONITOR_FUNCTIONS_LOADED" ]] || return 0
MONITOR_FUNCTIONS_LOADED=1

source /usr/local/autotunnel/functions/core.sh

################################################################################
# SYSTEM MONITORING
################################################################################

get_system_status() {
    local cpu=$(get_cpu_usage_percent)
    local ram=$(get_memory_usage_percent)
    local disk=$(df -h / | awk 'NR==2 {print $5}')
    
    echo "CPU: ${cpu}% RAM: ${ram}% Disk: $disk"
}

get_bandwidth_stats() {
    # Get network interface stats from /proc/net/dev
    local rx=$(cat /proc/net/dev | grep -E 'eth0|ens0' | awk '{print $2}' | head -1)
    local tx=$(cat /proc/net/dev | grep -E 'eth0|ens0' | awk '{print $10}' | head -1)
    
    echo "RX: $rx TX: $tx"
}

################################################################################
# SERVICE MONITORING
################################################################################

get_service_status() {
    local xray_status=$(service_status "xray")
    local ssh_status=$(service_status "ssh")
    
    echo "Xray: $xray_status SSH: $ssh_status"
}

monitor_services() {
    local services=("xray" "ssh" "autotunnel")
    
    for service in "${services[@]}"; do
        if service_is_running "$service"; then
            echo "[OK] $service is running"
        else
            echo "[FAIL] $service is NOT running"
            log_error "Service $service is not running"
        fi
    done
}

auto_restart_services() {
    local services=("xray" "autotunnel")
    
    for service in "${services[@]}"; do
        if ! service_is_running "$service"; then
            log_error "Service $service crashed, restarting..."
            service_restart "$service"
        fi
    done
}

################################################################################
# USER MONITORING
################################################################################

get_user_stats() {
    source /usr/local/autotunnel/functions/user.sh 2>/dev/null || return 1
    
    local online=$(get_online_user_count)
    echo "Online users: $online"
}

################################################################################
# PERFORMANCE METRICS
################################################################################

get_performance_metrics() {
    local load=$(uptime | awk -F'load average:' '{print $2}')
    local processes=$(ps aux | wc -l)
    
    echo "Load: $load Processes: $processes"
}

################################################################################
# CONTINUOUS MONITORING (HIGH_SPEC mode only)
################################################################################

start_continuous_monitoring() {
    [[ "$VPS_MODE" != "HIGH_SPEC" ]] && return 0
    
    while true; do
        auto_restart_services
        sleep 60
    done
}

export -f get_system_status get_bandwidth_stats
export -f get_service_status monitor_services auto_restart_services
export -f get_user_stats get_performance_metrics
export -f start_continuous_monitoring
