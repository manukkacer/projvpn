#!/bin/bash

################################################################################
#  USER MANAGEMENT FUNCTIONS
#  Account creation, deletion, renewal, and monitoring
################################################################################

[[ -z "$USER_FUNCTIONS_LOADED" ]] || return 0
USER_FUNCTIONS_LOADED=1

USER_DB_PATH="/usr/local/autotunnel/data/users"
ACCOUNT_CACHE_PATH="/usr/local/autotunnel/cache/accounts"

source /usr/local/autotunnel/functions/core.sh
source /usr/local/autotunnel/functions/xray.sh

mkdir -p "$USER_DB_PATH" "$ACCOUNT_CACHE_PATH"

################################################################################
# ACCOUNT CREATION
################################################################################

create_account() {
    local username="$1"
    local protocol="$2"
    local days=${3:-30}
    
    # Validate input
    username=$(sanitize_input "$username")
    [[ -z "$username" ]] && error_exit "Invalid username"
    
    # Check if account exists
    if user_exists "$username"; then
        error_exit "Account already exists: $username"
    fi
    
    local user_file="$USER_DB_PATH/${username}.user"
    local expiry=$(date -d "+$days days" '+%Y-%m-%d %H:%M:%S')
    local created=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create account based on protocol
    case "$protocol" in
        vmess)
            local credential=$(xray_add_vmess "$username" "$username@autotunnel")
            ;;
        vless)
            local credential=$(xray_add_vless "$username" "$username@autotunnel")
            ;;
        trojan)
            local credential=$(xray_add_trojan "$username" "$(random_string 16)")
            ;;
        shadowsocks)
            local credential=$(xray_add_shadowsocks "$username" "$(random_string 16)")
            ;;
        *)
            error_exit "Unknown protocol: $protocol"
            ;;
    esac
    
    # Save user record
    cat > "$user_file" <<EOF
USERNAME=$username
PROTOCOL=$protocol
CREATED=$created
EXPIRY=$expiry
CREDENTIAL=$credential
STATUS=active
BANDWIDTH=0
EOF
    
    cache_set "user_${username}" "active"
    log_info "Account created: $username ($protocol) - expires: $expiry"
    
    echo "Account created successfully"
    echo "Username: $username"
    echo "Protocol: $protocol"
    echo "Expiry: $expiry"
}

################################################################################
# ACCOUNT DELETION
################################################################################

delete_account() {
    local username="$1"
    
    username=$(sanitize_input "$username")
    [[ -z "$username" ]] && error_exit "Invalid username"
    
    local user_file="$USER_DB_PATH/${username}.user"
    
    if [[ ! -f "$user_file" ]]; then
        error_exit "Account not found: $username"
    fi
    
    # Get protocol from user file
    local protocol=$(grep '^PROTOCOL=' "$user_file" | cut -d= -f2)
    
    # Delete from xray
    xray_delete_account "$username" "$protocol"
    
    # Delete user record
    rm -f "$user_file"
    
    # Clear cache
    cache_clear "user_${username}"
    
    log_info "Account deleted: $username"
    echo "Account deleted: $username"
}

################################################################################
# ACCOUNT RENEWAL
################################################################################

renew_account() {
    local username="$1"
    local days=${2:-30}
    
    username=$(sanitize_input "$username")
    [[ -z "$username" ]] && error_exit "Invalid username"
    
    local user_file="$USER_DB_PATH/${username}.user"
    
    if [[ ! -f "$user_file" ]]; then
        error_exit "Account not found: $username"
    fi
    
    local protocol=$(grep '^PROTOCOL=' "$user_file" | cut -d= -f2)
    local expiry=$(date -d "+$days days" '+%Y-%m-%d %H:%M:%S')
    
    # Update expiry date
    sed -i "s/^EXPIRY=.*/EXPIRY=$expiry/" "$user_file"
    
    xray_renew_account "$username" "$protocol" "$days"
    cache_clear "user_${username}"
    
    log_info "Account renewed: $username - new expiry: $expiry"
    echo "Account renewed: $username"
    echo "New expiry: $expiry"
}

################################################################################
# ACCOUNT INFORMATION
################################################################################

get_account_info() {
    local username="$1"
    
    username=$(sanitize_input "$username")
    [[ -z "$username" ]] && return 1
    
    local user_file="$USER_DB_PATH/${username}.user"
    
    if [[ ! -f "$user_file" ]]; then
        return 1
    fi
    
    cat "$user_file"
}

get_account_list() {
    local protocol="$1"
    
    if [[ -z "$protocol" ]]; then
        # All accounts
        ls "$USER_DB_PATH"/*.user 2>/dev/null | wc -l
    else
        # Accounts for specific protocol
        grep -l "^PROTOCOL=$protocol" "$USER_DB_PATH"/*.user 2>/dev/null | wc -l
    fi
}

################################################################################
# ACCOUNT LIMITS
################################################################################

set_account_bandwidth_limit() {
    local username="$1"
    local limit_gb="$2"
    
    username=$(sanitize_input "$username")
    local user_file="$USER_DB_PATH/${username}.user"
    
    if [[ ! -f "$user_file" ]]; then
        error_exit "Account not found: $username"
    fi
    
    sed -i "s/^BANDWIDTH_LIMIT=.*/BANDWIDTH_LIMIT=$limit_gb/" "$user_file"
    log_info "Bandwidth limit set for $username: ${limit_gb}GB"
}

get_account_bandwidth_usage() {
    local username="$1"
    
    username=$(sanitize_input "$username")
    local user_file="$USER_DB_PATH/${username}.user"
    
    if [[ ! -f "$user_file" ]]; then
        return 1
    fi
    
    grep '^BANDWIDTH=' "$user_file" | cut -d= -f2
}

################################################################################
# TRIAL ACCOUNTS
################################################################################

create_trial_account() {
    local username="trial_$(random_string 8)"
    local protocol="${1:-vmess}"
    local days=${2:-7}
    
    create_account "$username" "$protocol" "$days"
    echo "Trial account created: $username (expires in $days days)"
}

################################################################################
# MONITORING
################################################################################

get_online_user_count() {
    # Count active connections (placeholder - protocol-specific implementation)
    ps aux | grep -E 'xray|vmess|vless|trojan' | grep -v grep | wc -l
}

get_expired_accounts() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local expired_count=0
    
    while IFS= read -r user_file; do
        local expiry=$(grep '^EXPIRY=' "$user_file" | cut -d= -f2)
        if [[ "$current_time" > "$expiry" ]]; then
            ((expired_count++))
        fi
    done < <(find "$USER_DB_PATH" -name "*.user" -type f)
    
    echo "$expired_count"
}

delete_expired_accounts() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local deleted=0
    
    while IFS= read -r user_file; do
        local username=$(grep '^USERNAME=' "$user_file" | cut -d= -f2)
        local expiry=$(grep '^EXPIRY=' "$user_file" | cut -d= -f2)
        
        if [[ "$current_time" > "$expiry" ]]; then
            delete_account "$username"
            ((deleted++))
        fi
    done < <(find "$USER_DB_PATH" -name "*.user" -type f)
    
    log_info "Deleted $deleted expired accounts"
    echo "Deleted $deleted expired accounts"
}

export -f create_account delete_account renew_account
export -f get_account_info get_account_list
export -f set_account_bandwidth_limit get_account_bandwidth_usage
export -f create_trial_account
export -f get_online_user_count get_expired_accounts delete_expired_accounts
