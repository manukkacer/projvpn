#!/bin/bash

################################################################################
#  SSH MANAGEMENT FUNCTIONS
#  SSH account and key management
################################################################################

[[ -z "$SSH_FUNCTIONS_LOADED" ]] || return 0
SSH_FUNCTIONS_LOADED=1

SSH_DB_PATH="/usr/local/autotunnel/data/ssh"

source /usr/local/autotunnel/functions/core.sh

mkdir -p "$SSH_DB_PATH"

################################################################################
# SSH ACCOUNT CREATION
################################################################################

add_ssh_user() {
    local username="$1"
    local password="$2"
    local shell=${3:-/bin/bash}
    
    username=$(sanitize_input "$username")
    [[ -z "$username" || -z "$password" ]] && error_exit "Invalid parameters"
    
    # Check if user exists
    if id "$username" &>/dev/null; then
        error_exit "User already exists: $username"
    fi
    
    # Create system user
    useradd -m -s "$shell" -d "/home/$username" "$username" 2>/dev/null || error_exit "Failed to create user"
    
    # Set password
    echo "$username:$password" | chpasswd
    
    # Save to database
    local ssh_file="$SSH_DB_PATH/${username}.ssh"
    local created=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "$ssh_file" <<EOF
USERNAME=$username
SHELL=$shell
CREATED=$created
STATUS=active
EOF
    
    log_info "SSH user created: $username"
    echo "SSH user created: $username"
}

################################################################################
# SSH ACCOUNT DELETION
################################################################################

delete_ssh_user() {
    local username="$1"
    
    username=$(sanitize_input "$username")
    [[ -z "$username" ]] && error_exit "Invalid username"
    
    if ! id "$username" &>/dev/null; then
        error_exit "User not found: $username"
    fi
    
    # Remove user and home directory
    userdel -rf "$username" 2>/dev/null || warn "Failed to delete user $username"
    
    # Remove from database
    rm -f "$SSH_DB_PATH/${username}.ssh"
    
    log_info "SSH user deleted: $username"
    echo "SSH user deleted: $username"
}

################################################################################
# SSH USER MANAGEMENT
################################################################################

change_ssh_password() {
    local username="$1"
    local new_password="$2"
    
    username=$(sanitize_input "$username")
    [[ -z "$username" || -z "$new_password" ]] && error_exit "Invalid parameters"
    
    if ! id "$username" &>/dev/null; then
        error_exit "User not found: $username"
    fi
    
    echo "$username:$new_password" | chpasswd || error_exit "Failed to change password"
    log_info "SSH password changed for: $username"
}

list_ssh_users() {
    # List all SSH users from database
    find "$SSH_DB_PATH" -name "*.ssh" -type f | wc -l
}

################################################################################
# SSH KEY MANAGEMENT
################################################################################

generateSshKey() {
    local username="$1"
    local key_type=${2:-rsa}
    local key_size=${3:-2048}
    
    username=$(sanitize_input "$username")
    [[ -z "$username" ]] && error_exit "Invalid username"
    
    if ! id "$username" &>/dev/null; then
        error_exit "User not found: $username"
    fi
    
    local home_dir="/home/$username"
    local ssh_dir="$home_dir/.ssh"
    
    # Create .ssh directory
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Generate key
    ssh-keygen -t "$key_type" -b "$key_size" -f "$ssh_dir/id_${key_type}" -N "" -C "$username@autotunnel" <<< y >/dev/null 2>&1
    
    # Set permissions
    chmod 600 "$ssh_dir/id_${key_type}"
    chmod 644 "$ssh_dir/id_${key_type}.pub"
    chown -R "$username:$username" "$ssh_dir"
    
    log_info "SSH key generated for: $username"
    echo "SSH key generated successfully"
}

add_ssh_public_key() {
    local username="$1"
    local public_key="$2"
    
    username=$(sanitize_input "$username")
    [[ -z "$username" || -z "$public_key" ]] && error_exit "Invalid parameters"
    
    if ! id "$username" &>/dev/null; then
        error_exit "User not found: $username"
    fi
    
    local home_dir="/home/$username"
    local ssh_dir="$home_dir/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    echo "$public_key" >> "$auth_keys"
    chmod 600 "$auth_keys"
    chown -R "$username:$username" "$ssh_dir"
    
    log_info "SSH public key added for: $username"
}

export -f add_ssh_user delete_ssh_user change_ssh_password list_ssh_users
export -f generateSshKey add_ssh_public_key
