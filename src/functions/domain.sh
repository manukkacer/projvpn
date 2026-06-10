#!/bin/bash

################################################################################
#  DOMAIN & CERTIFICATE MANAGEMENT FUNCTIONS
#  Domain configuration and SSL/TLS certificate management with Let's Encrypt
################################################################################

[[ -z "$DOMAIN_FUNCTIONS_LOADED" ]] || return 0
DOMAIN_FUNCTIONS_LOADED=1

source /usr/local/autotunnel/functions/core.sh

CONFIG_PATH="/usr/local/autotunnel/config"

################################################################################
# DOMAIN MANAGEMENT
################################################################################

set_domain() {
    local domain="$1"
    
    # Validate domain
    if ! validate_domain "$domain"; then
        error_exit "Invalid domain format: $domain"
    fi
    
    # Save domain to config
    if [[ -f "$CONFIG_PATH/system.conf" ]]; then
        sed -i "s/^VPS_DOMAIN=.*/VPS_DOMAIN=$domain/" "$CONFIG_PATH/system.conf"
    else
        echo "VPS_DOMAIN=$domain" >> "$CONFIG_PATH/system.conf"
    fi
    
    cache_clear "vps_domain"
    log_info "Domain set: $domain"
    echo "Domain configured: $domain"
}

get_domain() {
    grep '^VPS_DOMAIN=' "$CONFIG_PATH/system.conf" 2>/dev/null | cut -d= -f2 || echo ""
}

verify_domain() {
    local domain="$1"
    
    # Check if domain resolves
    if dig +short "$domain" | grep -q .; then
        echo "Domain verified successfully"
        return 0
    else
        error_exit "Domain verification failed: $domain"
    fi
}

point_domain_to_vps() {
    local domain="$1"
    local ip=$(get_vps_ip)
    
    echo "Please point your domain to the following IP:"
    echo "Domain: $domain"
    echo "IP: $ip"
    echo "Type: A Record"
    echo ""
    echo "After updating your DNS records, run: autotunnel-verify-domain $domain"
}

################################################################################
# SSL/TLS CERTIFICATE MANAGEMENT
################################################################################

generate_ssl_certificate() {
    local domain="$1"
    local email="${2:-admin@example.com}"
    
    if ! validate_domain "$domain"; then
        error_exit "Invalid domain: $domain"
    fi
    
    log_info "Generating SSL certificate for: $domain"
    
    # Use Certbot for Let's Encrypt
    certbot certonly --standalone --non-interactive --agree-tos \
        --email "$email" -d "$domain" 2>&1 | tee -a "/usr/local/autotunnel/logs/ssl.log"
    
    if [[ $? -eq 0 ]]; then
        cache_clear "ssl_cert_${domain}"
        log_info "SSL certificate generated: $domain"
        echo "SSL certificate generated successfully"
        return 0
    else
        log_error "Failed to generate SSL certificate"
        return 1
    fi
}

renew_ssl_certificate() {
    local domain="$1"
    
    log_info "Renewing SSL certificate: $domain"
    
    certbot renew --cert-name "$domain" 2>&1 | tee -a "/usr/local/autotunnel/logs/ssl.log"
    
    if [[ $? -eq 0 ]]; then
        log_info "SSL certificate renewed: $domain"
        echo "Certificate renewed successfully"
    else
        log_error "Failed to renew certificate"
        return 1
    fi
}

auto_renew_certificates() {
    certbot renew --quiet 2>&1 | tee -a "/usr/local/autotunnel/logs/ssl.log"
    log_info "Auto-renewal check completed"
}

list_certificates() {
    certbot certificates 2>/dev/null || echo "No certificates found"
}

get_certificate_info() {
    local domain="$1"
    local cert_path="/etc/letsencrypt/live/${domain}/cert.pem"
    
    if [[ ! -f "$cert_path" ]]; then
        return 1
    fi
    
    openssl x509 -in "$cert_path" -text -noout
}

get_certificate_expiry() {
    local domain="$1"
    local cert_path="/etc/letsencrypt/live/${domain}/cert.pem"
    
    if [[ ! -f "$cert_path" ]]; then
        echo "Not found"
        return 1
    fi
    
    openssl x509 -in "$cert_path" -noout -dates | grep notAfter | cut -d= -f2
}

check_certificate_expiry() {
    local domain="$1"
    local expiry_date=$(get_certificate_expiry "$domain")
    local expiry_timestamp=$(date -d "$expiry_date" '+%s')
    local current_timestamp=$(date '+%s')
    local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    if (( days_left < 30 )); then
        warn "Certificate for $domain expires in $days_left days"
        renew_ssl_certificate "$domain"
    fi
}

################################################################################
# SYSTEM-WIDE CERTIFICATE MANAGEMENT
################################################################################

install_ssl_for_panel() {
    local domain=$(get_domain)
    
    if [[ -z "$domain" ]]; then
        error_exit "Domain not set. Please set domain first."
    fi
    
    generate_ssl_certificate "$domain" "admin@${domain}"
}

setup_auto_ssl_renewal() {
    mkdir -p /etc/systemd/system
    
    cat > /etc/systemd/system/certbot-renew.service <<EOF
[Unit]
Description=Certbot Renewal
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet
EOF
    
    cat > /etc/systemd/system/certbot-renew.timer <<EOF
[Unit]
Description=Certbot Renewal Timer
Requires=certbot-renew.service

[Timer]
OnBootSec=30min
OnUnitActiveSec=1d
AccuracySec=60s

[Install]
WantedBy=timers.target
EOF
    
    systemctl daemon-reload
    systemctl enable certbot-renew.timer
    systemctl start certbot-renew.timer
    
    log_info "Auto SSL renewal configured"
}

export -f set_domain get_domain verify_domain point_domain_to_vps
export -f generate_ssl_certificate renew_ssl_certificate auto_renew_certificates
export -f list_certificates get_certificate_info get_certificate_expiry check_certificate_expiry
export -f install_ssl_for_panel setup_auto_ssl_renewal
