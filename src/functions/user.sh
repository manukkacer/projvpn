#!/bin/bash

################################################################################
# AUTO TUNNEL VPN PANEL - USER MANAGEMENT LIBRARY
# Handles account creation, deletion, renewal, and user operations
################################################################################

set -o pipefail

# Source core library
source "${BASH_SOURCE%/*}/core.sh" || exit 1

################################################################################
# USER DATABASE FUNCTIONS
################################################################################

# Get user database path
get_user_db() {
    local protocol="$1"
    echo "${DB_DIR}/${protocol}_users.db"
}

# Initialize user database
init_user_db() {
    local protocol="$1"
    local db_path
    
    db_path=$(get_user_db "$protocol")
    mkdir -p "${DB_DIR}"
    touch "$db_path"
    chmod 600 "$db_path"
}

# Add user to database
add_user_db() {
    local protocol="$1"
    local username="$2"
    local password="$3"
    local expiry="$4"
    local db_path
    
    db_path=$(get_user_db "$protocol")
    init_user_db "$protocol"
    
    # Format: username:password:expiry:created:last_login
    local created
    created=$(date +%s)
    
    echo "${username}:${password}:${expiry}:${created}:0" >> "$db_path"
    log_debug "User added to database: $protocol/$username"
}

# Remove user from database
remove_user_db() {
    local protocol="$1"
    local username="$2"
    local db_path
    
    db_path=$(get_user_db "$protocol")
    
    if [[ ! -f "$db_path" ]]; then
        return 1
    fi
    
    grep -v "^${username}:" "$db_path" > "${db_path}.tmp" 2>/dev/null || true
    mv "${db_path}.tmp" "$db_path"
    log_debug "User removed from database: $protocol/$username"
}

# Check if user exists
user_exists() {
    local protocol="$1"
    local username="$2"
    local db_path
    
    db_path=$(get_user_db "$protocol")
    
    if [[ ! -f "$db_path" ]]; then
        return 1
    fi
    
    grep -q "^${username}:" "$db_path" 2>/dev/null
}

# Get user expiry
get_user_expiry() {
    local protocol="$1"
    local username="$2"
    local db_path
    
    db_path=$(get_user_db "$protocol")
    
    if [[ ! -f "$db_path" ]]; then
        return 1
    fi
    
    grep "^${username}:" "$db_path" | cut -d':' -f3
}

# Update user expiry
update_user_expiry() {
    local protocol="$1"
    local username="$2"
    local new_expiry="$3"
    local db_path
    
    db_path=$(get_user_db "$protocol")
    
    if [[ ! -f "$db_path" ]]; then
        return 1
    fi
    
    # Replace the expiry field
    sed -i.bak "s/^\(${username}:[^:]*:\)[^:]*\(:[^:]*:[^:]*\)$/\1${new_expiry}\2/" "$db_path"
    rm -f "${db_path}.bak"
}

################################################################################
# ACCOUNT CREATION FUNCTIONS
################################################################################

# Create SSH account
create_ssh_user() {
    local username="$1"
    local password="$2"
    local days="${3:-30}"
    
    # Validate inputs
    if ! validate_username "$username"; then
        return 1
    fi
    
    if [[ -z "$password" ]]; then
        log_error "Password cannot be empty"
        return 1
    fi
    
    # Check if user exists
    if id "$username" &>/dev/null; then
        log_error "User already exists: $username"
        return 1
    fi
    
    # Calculate expiry
    local expiry
    expiry=$(($(date +%s) + (days * 86400)))
    
    # Create system user
    useradd -m -s /bin/bash "$username" 2>/dev/null || {
        log_error "Failed to create system user: $username"
        return 1
    }
    
    # Set password
    echo "${username}:${password}" | chpasswd || {
        log_error "Failed to set password for: $username"
        userdel -r "$username" 2>/dev/null || true
        return 1
    }
    
    # Add to database
    add_user_db "ssh" "$username" "$(echo -n "$password" | sha256sum | cut -d' ' -f1)" "$expiry"
    
    log_success "SSH user created: $username (expires: $(date -d @$expiry +'%Y-%m-%d'))"
    return 0
}

# Create trial SSH account
create_trial_ssh_user() {
    local username="$1"
    local days="${2:-7}"
    local password
    
    password=$(generate_random_string 12)
    create_ssh_user "$username" "$password" "$days"
}

# Create VMESS account
create_vmess_user() {
    local username="$1"
    local days="${2:-30}"
    local uuid
    local expiry
    
    if ! validate_username "$username"; then
        return 1
    fi
    
    if user_exists "vmess" "$username"; then
        log_error "VMESS user already exists: $username"
        return 1
    fi
    
    uuid=$(generate_uuid)
    expiry=$(($(date +%s) + (days * 86400)))
    
    add_user_db "vmess" "$username" "$uuid" "$expiry"
    
    log_success "VMESS user created: $username (UUID: $uuid)"
    echo "$uuid"
    return 0
}

# Create VLESS account
create_vless_user() {
    local username="$1"
    local days="${2:-30}"
    local uuid
    local expiry
    
    if ! validate_username "$username"; then
        return 1
    fi
    
    if user_exists "vless" "$username"; then
        log_error "VLESS user already exists: $username"
        return 1
    fi
    
    uuid=$(generate_uuid)
    expiry=$(($(date +%s) + (days * 86400)))
    
    add_user_db "vless" "$username" "$uuid" "$expiry"
    
    log_success "VLESS user created: $username (UUID: $uuid)"
    echo "$uuid"
    return 0
}

# Create Trojan account
create_trojan_user() {
    local username="$1"
    local days="${2:-30}"
    local password
    local expiry
    
    if ! validate_username "$username"; then
        return 1
    fi
    
    if user_exists "trojan" "$username"; then
        log_error "Trojan user already exists: $username"
        return 1
    fi
    
    password=$(generate_random_string 20)
    expiry=$(($(date +%s) + (days * 86400)))
    
    add_user_db "trojan" "$username" "$password" "$expiry"
    
    log_success "Trojan user created: $username"
    echo "$password"
    return 0
}

# Create Shadowsocks account
create_ss_user() {
    local username="$1"
    local days="${2:-30}"
    local password
    local expiry
    
    if ! validate_username "$username"; then
        return 1
    fi
    
    if user_exists "shadowsocks" "$username"; then
        log_error "Shadowsocks user already exists: $username"
        return 1
    fi
    
    password=$(generate_random_string 16)
    expiry=$(($(date +%s) + (days * 86400)))
    
    add_user_db "shadowsocks" "$username" "$password" "$expiry"
    
    log_success "Shadowsocks user created: $username"
    echo "$password"
    return 0
}

################################################################################
# ACCOUNT DELETION FUNCTIONS
################################################################################

# Delete SSH account
delete_ssh_user() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        log_error "User not found: $username"
        return 1
    fi
    
    # Kill user processes
    pkill -9 -u "$username" 2>/dev/null || true
    
    # Remove system user
    userdel -r "$username" 2>/dev/null || {
        log_error "Failed to delete system user: $username"
        return 1
    }
    
    # Remove from database
    remove_user_db "ssh" "$username"
    
    log_success "SSH user deleted: $username"
    return 0
}

# Delete VMESS account
delete_vmess_user() {
    local username="$1"
    
    if ! user_exists "vmess" "$username"; then
        log_error "VMESS user not found: $username"
        return 1
    fi
    
    remove_user_db "vmess" "$username"
    log_success "VMESS user deleted: $username"
    return 0
}

# Delete VLESS account
delete_vless_user() {
    local username="$1"
    
    if ! user_exists "vless" "$username"; then
        log_error "VLESS user not found: $username"
        return 1
    fi
    
    remove_user_db "vless" "$username"
    log_success "VLESS user deleted: $username"
    return 0
}

# Delete Trojan account
delete_trojan_user() {
    local username="$1"
    
    if ! user_exists "trojan" "$username"; then
        log_error "Trojan user not found: $username"
        return 1
    fi
    
    remove_user_db "trojan" "$username"
    log_success "Trojan user deleted: $username"
    return 0
}

# Delete Shadowsocks account
delete_ss_user() {
    local username="$1"
    
    if ! user_exists "shadowsocks" "$username"; then
        log_error "Shadowsocks user not found: $username"
        return 1
    fi
    
    remove_user_db "shadowsocks" "$username"
    log_success "Shadowsocks user deleted: $username"
    return 0
}

################################################################################
# ACCOUNT RENEWAL FUNCTIONS
################################################################################

# Renew user account
renew_user() {
    local protocol="$1"
    local username="$2"
    local days="${3:-30}"
    
    if ! user_exists "$protocol" "$username"; then
        log_error "User not found: $protocol/$username"
        return 1
    fi
    
    local new_expiry
    new_expiry=$(($(date +%s) + (days * 86400)))
    
    update_user_expiry "$protocol" "$username" "$new_expiry"
    
    log_success "User renewed: $protocol/$username (expires: $(date -d @$new_expiry +'%Y-%m-%d'))"
    return 0
}

################################################################################
# LIST FUNCTIONS
################################################################################

# List all users for a protocol
list_users() {
    local protocol="$1"
    local db_path
    
    db_path=$(get_user_db "$protocol")
    
    if [[ ! -f "$db_path" ]]; then
        log_info "No users found for $protocol"
        return 0
    fi
    
    echo -e "\n${BLUE}=== $protocol Users ===${NC}"
    echo -e "${CYAN}Username${NC}\t${CYAN}Expires${NC}"
    echo -e "${CYAN}--------${NC}\t${CYAN}-------${NC}"
    
    while IFS=: read -r username password expiry created last_login; do
        local expires_date
        expires_date=$(date -d @"$expiry" +'%Y-%m-%d' 2>/dev/null || echo "Invalid")
        echo -e "$username\t$expires_date"
    done < "$db_path"
}

################################################################################
# COUNT FUNCTIONS
################################################################################

# Count users for a protocol
count_users() {
    local protocol="$1"
    local db_path
    
    db_path=$(get_user_db "$protocol")
    
    if [[ ! -f "$db_path" ]]; then
        echo 0
    else
        wc -l < "$db_path"
    fi
}

# Count active users (not expired)
count_active_users() {
    local protocol="$1"
    local db_path
    local count=0
    
    db_path=$(get_user_db "$protocol")
    
    if [[ ! -f "$db_path" ]]; then
        echo 0
        return 0
    fi
    
    local now
    now=$(date +%s)
    
    while IFS=: read -r username password expiry created last_login; do
        if (( expiry > now )); then
            ((count++))
        fi
    done < "$db_path"
    
    echo "$count"
}

return 0 2>/dev/null || true
