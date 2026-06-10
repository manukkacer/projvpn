#!/bin/bash

################################################################################
#  AUTO TUNNEL - CORE FUNCTIONS LIBRARY
#  Central library for all shared functions
################################################################################

# Prevent multiple sourcing
[[ -z "$CORE_FUNCTIONS_LOADED" ]] || return 0
CORE_FUNCTIONS_LOADED=1

# Load configuration
CONFIG_PATH="/usr/local/autotunnel/config"
CACHE_PATH="/usr/local/autotunnel/cache"
LOG_PATH="/usr/local/autotunnel/logs"

# Load VPS configuration if exists
[[ -f "$CONFIG_PATH/vps.conf" ]] && source "$CONFIG_PATH/vps.conf"

################################################################################
# LOGGING FUNCTIONS
################################################################################

log_info() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    [[ "$LOG_LEVEL" != "error" ]] && echo "[$timestamp] INFO: $msg" >> "$LOG_PATH/system.log"
}

log_error() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $msg" >> "$LOG_PATH/error.log"
}

log_debug() {
    local msg="$1"
    [[ "$LOG_LEVEL" == "debug" ]] || return 0
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] DEBUG: $msg" >> "$LOG_PATH/system.log"
}

################################################################################
# CACHE FUNCTIONS
################################################################################

cache_get() {
    local key="$1"
    local cache_file="$CACHE_PATH/${key}.cache"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    # Check cache expiration
    local age=$(($(date +%s) - $(stat -c%Y "$cache_file" 2>/dev/null || echo 0)))
    local max_age=$((${CACHE_REFRESH:-30} * 60))
    
    if (( age > max_age )); then
        rm -f "$cache_file"
        return 1
    fi
    
    cat "$cache_file"
    return 0
}

cache_set() {
    local key="$1"
    local value="$2"
    local cache_file="$CACHE_PATH/${key}.cache"
    
    echo "$value" > "$cache_file"
    chmod 644 "$cache_file"
}

cache_clear() {
    local key="$1"
    local cache_file="$CACHE_PATH/${key}.cache"
    [[ -f "$cache_file" ]] && rm -f "$cache_file"
}

cache_clear_all() {
    rm -f "$CACHE_PATH"/*.cache
}

################################################################################
# SYSTEM INFORMATION FUNCTIONS
################################################################################

get_vps_ip() {
    # Try cache first
    cache_get "vps_ip" && return 0
    
    local ip=$(curl -s --max-time 3 -4 https://ipinfo.io/ip 2>/dev/null || \
               curl -s --max-time 3 -4 https://api.ipify.org 2>/dev/null || \
               hostname -I | awk '{print $1}')
    
    [[ -n "$ip" ]] && cache_set "vps_ip" "$ip"
    echo "$ip"
}

get_vps_domain() {
    # Try cache first
    cache_get "vps_domain" && return 0
    
    # Read from config if set
    if [[ -f "$CONFIG_PATH/system.conf" ]]; then
        source "$CONFIG_PATH/system.conf"
        [[ -n "$VPS_DOMAIN" ]] && cache_set "vps_domain" "$VPS_DOMAIN" && echo "$VPS_DOMAIN" && return 0
    fi
    
    # Try reverse DNS lookup
    local domain=$(dig -x $(get_vps_ip) +short 2>/dev/null | sed 's/\.$//' | head -1)
    [[ -n "$domain" ]] && cache_set "vps_domain" "$domain" && echo "$domain"
}

get_vps_hostname() {
    hostname -f 2>/dev/null || hostname
}

get_isp_info() {
    # Try cache first
    cache_get "isp_info" && return 0
    
    local ip=$(get_vps_ip)
    local isp=$(curl -s --max-time 3 "https://ipinfo.io/$ip/org" 2>/dev/null | grep -o '[^ ]*$' || echo "Unknown")
    
    cache_set "isp_info" "$isp"
    echo "$isp"
}

get_location_info() {
    # Try cache first
    cache_get "location_info" && return 0
    
    local ip=$(get_vps_ip)
    local location=$(curl -s --max-time 3 "https://ipinfo.io/$ip/city,country" 2>/dev/null || echo "Unknown")
    
    cache_set "location_info" "$location"
    echo "$location"
}

get_cpu_info() {
    # Try cache first
    cache_get "cpu_info" && return 0
    
    local cores=$(nproc 2>/dev/null || echo "1")
    local usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' || echo "0")
    local info="${cores} cores, ${usage}% used"
    
    cache_set "cpu_info" "$info"
    echo "$info"
}

get_ram_info() {
    # Try cache first
    cache_get "ram_info" && return 0
    
    local total=$(free -m | awk 'NR==2 {print $2}')
    local used=$(free -m | awk 'NR==2 {print $3}')
    local info="${used}MB/${total}MB"
    
    cache_set "ram_info" "$info"
    echo "$info"
}

get_uptime() {
    uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | sed 's/,.*//' | xargs
}

get_disk_info() {
    local usage=$(df -h / | awk 'NR==2 {print $3"/"$2}')
    echo "$usage"
}

################################################################################
# SERVICE MANAGEMENT FUNCTIONS
################################################################################

service_start() {
    local service="$1"
    systemctl start "$service" 2>/dev/null && log_info "Service started: $service" || log_error "Failed to start service: $service"
}

service_stop() {
    local service="$1"
    systemctl stop "$service" 2>/dev/null && log_info "Service stopped: $service" || log_error "Failed to stop service: $service"
}

service_restart() {
    local service="$1"
    systemctl restart "$service" 2>/dev/null && log_info "Service restarted: $service" || log_error "Failed to restart service: $service"
}

service_enable() {
    local service="$1"
    systemctl enable "$service" 2>/dev/null && log_info "Service enabled: $service" || log_error "Failed to enable service: $service"
}

service_status() {
    local service="$1"
    systemctl is-active "$service" 2>/dev/null && echo "active" || echo "inactive"
}

service_is_running() {
    local service="$1"
    systemctl is-active "$service" >/dev/null 2>&1
}

################################################################################
# FILE & TEXT FUNCTIONS
################################################################################

sanitize_input() {
    local input="$1"
    # Remove dangerous characters
    echo "$input" | sed 's/[^a-zA-Z0-9._-]//g'
}

validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

validate_domain() {
    local domain="$1"
    if [[ $domain =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

validate_port() {
    local port="$1"
    if [[ $port =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
        return 0
    fi
    return 1
}

################################################################################
# USER MANAGEMENT FUNCTIONS
################################################################################

get_online_users() {
    local protocol="$1"
    # Placeholder - will be implemented per-protocol
    echo "0"
}

get_total_users() {
    local protocol="$1"
    # Placeholder - will be implemented per-protocol
    echo "0"
}

user_exists() {
    local username="$1"
    [[ -f "/usr/local/autotunnel/cache/users/${username}.user" ]] && return 0 || return 1
}

################################################################################
# PROCESS & PERFORMANCE FUNCTIONS
################################################################################

get_process_count() {
    ps aux | wc -l
}

get_memory_usage_percent() {
    free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}'
}

get_cpu_usage_percent() {
    top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%.0f", 100 - $1}' || echo "0"
}

################################################################################
# NETWORK FUNCTIONS
################################################################################

check_port_open() {
    local port="$1"
    timeout 2 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null && return 0 || return 1
}

get_open_ports() {
    ss -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | cut -d: -f2- || echo "N/A"
}

################################################################################
# UTILITY FUNCTIONS
################################################################################

random_string() {
    local length=${1:-16}
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$length"
}

random_port() {
    local min=${1:-10000}
    local max=${2:-60000}
    echo $((RANDOM % (max - min + 1) + min))
}

get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

sleep_optimized() {
    # Use sleep with minimal overhead, respects LOW_SPEC mode
    local seconds="$1"
    if [[ "$VPS_MODE" == "LOW_SPEC" ]]; then
        # Shorter sleep cycles in low-spec mode
        sleep "${seconds}s"
    else
        sleep "${seconds}s"
    fi
}

################################################################################
# ERROR HANDLING
################################################################################

error_exit() {
    local msg="$1"
    local code=${2:-1}
    log_error "$msg"
    echo "[ERROR] $msg" >&2
    exit "$code"
}

warn() {
    local msg="$1"
    echo "[WARN] $msg" >&2
    log_info "WARNING: $msg"
}

info() {
    local msg="$1"
    echo "[INFO] $msg"
    log_info "$msg"
}

export -f log_info log_error log_debug
export -f cache_get cache_set cache_clear cache_clear_all
export -f get_vps_ip get_vps_domain get_vps_hostname
export -f get_isp_info get_location_info
export -f get_cpu_info get_ram_info get_uptime get_disk_info
export -f service_start service_stop service_restart service_enable service_status service_is_running
export -f sanitize_input validate_ip validate_domain validate_port
export -f get_online_users get_total_users user_exists
export -f get_process_count get_memory_usage_percent get_cpu_usage_percent
export -f check_port_open get_open_ports
export -f random_string random_port get_timestamp sleep_optimized
export -f error_exit warn info
