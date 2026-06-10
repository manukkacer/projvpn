#!/bin/bash

################################################################################
# AUTO TUNNEL VPN PANEL - CORE LIBRARY
# Foundation functions for all modules
# Handles logging, caching, validation, and system utilities
################################################################################

set -o pipefail

# Colors for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Paths
readonly INSTALL_PATH="${INSTALL_PATH:-/usr/local/autotunnel}"
readonly LOG_DIR="${LOG_DIR:-${INSTALL_PATH}/logs}"
readonly CACHE_DIR="${CACHE_DIR:-${INSTALL_PATH}/cache}"
readonly CONFIG_DIR="${CONFIG_DIR:-${INSTALL_PATH}/config}"
readonly BACKUP_DIR="${BACKUP_DIR:-${INSTALL_PATH}/backup}"
readonly DB_DIR="${DB_DIR:-${INSTALL_PATH}/data}"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$CACHE_DIR" "$CONFIG_DIR" "$BACKUP_DIR" "$DB_DIR" 2>/dev/null || true

# Load VPS configuration
if [[ -f "${CONFIG_DIR}/vps.conf" ]]; then
    source "${CONFIG_DIR}/vps.conf"
else
    VPS_MODE="HIGH_SPEC"
    LOG_LEVEL="info"
fi

################################################################################
# LOGGING FUNCTIONS
################################################################################

# Initialize log file
init_log() {
    local log_file="${1:-${LOG_DIR}/system.log}"
    touch "$log_file" 2>/dev/null || true
    chmod 644 "$log_file" 2>/dev/null || true
}

# Write to log file
log_write() {
    local level="$1"
    local message="$2"
    local log_file="${3:-${LOG_DIR}/system.log}"
    local timestamp
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Skip debug logs in LOW_SPEC mode
    if [[ "$VPS_MODE" == "LOW_SPEC" ]] && [[ "$level" == "DEBUG" ]]; then
        return 0
    fi
    
    # Check if message should be logged based on level
    case "$LOG_LEVEL" in
        error)
            [[ "$level" != "ERROR" ]] && return 0
            ;;
        warn)
            [[ ! "$level" =~ ^(ERROR|WARN)$ ]] && return 0
            ;;
        info)
            [[ "$level" == "DEBUG" ]] && return 0
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$log_file" 2>/dev/null || true
}

# Log error
log_error() {
    local message="$1"
    local log_file="${2:-${LOG_DIR}/error.log}"
    log_write "ERROR" "$message" "$log_file"
    echo -e "${RED}[✗] ERROR: $message${NC}" >&2
}

# Log warning
log_warn() {
    local message="$1"
    local log_file="${2:-${LOG_DIR}/system.log}"
    log_write "WARN" "$message" "$log_file"
    echo -e "${YELLOW}[!] WARN: $message${NC}" >&2
}

# Log info
log_info() {
    local message="$1"
    local log_file="${2:-${LOG_DIR}/system.log}"
    log_write "INFO" "$message" "$log_file"
    echo -e "${BLUE}[i] $message${NC}"
}

# Log success
log_success() {
    local message="$1"
    local log_file="${2:-${LOG_DIR}/system.log}"
    log_write "INFO" "$message" "$log_file"
    echo -e "${GREEN}[✓] $message${NC}"
}

# Log debug
log_debug() {
    local message="$1"
    local log_file="${2:-${LOG_DIR}/system.log}"
    log_write "DEBUG" "$message" "$log_file"
    [[ "$LOG_LEVEL" == "debug" ]] && echo -e "${CYAN}[D] $message${NC}"
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################

# Validate domain name
validate_domain() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        log_error "Domain cannot be empty"
        return 1
    fi
    
    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $domain"
        return 1
    fi
    
    return 0
}

# Validate IP address
validate_ip() {
    local ip="$1"
    
    if [[ -z "$ip" ]]; then
        log_error "IP cannot be empty"
        return 1
    fi
    
    if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        log_error "Invalid IP format: $ip"
        return 1
    fi
    
    local IFS='.'
    local -a octets=($ip)
    for octet in "${octets[@]}"; do
        if (( octet > 255 )); then
            log_error "Invalid IP address: $ip"
            return 1
        fi
    done
    
    return 0
}

# Validate port number
validate_port() {
    local port="$1"
    
    if [[ -z "$port" ]] || ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "Port must be a number"
        return 1
    fi
    
    if (( port < 1 || port > 65535 )); then
        log_error "Port must be between 1 and 65535"
        return 1
    fi
    
    return 0
}

# Validate username
validate_username() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        log_error "Username cannot be empty"
        return 1
    fi
    
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]{3,32}$ ]]; then
        log_error "Username must be 3-32 alphanumeric characters"
        return 1
    fi
    
    return 0
}

# Sanitize input
sanitize_input() {
    local input="$1"
    # Remove potentially dangerous characters
    echo "$input" | sed "s/[^a-zA-Z0-9._-]//g"
}

################################################################################
# CACHE FUNCTIONS
################################################################################

# Get cache file path
get_cache_file() {
    local cache_name="$1"
    echo "${CACHE_DIR}/${cache_name}.cache"
}

# Read from cache
read_cache() {
    local cache_name="$1"
    local max_age="${2:-600}"  # Default 10 minutes
    local cache_file
    
    cache_file=$(get_cache_file "$cache_name")
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    # Check cache age
    local file_age
    file_age=$(($(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null)))
    
    if (( file_age > max_age )); then
        rm -f "$cache_file" 2>/dev/null || true
        return 1
    fi
    
    cat "$cache_file"
    return 0
}

# Write to cache
write_cache() {
    local cache_name="$1"
    local data="$2"
    local cache_file
    
    cache_file=$(get_cache_file "$cache_name")
    echo "$data" > "$cache_file" 2>/dev/null || true
}

# Clear cache
clear_cache() {
    local pattern="${1:-*}"
    rm -f "${CACHE_DIR}/${pattern}.cache" 2>/dev/null || true
}

################################################################################
# SYSTEM INFORMATION FUNCTIONS
################################################################################

# Get CPU usage percentage
get_cpu_usage() {
    if [[ -f /proc/stat ]]; then
        local cpu_info
        cpu_info=$(grep '^cpu ' /proc/stat | awk '{print ($2+$4)*100/($2+$4+$5) "%"}')
        echo "$cpu_info"
    else
        echo "N/A"
    fi
}

# Get RAM usage
get_ram_info() {
    local total_kb
    local used_kb
    local percent
    
    if command -v free &>/dev/null; then
        local mem_info
        mem_info=$(free -k | grep Mem:)
        total_kb=$(echo "$mem_info" | awk '{print $2}')
        used_kb=$(echo "$mem_info" | awk '{print $3}')
        percent=$(echo "scale=1; ($used_kb * 100) / $total_kb" | bc)
        echo "${used_kb}KB/${total_kb}KB (${percent}%)"
    else
        echo "N/A"
    fi
}

# Get disk usage
get_disk_usage() {
    local path="${1:-/}"
    if command -v df &>/dev/null; then
        df -h "$path" | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}'
    else
        echo "N/A"
    fi
}

# Get system uptime
get_uptime() {
    if [[ -f /proc/uptime ]]; then
        local uptime_sec
        uptime_sec=$(awk '{print int($1)}' /proc/uptime)
        local days=$((uptime_sec / 86400))
        local hours=$(((uptime_sec % 86400) / 3600))
        local minutes=$(((uptime_sec % 3600) / 60))
        echo "${days}d ${hours}h ${minutes}m"
    else
        echo "N/A"
    fi
}

# Get server hostname
get_hostname() {
    hostname 2>/dev/null || echo "unknown"
}

# Get server IP
get_server_ip() {
    # Try to get public IP from cache first
    if read_cache "server_ip" 3600 2>/dev/null; then
        return 0
    fi
    
    # Get public IP with timeout
    local ip
    ip=$(curl -s --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || echo "")
    
    if [[ -n "$ip" ]]; then
        write_cache "server_ip" "$ip"
        echo "$ip"
    else
        # Fallback to local IP
        hostname -I | awk '{print $1}'
    fi
}

################################################################################
# SERVICE MANAGEMENT FUNCTIONS
################################################################################

# Check if service is running
is_service_running() {
    local service="$1"
    
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

# Start service
start_service() {
    local service="$1"
    
    if systemctl start "$service"; then
        log_success "Service $service started"
        return 0
    else
        log_error "Failed to start service $service"
        return 1
    fi
}

# Stop service
stop_service() {
    local service="$1"
    
    if systemctl stop "$service"; then
        log_success "Service $service stopped"
        return 0
    else
        log_error "Failed to stop service $service"
        return 1
    fi
}

# Restart service
restart_service() {
    local service="$1"
    
    if systemctl restart "$service"; then
        log_success "Service $service restarted"
        return 0
    else
        log_error "Failed to restart service $service"
        return 1
    fi
}

# Enable service
enable_service() {
    local service="$1"
    
    if systemctl enable "$service"; then
        log_success "Service $service enabled"
        return 0
    else
        log_error "Failed to enable service $service"
        return 1
    fi
}

# Get service status
get_service_status() {
    local service="$1"
    
    if is_service_running "$service"; then
        echo "running"
    else
        echo "stopped"
    fi
}

################################################################################
# ERROR HANDLING FUNCTIONS
################################################################################

# Check command success
check_cmd() {
    if [[ $? -eq 0 ]]; then
        log_success "$1"
        return 0
    else
        log_error "$1 failed"
        return 1
    fi
}

# Exit with error
exit_error() {
    local message="$1"
    local code="${2:-1}"
    log_error "$message"
    exit "$code"
}

# Trap errors
trap_error() {
    local line_num=$1
    local error_msg="Unexpected error at line $line_num"
    log_error "$error_msg"
    return 1
}

################################################################################
# FILE OPERATIONS
################################################################################

# Safe file backup
backup_file() {
    local file="$1"
    local backup_path="${2:-${BACKUP_DIR}}"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    mkdir -p "$backup_path"
    local backup_file="${backup_path}/$(basename "$file").bak.$(date +%s)"
    
    if cp -p "$file" "$backup_file"; then
        log_success "File backed up: $backup_file"
        return 0
    else
        log_error "Failed to backup file: $file"
        return 1
    fi
}

# Safe file write
write_file() {
    local file="$1"
    local content="$2"
    local mode="${3:-644}"
    
    local dir
    dir=$(dirname "$file")
    
    mkdir -p "$dir" 2>/dev/null || true
    
    if echo "$content" > "$file"; then
        chmod "$mode" "$file" 2>/dev/null || true
        return 0
    else
        log_error "Failed to write file: $file"
        return 1
    fi
}

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        return 1
    fi
    return 0
}

# Generate random string
generate_random_string() {
    local length="${1:-32}"
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$length"
}

# Generate UUID
generate_uuid() {
    python3 -c 'import uuid; print(str(uuid.uuid4()))' 2>/dev/null || \
    cat /proc/sys/kernel/random/uuid 2>/dev/null || \
    tr -dc 'a-f0-9' </dev/urandom | head -c 32 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
}

# Wait for condition
wait_for() {
    local condition="$1"
    local timeout="${2:-30}"
    local start
    
    start=$(date +%s)
    while true; do
        if eval "$condition"; then
            return 0
        fi
        
        if (( $(date +%s) - start > timeout )); then
            return 1
        fi
        
        sleep 1
    done
}

# Convert bytes to human readable format
format_bytes() {
    local bytes="$1"
    local units=(B KB MB GB TB)
    local size=$bytes
    local unit_idx=0
    
    while (( size > 1024 && unit_idx < ${#units[@]} - 1 )); do
        size=$((size / 1024))
        ((unit_idx++))
    done
    
    echo "${size}${units[$unit_idx]}"
}

# Check if command exists
cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

return 0 2>/dev/null || true
