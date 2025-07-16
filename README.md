# Shadowsocks + WireGuard Dual-Stack Automation Script

An enhanced automation script that combines Shadowsocks server with WireGuard functionality, providing robust network configuration, improved firewall rules, and comprehensive service management.

## Features

### Core Functionality
- **Shadowsocks Server**: Automated installation and configuration of shadowsocks-libev
- **WireGuard Integration**: Seamless WireGuard configuration using Cloudflare WARP
- **Dual-Stack Support**: Full IPv4/IPv6 support with automatic network detection
- **Robust Network Configuration**: Enhanced network checking and validation
- **Intelligent Firewall Rules**: Precise iptables/firewalld/ufw configuration
- **Service Management**: Comprehensive systemd service management
- **MTU Optimization**: Automatic MTU detection and optimization

### Enhanced Features
- **Network Diagnostics**: Built-in connectivity testing and troubleshooting
- **Service Monitoring**: Real-time service status checking
- **Configuration Validation**: Automatic configuration file validation
- **Detailed Logging**: Comprehensive logging with timestamps
- **Error Handling**: Robust error handling and recovery mechanisms
- **Interactive Menu**: User-friendly interactive interface

## System Requirements

### Supported Operating Systems
- **Debian**: 10 (Buster), 11 (Bullseye), 12 (Bookworm)
- **Ubuntu**: 18.04 (Bionic), 20.04 (Focal), 22.04 (Jammy), 24.04 (Noble)
- **CentOS/RHEL**: 8, 9
- **Fedora**: Recent versions
- **Arch Linux**: Rolling release

### Prerequisites
- Root privileges
- Internet connectivity (can be bypassed with --force)
- curl installed
- systemd-based system

## Installation

### Quick Start
```bash
# Download and run the script
curl -fsSL https://raw.githubusercontent.com/9val/warp/main/shadowsocks-warp.sh | sudo bash

# Or download and run manually
wget https://raw.githubusercontent.com/9val/warp/main/shadowsocks-warp.sh
chmod +x shadowsocks-warp.sh
sudo ./shadowsocks-warp.sh
```

### Manual Installation
```bash
# Clone the repository
git clone https://github.com/9val/warp.git
cd warp

# Make script executable
chmod +x shadowsocks-warp.sh

# Run the script
sudo ./shadowsocks-warp.sh
```

## Usage

### Command Line Interface
```bash
# Install and configure everything
sudo ./shadowsocks-warp.sh install

# Check service status
sudo ./shadowsocks-warp.sh status

# Run connection tests
sudo ./shadowsocks-warp.sh test

# Run full diagnostics
sudo ./shadowsocks-warp.sh diagnostics

# Restart services
sudo ./shadowsocks-warp.sh restart

# View connection information
sudo ./shadowsocks-warp.sh info

# Configure firewall rules
sudo ./shadowsocks-warp.sh firewall

# Cleanup installation
sudo ./shadowsocks-warp.sh cleanup

# Show interactive menu
sudo ./shadowsocks-warp.sh menu

# Show help
sudo ./shadowsocks-warp.sh help
```

### Command Line Options
```bash
# Force execution without network connectivity
sudo ./shadowsocks-warp.sh install --force

# Set custom Shadowsocks port
sudo ./shadowsocks-warp.sh install --port 9999

# Set custom password
sudo ./shadowsocks-warp.sh install --password "your-password"

# Set custom encryption method
sudo ./shadowsocks-warp.sh install --method chacha20-ietf-poly1305

# Combine multiple options
sudo ./shadowsocks-warp.sh install --port 9999 --password "your-password" --method chacha20-ietf-poly1305
```

### Interactive Menu
If run without arguments, the script provides an interactive menu:
```bash
sudo ./shadowsocks-warp.sh
```

## Configuration

### Shadowsocks Configuration
The script automatically configures Shadowsocks with:
- **Default Port**: 8388 (customizable)
- **Default Method**: aes-256-gcm (customizable)
- **Password**: Auto-generated secure password (customizable)
- **Timeout**: 60 seconds
- **Configuration File**: `/etc/shadowsocks-libev/config.json`

### WireGuard Configuration
WireGuard is configured with:
- **Interface**: wgcf
- **Configuration File**: `/etc/wireguard/wgcf.conf`
- **MTU**: Auto-detected optimal value
- **DNS**: Cloudflare DNS servers (1.1.1.1, 1.0.0.1)
- **Routing**: Policy-based routing with custom table

### Firewall Rules
The script configures appropriate firewall rules for:
- **Shadowsocks**: Opens configured port (TCP/UDP)
- **WireGuard**: Opens port 2408 (UDP)
- **NAT**: Configures masquerading for WireGuard traffic
- **IPv6**: Full IPv6 support when available

## Network Architecture

### Dual-Stack Configuration
The script implements a dual-stack configuration that:
1. **Primary Path**: Client connects to Shadowsocks server
2. **Secondary Path**: Shadowsocks traffic is routed through WireGuard
3. **Failover**: Automatic failover between IPv4 and IPv6
4. **Optimization**: MTU optimization for both protocols

### Traffic Flow
```
Client → Shadowsocks → WireGuard → Cloudflare WARP → Internet
```

## Troubleshooting

### Common Issues

#### Shadowsocks Connection Problems
1. **Check service status**: `sudo ./shadowsocks-warp.sh status`
2. **Test connectivity**: `sudo ./shadowsocks-warp.sh test`
3. **Check firewall rules**: Ensure port is open in firewall
4. **Verify configuration**: Check `/etc/shadowsocks-libev/config.json`

#### WireGuard Issues
1. **Check interface**: `sudo wg show`
2. **Verify routing**: `ip route show table 51888`
3. **Check DNS**: `dig @1.1.1.1 google.com`
4. **Test connectivity**: `ping -I wgcf 8.8.8.8`

#### Network Connectivity
1. **Run diagnostics**: `sudo ./shadowsocks-warp.sh diagnostics`
2. **Check logs**: `journalctl -u shadowsocks-libev -f`
3. **Verify MTU**: Check auto-detected MTU values
4. **Test routing**: Verify policy routing rules

### Log Files
- **Installation Log**: `/var/log/shadowsocks-warp/install.log`
- **Connection Info**: `/var/log/shadowsocks-warp/connection_info.txt`
- **Shadowsocks Log**: `journalctl -u shadowsocks-libev`
- **WireGuard Log**: `journalctl -u wg-quick@wgcf`

### Debug Mode
For additional debugging information:
```bash
# Enable debug logging
export DEBUG=1
sudo ./shadowsocks-warp.sh diagnostics
```

## Security Considerations

### Best Practices
1. **Change Default Port**: Use non-standard port for Shadowsocks
2. **Strong Password**: Use complex, unique passwords
3. **Regular Updates**: Keep system and packages updated
4. **Firewall Rules**: Regularly review and update firewall rules
5. **Log Monitoring**: Monitor logs for suspicious activity

### Encryption
- **Shadowsocks**: Uses AEAD ciphers by default (aes-256-gcm)
- **WireGuard**: ChaCha20-Poly1305 encryption
- **Key Exchange**: Automatic key generation and rotation

## Performance Optimization

### MTU Optimization
The script automatically:
- Detects optimal MTU values
- Configures WireGuard MTU appropriately
- Handles IPv4/IPv6 MTU differences

### Network Tuning
Recommended system optimizations:
```bash
# Increase network buffer sizes
echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' >> /etc/sysctl.conf

# Optimize TCP settings
echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf

# Apply changes
sysctl -p
```

## Advanced Configuration

### Custom Configuration Files
You can customize the generated configuration files:
- **Shadowsocks**: Edit `/etc/shadowsocks-libev/config.json`
- **WireGuard**: Edit `/etc/wireguard/wgcf.conf`

### Service Management
```bash
# Manual service control
sudo systemctl start shadowsocks-libev
sudo systemctl start wg-quick@wgcf

# Enable auto-start
sudo systemctl enable shadowsocks-libev
sudo systemctl enable wg-quick@wgcf

# View service status
sudo systemctl status shadowsocks-libev
sudo systemctl status wg-quick@wgcf
```

## Contributing

### Development
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Bug Reports
Please include:
- Operating system and version
- Script version
- Error messages
- Log files
- Steps to reproduce

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgments

- **P3TERX/warp.sh**: Original WireGuard WARP script
- **Shadowsocks**: Shadowsocks project
- **WireGuard**: WireGuard VPN project
- **Cloudflare**: WARP service

## Support

For support and questions:
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Documentation**: This README and inline comments

---

**Note**: This script is provided as-is. Use at your own risk. Always test in a safe environment before deploying to production.