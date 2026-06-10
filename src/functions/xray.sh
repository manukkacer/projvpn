#!/bin/bash

################################################################################
#  XRAY MANAGEMENT FUNCTIONS
#  Unified Xray protocol management (VMESS, VLESS, TROJAN, SHADOWSOCKS)
################################################################################

[[ -z "$XRAY_FUNCTIONS_LOADED" ]] || return 0
XRAY_FUNCTIONS_LOADED=1

XRAY_CONFIG_PATH="/etc/xray"
XRAY_LOG_PATH="/var/log/xray"

# Load core functions
source /usr/local/autotunnel/functions/core.sh

################################################################################
# PROTOCOL MANAGEMENT
################################################################################

xray_add_vmess() {
    local username="$1"
    local email="$2"
    local level=${3:-0}
    
    local uuid=$(cat /proc/sys/kernel/random/uuid)
    local config_file="$XRAY_CONFIG_PATH/vmess_${username}.json"
    
    cat > "$config_file" <<EOF
{
  "inbounds": [{
    "port": 10001,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "alterId": 64,
        "level": $level,
        "email": "$email"
      }]
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    
    echo "$uuid"
    cache_set "vmess_${username}" "$uuid"
    log_info "VMESS account created: $username"
}

xray_add_vless() {
    local username="$1"
    local email="$2"
    
    local uuid=$(cat /proc/sys/kernel/random/uuid)
    local config_file="$XRAY_CONFIG_PATH/vless_${username}.json"
    
    cat > "$config_file" <<EOF
{
  "inbounds": [{
    "port": 10002,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "email": "$email"
      }],
      "decryption": "none"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    
    echo "$uuid"
    cache_set "vless_${username}" "$uuid"
    log_info "VLESS account created: $username"
}

xray_add_trojan() {
    local username="$1"
    local password="$2"
    local port=${3:-10003}
    
    local config_file="$XRAY_CONFIG_PATH/trojan_${username}.json"
    
    cat > "$config_file" <<EOF
{
  "inbounds": [{
    "port": $port,
    "protocol": "trojan",
    "settings": {
      "clients": [{
        "password": "$password",
        "email": "$username"
      }]
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    
    cache_set "trojan_${username}" "$password"
    log_info "TROJAN account created: $username"
}

xray_add_shadowsocks() {
    local username="$1"
    local password="$2"
    local cipher=${3:-aes-128-gcm}
    local port=${4:-10004}
    
    local config_file="$XRAY_CONFIG_PATH/shadowsocks_${username}.json"
    
    cat > "$config_file" <<EOF
{
  "inbounds": [{
    "port": $port,
    "protocol": "shadowsocks",
    "settings": {
      "method": "$cipher",
      "ota": false,
      "clients": [{
        "password": "$password",
        "level": 0
      }]
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    
    cache_set "shadowsocks_${username}" "$password"
    log_info "SHADOWSOCKS account created: $username"
}

################################################################################
# ACCOUNT MANAGEMENT
################################################################################

xray_delete_account() {
    local username="$1"
    local protocol="$2"
    
    local config_file="$XRAY_CONFIG_PATH/${protocol}_${username}.json"
    [[ -f "$config_file" ]] && rm -f "$config_file"
    
    cache_clear "${protocol}_${username}"
    cache_clear "vmess_${username}"
    cache_clear "vless_${username}"
    cache_clear "trojan_${username}"
    cache_clear "shadowsocks_${username}"
    
    log_info "Account deleted: $username ($protocol)"
}

xray_get_account_info() {
    local username="$1"
    local protocol="$2"
    
    local config_file="$XRAY_CONFIG_PATH/${protocol}_${username}.json"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    cat "$config_file"
}

xray_list_accounts() {
    local protocol="$1"
    find "$XRAY_CONFIG_PATH" -name "${protocol}_*.json" -type f | wc -l
}

xray_renew_account() {
    local username="$1"
    local protocol="$2"
    local days=${3:-30}
    
    # Mark renewal in cache
    cache_set "renewal_${username}" "$(date -d "+$days days" '+%Y-%m-%d')"
    log_info "Account renewed: $username for $days days"
}

################################################################################
# SERVICE MANAGEMENT
################################################################################

xray_start() {
    service_start "xray"
    sleep 1
    cache_clear_all  # Clear cache after restart
}

xray_stop() {
    service_stop "xray"
}

xray_restart() {
    service_restart "xray"
    sleep 1
    cache_clear_all
}

xray_status() {
    service_status "xray"
}

xray_is_running() {
    service_is_running "xray"
}

################################################################################
# CONFIGURATION
################################################################################

xray_test_config() {
    local config_file="${1:-$XRAY_CONFIG_PATH/config.json}"
    xray test -c "$config_file" >/dev/null 2>&1 && return 0 || return 1
}

xray_reload_config() {
    xray test -c "$XRAY_CONFIG_PATH/config.json" >/dev/null 2>&1 || return 1
    service_restart "xray"
}

################################################################################
# STATISTICS
################################################################################

xray_get_stats() {
    local protocol="$1"
    cache_get "xray_stats_${protocol}" && return 0
    
    local count=$(xray_list_accounts "$protocol")
    cache_set "xray_stats_${protocol}" "$count"
    echo "$count"
}

export -f xray_add_vmess xray_add_vless xray_add_trojan xray_add_shadowsocks
export -f xray_delete_account xray_get_account_info xray_list_accounts xray_renew_account
export -f xray_start xray_stop xray_restart xray_status xray_is_running
export -f xray_test_config xray_reload_config
export -f xray_get_stats
