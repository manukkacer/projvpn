#!/bin/bash

################################################################################
# AUTO TUNNEL VPN PANEL - DOMAIN & SSL MANAGEMENT LIBRARY
# Handles domain management, SSL certificates, and DNS configuration
################################################################################

set -o pipefail

# Source core library
source "${BASH_SOURCE%/*}/core.sh" || exit 1

readonly DOMAIN_CONFIG="${CONFIG_DIR}/domain.conf"
readonly SSL_DIR="/etc/letsencrypt/live"
readonly SSL_CERT_DIR="/etc/ssl/certs"

################################################################################
# DOMAIN MANAGEMENT
################################################################################

# Save domain configuration
save_domain() {
    local domain="$1"
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    echo "DOMAIN=$domain" > "$DOMAIN_CONFIG"
    echo "DOMAIN_SET_DATE=$(date +%s)" >> "$DOMAIN_CONFIG"
    
    log_success "Domain saved: $domain"
    write_cache "domain" "$domain" 86400
    return 0
}

# Get current domain
get_current_domain() {
    if [[ -f "$DOMAIN_CONFIG" ]]; then
        grep "^DOMAIN=" "$DOMAIN_CONFIG" | cut -d'=' -f2
    else
        echo "Not configured"
    fi
}

# Verify domain points to server
verify_domain() {
    local domain="$1"
    local server_ip="$2"
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    if [[ -z "$server_ip" ]]; then
        server_ip=$(get_server_ip)
    fi
    
    local domain_ip
    domain_ip=$(dig +short "$domain" @8.8.8.8 | tail -n1)
    
    if [[ "$domain_ip" == "$server_ip" ]]; then
        log_success "Domain verification passed: $domain -> $server_ip"
        return 0
    else
        log_error "Domain verification failed: $domain -> $domain_ip (expected: $server_ip)"
        return 1
    fi
}

################################################################################
# SSL CERTIFICATE MANAGEMENT
################################################################################

# Check if Certbot is installed
certbot_installed() {
    command -v certbot &>/dev/null
}

# Install Certbot
install_certbot() {
    if certbot_installed; then
        log_info "Certbot is already installed"
        return 0
    fi
    
    log_info "Installing Certbot..."
    
    apt-get update >/dev/null
    apt-get install -y certbot python3-certbot-nginx >/dev/null 2>&1 || \
    apt-get install -y certbot python3-certbot-apache >/dev/null 2>&1 || \
    apt-get install -y certbot >/dev/null 2>&1 || {
        log_error "Failed to install Certbot"
        return 1
    }
    
    log_success "Certbot installed"
    return 0
}

# Create self-signed certificate
create_self_signed_cert() {
    local domain="$1"
    local days="${2:-365}"
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    log_info "Creating self-signed certificate for: $domain"
    
    mkdir -p "$SSL_CERT_DIR"
    
    openssl req -x509 -newkey rsa:4096 -keyout "${SSL_CERT_DIR}/${domain}.key" \
        -out "${SSL_CERT_DIR}/${domain}.crt" -days "$days" -nodes \
        -subj "/C=ID/ST=State/L=City/O=Organization/CN=${domain}" || {
        log_error "Failed to create self-signed certificate"
        return 1
    }
    
    log_success "Self-signed certificate created: $domain"
    return 0
}

# Create Let's Encrypt certificate
create_letsencrypt_cert() {
    local domain="$1"
    local email="${2:-admin@${domain}}"
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    if ! certbot_installed; then
        install_certbot || return 1
    fi
    
    log_info "Creating Let's Encrypt certificate for: $domain"
    
    certbot certonly --standalone -d "$domain" --non-interactive \
        --agree-tos --email "$email" 2>&1 | tee -a "${LOG_DIR}/ssl.log" || {
        log_error "Failed to create Let's Encrypt certificate"
        return 1
    }
    
    log_success "Let's Encrypt certificate created: $domain"
    return 0
}

# Get certificate path
get_cert_path() {
    local domain="$1"
    
    if [[ -f "${SSL_DIR}/${domain}/fullchain.pem" ]]; then
        echo "${SSL_DIR}/${domain}/fullchain.pem"
    elif [[ -f "${SSL_CERT_DIR}/${domain}.crt" ]]; then
        echo "${SSL_CERT_DIR}/${domain}.crt"
    else
        return 1
    fi
}

# Get certificate key path
get_cert_key_path() {
    local domain="$1"
    
    if [[ -f "${SSL_DIR}/${domain}/privkey.pem" ]]; then
        echo "${SSL_DIR}/${domain}/privkey.pem"
    elif [[ -f "${SSL_CERT_DIR}/${domain}.key" ]]; then
        echo "${SSL_CERT_DIR}/${domain}.key"
    else
        return 1
    fi
}

# Check certificate expiry
check_cert_expiry() {
    local cert_path
    cert_path=$(get_cert_path "$1")
    
    if [[ ! -f "$cert_path" ]]; then
        log_error "Certificate not found: $1"
        return 1
    fi
    
    local expiry_date
    local days_left
    
    expiry_date=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d'=' -f2)
    days_left=$(( ($(date -d "$expiry_date" +%s) - $(date +%s)) / 86400 ))
    
    echo "Certificate for $1 expires in $days_left days ($expiry_date)"
    
    if (( days_left < 0 )); then
        return 1
    fi
    
    return 0
}

# Renew Let's Encrypt certificate
renew_letsencrypt_cert() {
    local domain="$1"
    
    if ! certbot_installed; then
        log_error "Certbot is not installed"
        return 1
    fi
    
    log_info "Renewing Let's Encrypt certificate for: $domain"
    
    certbot renew --force-renewal -d "$domain" 2>&1 | tee -a "${LOG_DIR}/ssl.log" || {
        log_error "Failed to renew Let's Encrypt certificate"
        return 1
    }
    
    log_success "Certificate renewed: $domain"
    return 0
}

# Setup auto-renewal
setup_auto_renewal() {
    if ! certbot_installed; then
        install_certbot || return 1
    fi
    
    log_info "Setting up auto-renewal timer..."
    
    # Create systemd timer for renewal
    cat > /etc/systemd/system/certbot-renew.timer <<EOF
[Unit]
Description=Let's Encrypt Renewal Timer
After=network-online.target

[Timer]
OnBootSec=1d
OnUnitActiveSec=1d

[Install]
WantedBy=timers.target
EOF
    
    # Create systemd service for renewal
    cat > /etc/systemd/system/certbot-renew.service <<EOF
[Unit]
Description=Let's Encrypt Renewal Service
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet
ExecStartPost=/usr/sbin/systemctl reload nginx
EOF
    
    systemctl daemon-reload
    systemctl enable certbot-renew.timer
    systemctl start certbot-renew.timer
    
    log_success "Auto-renewal configured"
    return 0
}

################################################################################
# DNS MANAGEMENT
################################################################################

# Check DNS resolution
check_dns() {
    local domain="$1"
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    echo "DNS Resolution for $domain:"
    dig +short "$domain" @8.8.8.8
}

# Test DNS propagation
test_dns_propagation() {
    local domain="$1"
    local nameservers=("8.8.8.8" "1.1.1.1" "208.67.222.222" "9.9.9.9")
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    echo "Testing DNS propagation for $domain:"
    for ns in "${nameservers[@]}"; do
        local result
        result=$(dig +short "$domain" @"$ns" | tail -n1)
        echo "  $ns: $result"
    done
}

################################################################################
# CERTIFICATE VIEWING
################################################################################

# Display certificate information
show_cert_info() {
    local domain="$1"
    local cert_path
    
    cert_path=$(get_cert_path "$domain")
    
    if [[ ! -f "$cert_path" ]]; then
        log_error "Certificate not found for: $domain"
        return 1
    fi
    
    echo -e "\n${BLUE}=== Certificate Information ===${NC}"
    echo "Domain: $domain"
    echo ""
    openssl x509 -in "$cert_path" -noout -text | grep -E "Subject:|Issuer:|Not Before|Not After|Public-Key:"
}

return 0 2>/dev/null || true
