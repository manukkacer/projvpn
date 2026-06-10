# Auto Tunnel VPN Panel - Refactored Edition

**Modern, Lightweight, and Powerful VPN Management Panel**

## Overview

Auto Tunnel VPN Panel adalah sistem manajemen VPN yang dirancang untuk berjalan optimal pada:
- **Low Spec**: 1 Core CPU, 512MB RAM, 10GB Storage
- **High Spec**: 2-16 Core CPU, 2GB-64GB RAM

Panel ini secara otomatis mendeteksi spesifikasi VPS dan menyesuaikan konfigurasi, service, caching, logging, dan monitoring untuk performa maksimal.

## Fitur Utama

### VPN Protocols
- SSH
- VMESS
- VLESS
- TROJAN
- SHADOWSOCKS
- XRAY Management

### Management
- Create/Delete/Renew Account
- Trial Account Management
- User Limit Control
- Online User Monitoring
- User Information Tracking

### System
- Backup & Restore
- Telegram Bot Integration
- Auto Reboot & Auto Backup
- Domain Management
- Certificate Management (Let's Encrypt)
- System Monitoring
- Service Monitoring
- Bandwidth Monitor
- Log Viewer

### Administration
- VPS Information
- Service Status
- Auto Update
- System Repair
- Service Restart
- Cache Management
- Diagnostics

## Architecture

```
/usr/local/autotunnel/
├── menu/                 # Menu interface
├── modules/              # Core modules (SSH, VMESS, VLESS, etc)
├── functions/            # Shared function library
├── services/             # Systemd service files
├── cache/                # Cache management system
├── config/               # Configuration files
├── logs/                 # Application logs
├── backup/               # Backup storage
├── install/              # Installation scripts
└── update/               # Update scripts
```

## Quick Start

```bash
sudo bash install.sh
```

## System Requirements

### Minimum (Low Spec)
- OS: Ubuntu 18.04+, Debian 9+, CentOS 7+
- CPU: 1 Core
- RAM: 512MB
- Storage: 10GB

### Recommended (High Spec)
- OS: Ubuntu 20.04+, Debian 10+, CentOS 8+
- CPU: 2+ Cores
- RAM: 2GB+
- Storage: 20GB+

## Key Optimizations

### Resource Management
- Automatic VPS mode detection
- Adaptive caching (30min low-spec, 10min high-spec)
- Minimal process forking
- Optimized systemd services
- Lightweight logging in low-spec mode

### Network Optimization
- Aggressive caching reduces internet requests
- 3-5 second timeout on external calls
- Fallback to cached data on failure
- Minimized API calls

### Code Quality
- No unnecessary piping (grep file, not cat | grep)
- Built-in bash features used extensively
- Modular design with shared functions
- Removed dead code and unused dependencies

## Configuration

All configurations are located in `/usr/local/autotunnel/config/`

- `system.conf` - System-wide settings
- `vps.conf` - VPS mode and resource limits
- `cache.conf` - Cache refresh intervals
- `service.conf` - Service-specific settings
- `telegram.conf` - Bot token and settings

## Documentation

See `/docs/` for detailed documentation on:
- Installation guide
- Configuration guide
- Module development
- Troubleshooting

## License

MIT License

## Support

For issues and feature requests, please visit the GitHub repository.
