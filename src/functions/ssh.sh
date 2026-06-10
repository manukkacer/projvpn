#!/bin/bash

################################################################################
# AUTO TUNNEL VPN PANEL - SSH MANAGEMENT LIBRARY
# Handles SSH user creation, deletion, renewal, and management
################################################################################

set -o pipefail

# Source core library
source "${BASH_SOURCE%/*}/core.sh" || exit 1
source "${BASH_SOURCE%/*}/user.sh" || exit 1

readonly SSH_PORT=22
readonly SSHD_CONFIG="/etc/ssh/sshd_config"

################################################################################
# SSH SERVICE MANAGEMENT
################################################################################

# Check SSH service status
ssh_is_running() {
    is_service_running sshd
}

# Start SSH service
start_ssh() {
    start_service sshd
}

# Stop SSH service
stop_ssh() {
    stop_service sshd
}

# Restart SSH service
restart_ssh() {
    restart_service sshd
}

################################################################################
# SSH CONFIGURATION
################################################################################

# Backup SSH config
backup_ssh_config() {
    backup_file "$SSHD_CONFIG"
}

# Get SSH config value
get_ssh_config_value() {
    local key="$1"
    grep "^${key}" "$SSHD_CONFIG" | head -n1 | awk '{print $2}'
}

# Set SSH config value
set_ssh_config_value() {
    local key="$1"
    local value="$2"
    
    if grep -q "^${key}" "$SSHD_CONFIG"; then
        sed -i "s/^${key} .*/${key} ${value}/" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

################################################################################
# SSH USER OPERATIONS
################################################################################

# Create SSH user with extended features
create_ssh_user_full() {
    local username="$1"
    local password="$2"
    local days="${3:-30}"
    local shell="${4:-/bin/bash}"
    local home="${5:-/home/$username}"
    
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
    useradd -m -d "$home" -s "$shell" "$username" || {
        log_error "Failed to create system user: $username"
        return 1
    }
    
    # Set password
    echo "${username}:${password}" | chpasswd || {
        log_error "Failed to set password for: $username"
        userdel -r "$username" 2>/dev/null || true
        return 1
    }
    
    # Set password expiry
    chage -M "$days" "$username" 2>/dev/null || true
    
    # Set home directory permissions
    chmod 700 "$home" 2>/dev/null || true
    
    # Add to database
    add_user_db "ssh" "$username" "$(echo -n "$password" | sha256sum | cut -d' ' -f1)" "$expiry"
    
    log_success "SSH user created: $username (expires: $(date -d @$expiry +'%Y-%m-%d'))"
    write_cache "ssh_user_${username}" "$username:$expiry" 300
    
    return 0
}

# Delete SSH user completely
delete_ssh_user_full() {
    local username="$1"
    local keep_home="${2:-false}"
    
    if ! id "$username" &>/dev/null; then
        log_error "User not found: $username"
        return 1
    fi
    
    # Kill user processes
    pkill -9 -u "$username" 2>/dev/null || true
    sleep 1
    
    # Close SSH sessions
    pkill -9 -f "sshd.*\[$username\]" 2>/dev/null || true
    
    # Remove system user
    if [[ "$keep_home" == "true" ]]; then
        userdel "$username" 2>/dev/null || {
            log_error "Failed to delete system user: $username"
            return 1
        }
    else
        userdel -r "$username" 2>/dev/null || {
            log_error "Failed to delete system user: $username"
            return 1
        }
    fi
    
    # Remove from database
    remove_user_db "ssh" "$username"
    
    # Clear cache
    clear_cache "ssh_user_*"
    
    log_success "SSH user deleted: $username"
    return 0
}

# Change SSH user password
change_ssh_password() {
    local username="$1"
    local new_password="$2"
    
    if ! id "$username" &>/dev/null; then
        log_error "User not found: $username"
        return 1
    fi
    
    if [[ -z "$new_password" ]]; then
        log_error "Password cannot be empty"
        return 1
    fi
    
    # Set new password
    echo "${username}:${new_password}" | chpasswd || {
        log_error "Failed to change password for: $username"
        return 1
    }
    
    log_success "Password changed for: $username"
    return 0
}

# Renew SSH user expiry
renew_ssh_user() {
    local username="$1"
    local days="${2:-30}"
    
    if ! id "$username" &>/dev/null; then
        log_error "User not found: $username"
        return 1
    fi
    
    local new_expiry
    new_expiry=$(($(date +%s) + (days * 86400)))
    
    # Update expiry in system
    chage -M "$days" "$username" 2>/dev/null || true
    
    # Update in database
    update_user_expiry "ssh" "$username" "$new_expiry"
    
    log_success "SSH user renewed: $username (expires: $(date -d @$new_expiry +'%Y-%m-%d'))"
    return 0
}

################################################################################
# SSH USER LOCKING/UNLOCKING
################################################################################

# Lock SSH user account
lock_ssh_user() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        log_error "User not found: $username"
        return 1
    fi
    
    usermod -L "$username" || {
        log_error "Failed to lock user: $username"
        return 1
    }
    
    log_success "SSH user locked: $username"
    return 0
}

# Unlock SSH user account
unlock_ssh_user() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        log_error "User not found: $username"
        return 1
    fi
    
    usermod -U "$username" || {
        log_error "Failed to unlock user: $username"
        return 1
    }
    
    log_success "SSH user unlocked: $username"
    return 0
}

# Check if user is locked
is_user_locked() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        return 1
    fi
    
    passwd -S "$username" | grep -q "L"
}

################################################################################
# SSH USER INFORMATION
################################################################################

# Get SSH user info
get_ssh_user_info() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        log_error "User not found: $username"
        return 1
    fi
    
    echo "Username: $username"
    id "$username"
    
    if user_exists "ssh" "$username"; then
        local expiry
        expiry=$(get_user_expiry "ssh" "$username")
        echo "Expires: $(date -d @$expiry +'%Y-%m-%d %H:%M:%S')"
    fi
}

# Check online SSH users
check_online_ssh_users() {
    local username="${1:-all}"
    
    echo -e "\n${BLUE}=== Online SSH Users ===${NC}"
    
    if [[ "$username" == "all" ]]; then
        ps aux | grep "sshd:" | grep -v "^root" | awk '{print $1}' | sort -u
    else
        if ps aux | grep "sshd:.*\[$username\]" &>/dev/null; then
            echo "$username is online"
            return 0
        else
            echo "$username is offline"
            return 1
        fi
    fi
}

# Count online SSH users
count_online_ssh_users() {
    ps aux | grep "sshd:" | grep -v "^root" | awk '{print $1}' | sort -u | wc -l
}

################################################################################
# SSH LOGIN DETECTION
################################################################################

# Check last login
get_last_login() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        log_error "User not found: $username"
        return 1
    fi
    
    lastlog -u "$username" 2>/dev/null | tail -n1
}

# Check failed login attempts
get_failed_logins() {
    local username="$1"
    
    if [[ -f /var/log/auth.log ]]; then
        grep "Failed password for $username" /var/log/auth.log | wc -l
    elif [[ -f /var/log/secure ]]; then
        grep "Failed password for $username" /var/log/secure | wc -l
    else
        echo 0
    fi
}

################################################################################
# MULTI-LOGIN DETECTION
################################################################################

# Limit simultaneous logins per user
set_login_limit() {
    local username="$1"
    local max_logins="${2:-1}"
    
    # Configure limits via limits.conf
    echo "${username} maxlogins ${max_logins}" >> /etc/security/limits.conf 2>/dev/null || true
    
    log_success "Login limit set for $username: $max_logins"
}

# Get current login count
get_current_login_count() {
    local username="$1"
    who | grep "^${username}" | wc -l
}

# Kill other SSH sessions for user
kill_other_ssh_sessions() {
    local username="$1"
    local keep_pid="${2:-$$}"
    
    ps aux | grep "sshd:.*\[$username\]" | grep -v "$$" | awk '{print $2}' | while read -r pid; do
        if [[ "$pid" != "$keep_pid" ]]; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
}

return 0 2>/dev/null || true
