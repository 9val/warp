#!/usr/bin/env bash
#
# Shadowsocks + WireGuard Dual-Stack Automation Script
# Enhanced version with improved network configuration, firewall rules, and service management
# Based on warp.sh by P3TERX and optimized for Shadowsocks integration
#
# System Required: Debian, Ubuntu, CentOS, Fedora, Oracle Linux, Arch Linux
# Version: 1.0.0
#

shVersion='1.0.0'

# Color definitions for logging
FontColor_Red="\033[31m"
FontColor_Red_Bold="\033[1;31m"
FontColor_Green="\033[32m"
FontColor_Green_Bold="\033[1;32m"
FontColor_Yellow="\033[33m"
FontColor_Yellow_Bold="\033[1;33m"
FontColor_Purple="\033[35m"
FontColor_Purple_Bold="\033[1;35m"
FontColor_Suffix="\033[0m"

# Enhanced logging function
log() {
    local LEVEL="$1"
    local MSG="$2"
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    case "${LEVEL}" in
    INFO)
        local LEVEL="[${FontColor_Green}${LEVEL}${FontColor_Suffix}]"
        local MSG="${LEVEL} ${TIMESTAMP} ${MSG}"
        ;;
    WARN)
        local LEVEL="[${FontColor_Yellow}${LEVEL}${FontColor_Suffix}]"
        local MSG="${LEVEL} ${TIMESTAMP} ${MSG}"
        ;;
    ERROR)
        local LEVEL="[${FontColor_Red}${LEVEL}${FontColor_Suffix}]"
        local MSG="${LEVEL} ${TIMESTAMP} ${MSG}"
        ;;
    DEBUG)
        local LEVEL="[${FontColor_Purple}${LEVEL}${FontColor_Suffix}]"
        local MSG="${LEVEL} ${TIMESTAMP} ${MSG}"
        ;;
    *) ;;
    esac
    echo -e "${MSG}"
    # Also log to file if log directory exists
    if [[ -d /var/log/shadowsocks-warp ]]; then
        echo -e "${MSG}" >> /var/log/shadowsocks-warp/install.log
    fi
}

# Pre-flight checks
if [[ $(uname -s) != Linux ]]; then
    log ERROR "This operating system is not supported."
    exit 1
fi

if [[ $(id -u) != 0 ]]; then
    log ERROR "This script must be run as root."
    exit 1
fi

if [[ -z $(command -v curl) ]]; then
    log ERROR "cURL is not installed."
    exit 1
fi

# Configuration variables
SHADOWSOCKS_PORT='8388'
SHADOWSOCKS_PASSWORD=''
SHADOWSOCKS_METHOD='aes-256-gcm'
SHADOWSOCKS_TIMEOUT='60'
SHADOWSOCKS_CONFIG_PATH='/etc/shadowsocks-libev/config.json'
SHADOWSOCKS_SERVICE_NAME='shadowsocks-libev'
FORCE_MODE='false'

# WireGuard configuration (adapted from warp.sh)
WGCF_Profile='wgcf-profile.conf'
WGCF_ProfileDir="/etc/warp"
WGCF_ProfilePath="${WGCF_ProfileDir}/${WGCF_Profile}"

WireGuard_Interface='wgcf'
WireGuard_ConfPath="/etc/wireguard/${WireGuard_Interface}.conf"

WireGuard_Interface_DNS_IPv4='8.8.8.8,8.8.4.4'
WireGuard_Interface_DNS_IPv6='2001:4860:4860::8888,2001:4860:4860::8844'
WireGuard_Interface_DNS_46="${WireGuard_Interface_DNS_IPv4},${WireGuard_Interface_DNS_IPv6}"
WireGuard_Interface_DNS_64="${WireGuard_Interface_DNS_IPv6},${WireGuard_Interface_DNS_IPv4}"
WireGuard_Interface_Rule_table='51888'
WireGuard_Interface_Rule_fwmark='51888'
WireGuard_Interface_MTU='1280'

WireGuard_Peer_Endpoint_IP4='162.159.192.1'
WireGuard_Peer_Endpoint_IP6='2606:4700:d0::a29f:c001'
WireGuard_Peer_Endpoint_IPv4="${WireGuard_Peer_Endpoint_IP4}:2408"
WireGuard_Peer_Endpoint_IPv6="[${WireGuard_Peer_Endpoint_IP6}]:2408"
WireGuard_Peer_Endpoint_Domain='engage.cloudflareclient.com:2408'
WireGuard_Peer_AllowedIPs_IPv4='0.0.0.0/0'
WireGuard_Peer_AllowedIPs_IPv6='::/0'
WireGuard_Peer_AllowedIPs_DualStack='0.0.0.0/0,::/0'

# Network test endpoints
TestIPv4_1='1.0.0.1'
TestIPv4_2='9.9.9.9'
TestIPv6_1='2606:4700:4700::1001'
TestIPv6_2='2620:fe::fe'
CF_Trace_URL='https://www.cloudflare.com/cdn-cgi/trace'

# System information gathering (adapted from warp.sh)
Get_System_Info() {
    log INFO "Gathering system information..."
    source /etc/os-release
    SysInfo_OS_CodeName="${VERSION_CODENAME}"
    SysInfo_OS_Name_lowercase="${ID}"
    SysInfo_OS_Name_Full="${PRETTY_NAME}"
    SysInfo_RelatedOS="${ID_LIKE}"
    SysInfo_Kernel="$(uname -r)"
    SysInfo_Kernel_Ver_major="$(uname -r | awk -F . '{print $1}')"
    SysInfo_Kernel_Ver_minor="$(uname -r | awk -F . '{print $2}')"
    SysInfo_Arch="$(uname -m)"
    SysInfo_Virt="$(systemd-detect-virt)"
    case ${SysInfo_RelatedOS} in
    *fedora* | *rhel*)
        SysInfo_OS_Ver_major="$(rpm -E '%{rhel}')"
        ;;
    *)
        SysInfo_OS_Ver_major="$(echo ${VERSION_ID} | cut -d. -f1)"
        ;;
    esac
    
    log INFO "System: ${SysInfo_OS_Name_Full} (${SysInfo_Arch})"
    log INFO "Kernel: ${SysInfo_Kernel}"
    log INFO "Virtualization: ${SysInfo_Virt}"
}

# Print system information
Print_System_Info() {
    echo -e "
System Information
---------------------------------------------------
  Operating System: ${SysInfo_OS_Name_Full}
      Linux Kernel: ${SysInfo_Kernel}
      Architecture: ${SysInfo_Arch}
    Virtualization: ${SysInfo_Virt}
---------------------------------------------------
"
}

# Network status checking (adapted from warp.sh)
Check_Network_Status_IPv4() {
    log DEBUG "Checking IPv4 connectivity..."
    if ping -c1 -W1 ${TestIPv4_1} >/dev/null 2>&1 || ping -c1 -W1 ${TestIPv4_2} >/dev/null 2>&1; then
        IPv4Status='on'
        log INFO "IPv4 connectivity: Available"
    else
        IPv4Status='off'
        log WARN "IPv4 connectivity: Not available"
    fi
}

Check_Network_Status_IPv6() {
    log DEBUG "Checking IPv6 connectivity..."
    if ping6 -c1 -W1 ${TestIPv6_1} >/dev/null 2>&1 || ping6 -c1 -W1 ${TestIPv6_2} >/dev/null 2>&1; then
        IPv6Status='on'
        log INFO "IPv6 connectivity: Available"
    else
        IPv6Status='off'
        log WARN "IPv6 connectivity: Not available"
    fi
}

Check_Network_Status() {
    log INFO "Checking network connectivity..."
    Check_Network_Status_IPv4
    Check_Network_Status_IPv6
    
    if [[ ${IPv4Status} = off && ${IPv6Status} = off ]]; then
        log WARN "No network connectivity detected. This may be due to restricted network access."
        if [[ ${FORCE_MODE} != "true" ]]; then
            log ERROR "Network connectivity is required. Use --force to bypass this check."
            exit 1
        else
            log WARN "Continuing in force mode..."
        fi
    fi
}

# Get network interface IP addresses
Check_IPv4_addr() {
    IPv4_addr=$(
        ip route get ${TestIPv4_1} 2>/dev/null | grep -oP 'src \K\S+' ||
            ip route get ${TestIPv4_2} 2>/dev/null | grep -oP 'src \K\S+'
    )
}

Check_IPv6_addr() {
    IPv6_addr=$(
        ip route get ${TestIPv6_1} 2>/dev/null | grep -oP 'src \K\S+' ||
            ip route get ${TestIPv6_2} 2>/dev/null | grep -oP 'src \K\S+'
    )
}

Get_IP_addr() {
    Check_Network_Status
    if [[ ${IPv4Status} = on ]]; then
        log INFO "Getting the network interface IPv4 address..."
        Check_IPv4_addr
        if [[ ${IPv4_addr} ]]; then
            log INFO "IPv4 Address: ${IPv4_addr}"
        else
            log WARN "Network interface IPv4 address not obtained."
        fi
    fi
    if [[ ${IPv6Status} = on ]]; then
        log INFO "Getting the network interface IPv6 address..."
        Check_IPv6_addr
        if [[ ${IPv6_addr} ]]; then
            log INFO "IPv6 Address: ${IPv6_addr}"
        else
            log WARN "Network interface IPv6 address not obtained."
        fi
    fi
}

# IPv6 support enablement
Enable_IPv6_Support() {
    log INFO "Enabling IPv6 support..."
    if [[ $(sysctl -a | grep 'disable_ipv6.*=.*1') || $(cat /etc/sysctl.{conf,d/*} 2>/dev/null | grep 'disable_ipv6.*=.*1') ]]; then
        sed -i '/disable_ipv6/d' /etc/sysctl.{conf,d/*} 2>/dev/null
        echo 'net.ipv6.conf.all.disable_ipv6 = 0' >/etc/sysctl.d/ipv6.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
        log INFO "IPv6 support enabled."
    else
        log INFO "IPv6 support already enabled."
    fi
}

# Create log directory
Create_Log_Directory() {
    if [[ ! -d /var/log/shadowsocks-warp ]]; then
        mkdir -p /var/log/shadowsocks-warp
        log INFO "Created log directory: /var/log/shadowsocks-warp"
    fi
}

# Generate random password for Shadowsocks
Generate_Shadowsocks_Password() {
    if [[ -z ${SHADOWSOCKS_PASSWORD} ]]; then
        SHADOWSOCKS_PASSWORD=$(openssl rand -base64 32)
        log INFO "Generated random Shadowsocks password."
    fi
}

# Shadowsocks installation functions
Install_Shadowsocks_Debian() {
    log INFO "Installing Shadowsocks on Debian/Ubuntu..."
    apt update
    apt install -y shadowsocks-libev
    
    # Create configuration directory
    mkdir -p /etc/shadowsocks-libev
}

Install_Shadowsocks_CentOS() {
    log INFO "Installing Shadowsocks on CentOS/RHEL..."
    
    # Install EPEL repository
    yum install -y epel-release
    
    # Install shadowsocks-libev
    yum install -y shadowsocks-libev
    
    # Create configuration directory
    mkdir -p /etc/shadowsocks-libev
}

Install_Shadowsocks_Fedora() {
    log INFO "Installing Shadowsocks on Fedora..."
    dnf install -y shadowsocks-libev
    
    # Create configuration directory
    mkdir -p /etc/shadowsocks-libev
}

Install_Shadowsocks_Arch() {
    log INFO "Installing Shadowsocks on Arch Linux..."
    pacman -Sy shadowsocks-libev --noconfirm
    
    # Create configuration directory
    mkdir -p /etc/shadowsocks-libev
}

Install_Shadowsocks() {
    log INFO "Installing Shadowsocks server..."
    case ${SysInfo_OS_Name_lowercase} in
    *debian* | *ubuntu*)
        Install_Shadowsocks_Debian
        ;;
    *centos* | *rhel*)
        Install_Shadowsocks_CentOS
        ;;
    *fedora*)
        Install_Shadowsocks_Fedora
        ;;
    *arch*)
        Install_Shadowsocks_Arch
        ;;
    *)
        if [[ ${SysInfo_RelatedOS} = *rhel* || ${SysInfo_RelatedOS} = *fedora* ]]; then
            Install_Shadowsocks_CentOS
        else
            log ERROR "This operating system is not supported."
            exit 1
        fi
        ;;
    esac
    
    log INFO "Shadowsocks installation completed."
}

# Generate Shadowsocks configuration
Generate_Shadowsocks_Config() {
    log INFO "Generating Shadowsocks configuration..."
    
    # Create configuration file
    cat > ${SHADOWSOCKS_CONFIG_PATH} << EOF
{
    "server": "0.0.0.0",
    "server_port": ${SHADOWSOCKS_PORT},
    "password": "${SHADOWSOCKS_PASSWORD}",
    "timeout": ${SHADOWSOCKS_TIMEOUT},
    "method": "${SHADOWSOCKS_METHOD}",
    "fast_open": false,
    "workers": 1,
    "prefer_ipv6": false
}
EOF
    
    log INFO "Shadowsocks configuration generated at ${SHADOWSOCKS_CONFIG_PATH}"
}

# Service management functions
Check_Shadowsocks_Service() {
    Shadowsocks_Status=$(systemctl is-active ${SHADOWSOCKS_SERVICE_NAME})
    Shadowsocks_SelfStart=$(systemctl is-enabled ${SHADOWSOCKS_SERVICE_NAME} 2>/dev/null)
}

Start_Shadowsocks_Service() {
    log INFO "Starting Shadowsocks service..."
    systemctl enable ${SHADOWSOCKS_SERVICE_NAME}
    systemctl start ${SHADOWSOCKS_SERVICE_NAME}
    
    Check_Shadowsocks_Service
    if [[ ${Shadowsocks_Status} = active ]]; then
        log INFO "Shadowsocks service started successfully."
    else
        log ERROR "Failed to start Shadowsocks service."
        journalctl -u ${SHADOWSOCKS_SERVICE_NAME} --no-pager -n 20
        exit 1
    fi
}

Stop_Shadowsocks_Service() {
    log INFO "Stopping Shadowsocks service..."
    systemctl stop ${SHADOWSOCKS_SERVICE_NAME}
    systemctl disable ${SHADOWSOCKS_SERVICE_NAME}
    
    Check_Shadowsocks_Service
    if [[ ${Shadowsocks_Status} != active ]]; then
        log INFO "Shadowsocks service stopped."
    else
        log ERROR "Failed to stop Shadowsocks service."
    fi
}

Restart_Shadowsocks_Service() {
    log INFO "Restarting Shadowsocks service..."
    systemctl restart ${SHADOWSOCKS_SERVICE_NAME}
    
    Check_Shadowsocks_Service
    if [[ ${Shadowsocks_Status} = active ]]; then
        log INFO "Shadowsocks service restarted successfully."
    else
        log ERROR "Failed to restart Shadowsocks service."
        journalctl -u ${SHADOWSOCKS_SERVICE_NAME} --no-pager -n 20
        exit 1
    fi
}

# Firewall configuration functions
Check_Firewall_Status() {
    log INFO "Checking firewall status..."
    
    # Check if iptables is available
    if ! command -v iptables >/dev/null 2>&1; then
        log ERROR "iptables is not installed."
        exit 1
    fi
    
    # Check if firewalld is running
    if systemctl is-active firewalld >/dev/null 2>&1; then
        log INFO "firewalld is running."
        Firewall_Type="firewalld"
    # Check if ufw is active
    elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        log INFO "ufw is active."
        Firewall_Type="ufw"
    else
        log INFO "Using iptables directly."
        Firewall_Type="iptables"
    fi
}

Configure_Firewall_Rules() {
    log INFO "Configuring firewall rules..."
    Check_Firewall_Status
    
    case ${Firewall_Type} in
    "firewalld")
        Configure_Firewalld_Rules
        ;;
    "ufw")
        Configure_UFW_Rules
        ;;
    "iptables")
        Configure_Iptables_Rules
        ;;
    esac
    
    log INFO "Firewall rules configured successfully."
}

Configure_Firewalld_Rules() {
    log INFO "Configuring firewalld rules..."
    
    # Open Shadowsocks port
    firewall-cmd --permanent --add-port=${SHADOWSOCKS_PORT}/tcp
    firewall-cmd --permanent --add-port=${SHADOWSOCKS_PORT}/udp
    
    # Allow WireGuard traffic
    firewall-cmd --permanent --add-port=2408/udp
    
    # Enable IP forwarding
    firewall-cmd --permanent --add-masquerade
    
    # Reload firewalld
    firewall-cmd --reload
    
    log INFO "firewalld rules configured."
}

Configure_UFW_Rules() {
    log INFO "Configuring ufw rules..."
    
    # Open Shadowsocks port
    ufw allow ${SHADOWSOCKS_PORT}/tcp
    ufw allow ${SHADOWSOCKS_PORT}/udp
    
    # Allow WireGuard traffic
    ufw allow 2408/udp
    
    # Enable IP forwarding
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
    
    log INFO "ufw rules configured."
}

Configure_Iptables_Rules() {
    log INFO "Configuring iptables rules..."
    
    # Save current rules
    iptables-save > /tmp/iptables_backup.rules
    
    # Allow Shadowsocks traffic
    iptables -A INPUT -p tcp --dport ${SHADOWSOCKS_PORT} -j ACCEPT
    iptables -A INPUT -p udp --dport ${SHADOWSOCKS_PORT} -j ACCEPT
    
    # Allow WireGuard traffic
    iptables -A INPUT -p udp --dport 2408 -j ACCEPT
    
    # Allow established and related connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Enable IP forwarding
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
    sysctl -p
    
    # NAT rules for WireGuard
    if [[ ${IPv4Status} = on ]]; then
        iptables -t nat -A POSTROUTING -s 10.2.0.0/16 -o $(ip route | grep default | head -1 | awk '{print $5}') -j MASQUERADE
    fi
    
    # IPv6 rules if available
    if [[ ${IPv6Status} = on ]] && command -v ip6tables >/dev/null 2>&1; then
        ip6tables -A INPUT -p tcp --dport ${SHADOWSOCKS_PORT} -j ACCEPT
        ip6tables -A INPUT -p udp --dport ${SHADOWSOCKS_PORT} -j ACCEPT
        ip6tables -A INPUT -p udp --dport 2408 -j ACCEPT
        ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    fi
    
    # Save iptables rules
    case ${SysInfo_OS_Name_lowercase} in
    *debian* | *ubuntu*)
        iptables-save > /etc/iptables/rules.v4
        if [[ ${IPv6Status} = on ]]; then
            ip6tables-save > /etc/iptables/rules.v6
        fi
        ;;
    *centos* | *rhel* | *fedora*)
        service iptables save 2>/dev/null || iptables-save > /etc/sysconfig/iptables
        if [[ ${IPv6Status} = on ]]; then
            service ip6tables save 2>/dev/null || ip6tables-save > /etc/sysconfig/ip6tables
        fi
        ;;
    esac
    
    log INFO "iptables rules configured."
}

# Remove firewall rules
Remove_Firewall_Rules() {
    log INFO "Removing firewall rules..."
    Check_Firewall_Status
    
    case ${Firewall_Type} in
    "firewalld")
        firewall-cmd --permanent --remove-port=${SHADOWSOCKS_PORT}/tcp
        firewall-cmd --permanent --remove-port=${SHADOWSOCKS_PORT}/udp
        firewall-cmd --permanent --remove-port=2408/udp
        firewall-cmd --reload
        ;;
    "ufw")
        ufw delete allow ${SHADOWSOCKS_PORT}/tcp
        ufw delete allow ${SHADOWSOCKS_PORT}/udp
        ufw delete allow 2408/udp
        ;;
    "iptables")
        iptables -D INPUT -p tcp --dport ${SHADOWSOCKS_PORT} -j ACCEPT 2>/dev/null
        iptables -D INPUT -p udp --dport ${SHADOWSOCKS_PORT} -j ACCEPT 2>/dev/null
        iptables -D INPUT -p udp --dport 2408 -j ACCEPT 2>/dev/null
        
        if [[ ${IPv6Status} = on ]] && command -v ip6tables >/dev/null 2>&1; then
            ip6tables -D INPUT -p tcp --dport ${SHADOWSOCKS_PORT} -j ACCEPT 2>/dev/null
            ip6tables -D INPUT -p udp --dport ${SHADOWSOCKS_PORT} -j ACCEPT 2>/dev/null
            ip6tables -D INPUT -p udp --dport 2408 -j ACCEPT 2>/dev/null
        fi
        ;;
    esac
    
    log INFO "Firewall rules removed."
}

# WireGuard functions (adapted from warp.sh)
Install_WireGuardTools_Debian() {
    case ${SysInfo_OS_Ver_major} in
    10)
        if [[ -z $(grep "^deb.*buster-backports.*main" /etc/apt/sources.list{,.d/*}) ]]; then
            echo "deb http://deb.debian.org/debian buster-backports main" | tee /etc/apt/sources.list.d/backports.list
        fi
        ;;
    *)
        if [[ ${SysInfo_OS_Ver_major} -lt 10 ]]; then
            log ERROR "This operating system is not supported."
            exit 1
        fi
        ;;
    esac
    apt update
    apt install -y iproute2 openresolv
    apt install -y wireguard-tools --no-install-recommends
}

Install_WireGuardTools_Ubuntu() {
    apt update
    apt install -y iproute2 openresolv
    apt install -y wireguard-tools --no-install-recommends
}

Install_WireGuardTools_CentOS() {
    yum install -y epel-release || yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${SysInfo_OS_Ver_major}.noarch.rpm
    yum install -y iproute iptables wireguard-tools
}

Install_WireGuardTools_Fedora() {
    dnf install -y iproute iptables wireguard-tools
}

Install_WireGuardTools_Arch() {
    pacman -Sy iproute2 openresolv wireguard-tools --noconfirm
}

Install_WireGuardTools() {
    log INFO "Installing WireGuard tools..."
    case ${SysInfo_OS_Name_lowercase} in
    *debian*)
        Install_WireGuardTools_Debian
        ;;
    *ubuntu*)
        Install_WireGuardTools_Ubuntu
        ;;
    *centos* | *rhel*)
        Install_WireGuardTools_CentOS
        ;;
    *fedora*)
        Install_WireGuardTools_Fedora
        ;;
    *arch*)
        Install_WireGuardTools_Arch
        ;;
    *)
        if [[ ${SysInfo_RelatedOS} = *rhel* || ${SysInfo_RelatedOS} = *fedora* ]]; then
            Install_WireGuardTools_CentOS
        else
            log ERROR "This operating system is not supported."
            exit 1
        fi
        ;;
    esac
    log INFO "WireGuard tools installed successfully."
}

Install_WireGuardGo() {
    case ${SysInfo_Virt} in
    openvz | lxc*)
        log INFO "Installing WireGuard-Go for virtualized environment..."
        curl -fsSL git.io/wireguard-go.sh | bash
        ;;
    *)
        if [[ ${SysInfo_Kernel_Ver_major} -lt 5 || ${SysInfo_Kernel_Ver_minor} -lt 6 ]]; then
            log INFO "Installing WireGuard-Go for older kernel..."
            curl -fsSL git.io/wireguard-go.sh | bash
        fi
        ;;
    esac
}

Check_WireGuard_Service() {
    WireGuard_Status=$(systemctl is-active wg-quick@${WireGuard_Interface})
    WireGuard_SelfStart=$(systemctl is-enabled wg-quick@${WireGuard_Interface} 2>/dev/null)
}

Install_WireGuard() {
    log INFO "Installing WireGuard..."
    Check_WireGuard_Service
    if [[ ${WireGuard_SelfStart} != enabled || ${WireGuard_Status} != active ]]; then
        Install_WireGuardTools
        Install_WireGuardGo
    else
        log INFO "WireGuard is already installed and running."
    fi
}

# WGCF (WireGuard CloudFlare) functions
Install_wgcf() {
    log INFO "Installing wgcf..."
    curl -fsSL git.io/wgcf.sh | bash
}

Uninstall_wgcf() {
    rm -f /usr/local/bin/wgcf
}

Register_WARP_Account() {
    log INFO "Registering WARP account..."
    while [[ ! -f wgcf-account.toml ]]; do
        Install_wgcf
        log INFO "Cloudflare WARP Account registration in progress..."
        yes | wgcf register
        sleep 5
    done
}

Generate_WGCF_Profile() {
    log INFO "Generating WGCF profile..."
    while [[ ! -f ${WGCF_Profile} ]]; do
        Register_WARP_Account
        log INFO "WARP WireGuard profile generation in progress..."
        wgcf generate
    done
    Uninstall_wgcf
}

Backup_WGCF_Profile() {
    mkdir -p ${WGCF_ProfileDir}
    mv -f wgcf* ${WGCF_ProfileDir}
}

Read_WGCF_Profile() {
    WireGuard_Interface_PrivateKey=$(cat ${WGCF_ProfilePath} | grep ^PrivateKey | cut -d= -f2- | awk '$1=$1')
    WireGuard_Interface_Address=$(cat ${WGCF_ProfilePath} | grep ^Address | cut -d= -f2- | awk '$1=$1' | sed ":a;N;s/\n/,/g;ta")
    WireGuard_Peer_PublicKey=$(cat ${WGCF_ProfilePath} | grep ^PublicKey | cut -d= -f2- | awk '$1=$1')
    WireGuard_Interface_Address_IPv4=$(echo ${WireGuard_Interface_Address} | cut -d, -f1 | cut -d'/' -f1)
    WireGuard_Interface_Address_IPv6=$(echo ${WireGuard_Interface_Address} | cut -d, -f2 | cut -d'/' -f1)
}

Load_WGCF_Profile() {
    if [[ -f ${WGCF_Profile} ]]; then
        Backup_WGCF_Profile
        Read_WGCF_Profile
    elif [[ -f ${WGCF_ProfilePath} ]]; then
        Read_WGCF_Profile
    else
        Generate_WGCF_Profile
        Backup_WGCF_Profile
        Read_WGCF_Profile
    fi
}

# MTU detection (adapted from warp.sh)
Get_WireGuard_Interface_MTU() {
    log INFO "Getting the best MTU value for WireGuard..."
    MTU_Preset=1500
    MTU_Increment=10
    if [[ ${IPv4Status} = off && ${IPv6Status} = on ]]; then
        CMD_ping='ping6'
        MTU_TestIP_1="${TestIPv6_1}"
        MTU_TestIP_2="${TestIPv6_2}"
    else
        CMD_ping='ping'
        MTU_TestIP_1="${TestIPv4_1}"
        MTU_TestIP_2="${TestIPv4_2}"
    fi
    while true; do
        if ${CMD_ping} -c1 -W1 -s$((${MTU_Preset} - 28)) -Mdo ${MTU_TestIP_1} >/dev/null 2>&1 || ${CMD_ping} -c1 -W1 -s$((${MTU_Preset} - 28)) -Mdo ${MTU_TestIP_2} >/dev/null 2>&1; then
            MTU_Increment=1
            MTU_Preset=$((${MTU_Preset} + ${MTU_Increment}))
        else
            MTU_Preset=$((${MTU_Preset} - ${MTU_Increment}))
            if [[ ${MTU_Increment} = 1 ]]; then
                break
            fi
        fi
        if [[ ${MTU_Preset} -le 1360 ]]; then
            log WARN "MTU is set to the lowest value."
            MTU_Preset='1360'
            break
        fi
    done
    WireGuard_Interface_MTU=$((${MTU_Preset} - 80))
    log INFO "WireGuard MTU: ${WireGuard_Interface_MTU}"
}

# WireGuard endpoint detection
Check_WireGuard_Peer_Endpoint() {
    log INFO "Checking WireGuard peer endpoint..."
    if ping -c1 -W1 ${WireGuard_Peer_Endpoint_IP4} >/dev/null 2>&1; then
        WireGuard_Peer_Endpoint="${WireGuard_Peer_Endpoint_IPv4}"
        log INFO "Using IPv4 endpoint: ${WireGuard_Peer_Endpoint}"
    elif ping6 -c1 -W1 ${WireGuard_Peer_Endpoint_IP6} >/dev/null 2>&1; then
        WireGuard_Peer_Endpoint="${WireGuard_Peer_Endpoint_IPv6}"
        log INFO "Using IPv6 endpoint: ${WireGuard_Peer_Endpoint}"
    else
        WireGuard_Peer_Endpoint="${WireGuard_Peer_Endpoint_Domain}"
        log INFO "Using domain endpoint: ${WireGuard_Peer_Endpoint}"
    fi
}

# WireGuard configuration generation
Generate_WireGuardProfile_Interface() {
    Get_WireGuard_Interface_MTU
    log INFO "Generating WireGuard interface configuration..."
    cat <<EOF >${WireGuard_ConfPath}
# Generated by Shadowsocks + WireGuard Dual-Stack Script
# Enhanced configuration with Shadowsocks integration

[Interface]
PrivateKey = ${WireGuard_Interface_PrivateKey}
Address = ${WireGuard_Interface_Address}
DNS = ${WireGuard_Interface_DNS}
MTU = ${WireGuard_Interface_MTU}
EOF
}

Generate_WireGuardProfile_Interface_Rule_TableOff() {
    cat <<EOF >>${WireGuard_ConfPath}
Table = off
EOF
}

Generate_WireGuardProfile_Interface_Rule_IPv4_nonGlobal() {
    cat <<EOF >>${WireGuard_ConfPath}
PostUp = ip -4 route add default dev ${WireGuard_Interface} table ${WireGuard_Interface_Rule_table}
PostUp = ip -4 rule add from ${WireGuard_Interface_Address_IPv4} lookup ${WireGuard_Interface_Rule_table}
PostDown = ip -4 rule delete from ${WireGuard_Interface_Address_IPv4} lookup ${WireGuard_Interface_Rule_table}
PostUp = ip -4 rule add fwmark ${WireGuard_Interface_Rule_fwmark} lookup ${WireGuard_Interface_Rule_table}
PostDown = ip -4 rule delete fwmark ${WireGuard_Interface_Rule_fwmark} lookup ${WireGuard_Interface_Rule_table}
PostUp = ip -4 rule add table main suppress_prefixlength 0
PostDown = ip -4 rule delete table main suppress_prefixlength 0
EOF
}

Generate_WireGuardProfile_Interface_Rule_IPv6_nonGlobal() {
    cat <<EOF >>${WireGuard_ConfPath}
PostUp = ip -6 route add default dev ${WireGuard_Interface} table ${WireGuard_Interface_Rule_table}
PostUp = ip -6 rule add from ${WireGuard_Interface_Address_IPv6} lookup ${WireGuard_Interface_Rule_table}
PostDown = ip -6 rule delete from ${WireGuard_Interface_Address_IPv6} lookup ${WireGuard_Interface_Rule_table}
PostUp = ip -6 rule add fwmark ${WireGuard_Interface_Rule_fwmark} lookup ${WireGuard_Interface_Rule_table}
PostDown = ip -6 rule delete fwmark ${WireGuard_Interface_Rule_fwmark} lookup ${WireGuard_Interface_Rule_table}
PostUp = ip -6 rule add table main suppress_prefixlength 0
PostDown = ip -6 rule delete table main suppress_prefixlength 0
EOF
}

Generate_WireGuardProfile_Interface_Rule_DualStack_nonGlobal() {
    Generate_WireGuardProfile_Interface_Rule_TableOff
    Generate_WireGuardProfile_Interface_Rule_IPv4_nonGlobal
    Generate_WireGuardProfile_Interface_Rule_IPv6_nonGlobal
}

Generate_WireGuardProfile_Interface_Rule_IPv4_Global_srcIP() {
    cat <<EOF >>${WireGuard_ConfPath}
PostUp = ip -4 rule add from ${IPv4_addr} lookup main prio 18
PostDown = ip -4 rule delete from ${IPv4_addr} lookup main prio 18
EOF
}

Generate_WireGuardProfile_Interface_Rule_IPv6_Global_srcIP() {
    cat <<EOF >>${WireGuard_ConfPath}
PostUp = ip -6 rule add from ${IPv6_addr} lookup main prio 18
PostDown = ip -6 rule delete from ${IPv6_addr} lookup main prio 18
EOF
}

Generate_WireGuardProfile_Peer() {
    cat <<EOF >>${WireGuard_ConfPath}

[Peer]
PublicKey = ${WireGuard_Peer_PublicKey}
AllowedIPs = ${WireGuard_Peer_AllowedIPs}
Endpoint = ${WireGuard_Peer_Endpoint}
EOF
}

# WireGuard service management
Start_WireGuard_Service() {
    log INFO "Starting WireGuard service..."
    systemctl enable wg-quick@${WireGuard_Interface} --now
    Check_WireGuard_Service
    if [[ ${WireGuard_Status} = active ]]; then
        log INFO "WireGuard service started successfully."
    else
        log ERROR "Failed to start WireGuard service."
        journalctl -u wg-quick@${WireGuard_Interface} --no-pager -n 20
        exit 1
    fi
}

Stop_WireGuard_Service() {
    log INFO "Stopping WireGuard service..."
    systemctl disable wg-quick@${WireGuard_Interface} --now
    Check_WireGuard_Service
    if [[ ${WireGuard_Status} != active ]]; then
        log INFO "WireGuard service stopped."
    else
        log ERROR "Failed to stop WireGuard service."
    fi
}

Restart_WireGuard_Service() {
    log INFO "Restarting WireGuard service..."
    systemctl restart wg-quick@${WireGuard_Interface}
    Check_WireGuard_Service
    if [[ ${WireGuard_Status} = active ]]; then
        log INFO "WireGuard service restarted successfully."
    else
        log ERROR "Failed to restart WireGuard service."
        journalctl -u wg-quick@${WireGuard_Interface} --no-pager -n 20
        exit 1
    fi
}

# Dual-stack configuration functions
Configure_Shadowsocks_WireGuard_DualStack() {
    log INFO "Configuring Shadowsocks + WireGuard dual-stack..."
    
    # Install and configure Shadowsocks
    Install_Shadowsocks
    Generate_Shadowsocks_Config
    
    # Install and configure WireGuard
    Install_WireGuard
    Load_WGCF_Profile
    
    # Set DNS based on network availability
    if [[ ${IPv4Status} = off && ${IPv6Status} = on ]]; then
        WireGuard_Interface_DNS="${WireGuard_Interface_DNS_64}"
    else
        WireGuard_Interface_DNS="${WireGuard_Interface_DNS_46}"
    fi
    
    # Configure for dual-stack
    WireGuard_Peer_AllowedIPs="${WireGuard_Peer_AllowedIPs_DualStack}"
    Check_WireGuard_Peer_Endpoint
    
    # Generate WireGuard configuration
    Generate_WireGuardProfile_Interface
    Generate_WireGuardProfile_Interface_Rule_DualStack_nonGlobal
    Generate_WireGuardProfile_Peer
    
    # Configure firewall rules
    Configure_Firewall_Rules
    
    # Start services
    Start_Shadowsocks_Service
    Start_WireGuard_Service
    
    log INFO "Shadowsocks + WireGuard dual-stack configuration completed."
}

# Diagnostic and troubleshooting functions
Test_Shadowsocks_Connection() {
    log INFO "Testing Shadowsocks connection..."
    
    # Check if Shadowsocks is listening on the correct port
    if netstat -tlnp | grep -q ":${SHADOWSOCKS_PORT}"; then
        log INFO "Shadowsocks is listening on port ${SHADOWSOCKS_PORT}."
    else
        log ERROR "Shadowsocks is not listening on port ${SHADOWSOCKS_PORT}."
        return 1
    fi
    
    # Test local connection
    if timeout 5 nc -z 127.0.0.1 ${SHADOWSOCKS_PORT}; then
        log INFO "Local Shadowsocks connection test passed."
    else
        log ERROR "Local Shadowsocks connection test failed."
        return 1
    fi
    
    # Test external connection if possible
    if [[ ${IPv4_addr} ]]; then
        if timeout 5 nc -z ${IPv4_addr} ${SHADOWSOCKS_PORT}; then
            log INFO "External Shadowsocks connection test passed."
        else
            log WARN "External Shadowsocks connection test failed. Check firewall rules."
        fi
    fi
    
    log INFO "Shadowsocks connection test completed."
}

Test_WireGuard_Connection() {
    log INFO "Testing WireGuard connection..."
    
    # Check if WireGuard interface is up
    if ip link show ${WireGuard_Interface} >/dev/null 2>&1; then
        log INFO "WireGuard interface ${WireGuard_Interface} is up."
    else
        log ERROR "WireGuard interface ${WireGuard_Interface} is not up."
        return 1
    fi
    
    # Check WireGuard status
    if wg show ${WireGuard_Interface} >/dev/null 2>&1; then
        log INFO "WireGuard interface status:"
        wg show ${WireGuard_Interface}
    else
        log ERROR "Cannot get WireGuard interface status."
        return 1
    fi
    
    # Test connectivity through WireGuard
    if ping -c1 -W5 -I ${WireGuard_Interface} ${TestIPv4_1} >/dev/null 2>&1; then
        log INFO "WireGuard IPv4 connectivity test passed."
    else
        log WARN "WireGuard IPv4 connectivity test failed."
    fi
    
    if [[ ${IPv6Status} = on ]]; then
        if ping6 -c1 -W5 -I ${WireGuard_Interface} ${TestIPv6_1} >/dev/null 2>&1; then
            log INFO "WireGuard IPv6 connectivity test passed."
        else
            log WARN "WireGuard IPv6 connectivity test failed."
        fi
    fi
    
    log INFO "WireGuard connection test completed."
}

Check_Service_Status() {
    log INFO "Checking service status..."
    
    # Check Shadowsocks service
    Check_Shadowsocks_Service
    case ${Shadowsocks_Status} in
    active)
        log INFO "Shadowsocks service: ${FontColor_Green}Running${FontColor_Suffix}"
        ;;
    *)
        log WARN "Shadowsocks service: ${FontColor_Red}Stopped${FontColor_Suffix}"
        ;;
    esac
    
    # Check WireGuard service
    Check_WireGuard_Service
    case ${WireGuard_Status} in
    active)
        log INFO "WireGuard service: ${FontColor_Green}Running${FontColor_Suffix}"
        ;;
    *)
        log WARN "WireGuard service: ${FontColor_Red}Stopped${FontColor_Suffix}"
        ;;
    esac
}

Print_Connection_Info() {
    log INFO "Connection Information:"
    echo "============================================="
    echo "Shadowsocks Server Configuration:"
    echo "  Server: ${IPv4_addr:-[Your Server IP]}"
    echo "  Port: ${SHADOWSOCKS_PORT}"
    echo "  Password: ${SHADOWSOCKS_PASSWORD}"
    echo "  Method: ${SHADOWSOCKS_METHOD}"
    echo "  Timeout: ${SHADOWSOCKS_TIMEOUT}"
    echo "============================================="
    echo "WireGuard Configuration:"
    echo "  Interface: ${WireGuard_Interface}"
    echo "  Address: ${WireGuard_Interface_Address}"
    echo "  MTU: ${WireGuard_Interface_MTU}"
    echo "  Endpoint: ${WireGuard_Peer_Endpoint}"
    echo "============================================="
    
    # Save connection info to file
    cat > /var/log/shadowsocks-warp/connection_info.txt << EOF
Shadowsocks + WireGuard Dual-Stack Configuration
Generated on: $(date)

Shadowsocks Server Configuration:
  Server: ${IPv4_addr:-[Your Server IP]}
  Port: ${SHADOWSOCKS_PORT}
  Password: ${SHADOWSOCKS_PASSWORD}
  Method: ${SHADOWSOCKS_METHOD}
  Timeout: ${SHADOWSOCKS_TIMEOUT}

WireGuard Configuration:
  Interface: ${WireGuard_Interface}
  Address: ${WireGuard_Interface_Address}
  MTU: ${WireGuard_Interface_MTU}
  Endpoint: ${WireGuard_Peer_Endpoint}

Configuration Files:
  Shadowsocks: ${SHADOWSOCKS_CONFIG_PATH}
  WireGuard: ${WireGuard_ConfPath}
  WGCF Profile: ${WGCF_ProfilePath}
EOF
    
    log INFO "Connection information saved to /var/log/shadowsocks-warp/connection_info.txt"
}

# Full diagnostic function
Run_Diagnostics() {
    log INFO "Running comprehensive diagnostics..."
    
    Print_System_Info
    Check_Network_Status
    Check_Service_Status
    Test_Shadowsocks_Connection
    Test_WireGuard_Connection
    Print_Connection_Info
    
    log INFO "Diagnostics completed."
}

# Cleanup function
Cleanup_Installation() {
    log INFO "Cleaning up installation..."
    
    # Stop services
    Stop_Shadowsocks_Service
    Stop_WireGuard_Service
    
    # Remove firewall rules
    Remove_Firewall_Rules
    
    # Remove configuration files
    rm -f ${SHADOWSOCKS_CONFIG_PATH}
    rm -f ${WireGuard_ConfPath}
    rm -rf ${WGCF_ProfileDir}
    
    log INFO "Cleanup completed."
}

# Menu functions
Print_Menu() {
    echo -e "
${FontColor_Yellow_Bold}Shadowsocks + WireGuard Dual-Stack Script${FontColor_Suffix} ${FontColor_Red}[${shVersion}]${FontColor_Suffix}

${FontColor_Green_Bold}1${FontColor_Suffix}. Install and configure Shadowsocks + WireGuard dual-stack
${FontColor_Green_Bold}2${FontColor_Suffix}. Check service status
${FontColor_Green_Bold}3${FontColor_Suffix}. Run connection tests
${FontColor_Green_Bold}4${FontColor_Suffix}. Run full diagnostics
${FontColor_Green_Bold}5${FontColor_Suffix}. Restart services
${FontColor_Green_Bold}6${FontColor_Suffix}. View connection information
${FontColor_Green_Bold}7${FontColor_Suffix}. Configure firewall rules
${FontColor_Green_Bold}8${FontColor_Suffix}. Cleanup installation
${FontColor_Green_Bold}9${FontColor_Suffix}. Exit
"
}

# Main menu function
Main_Menu() {
    while true; do
        clear
        Print_Menu
        read -p "Please select an option: " choice
        echo
        
        case $choice in
        1)
            Configure_Shadowsocks_WireGuard_DualStack
            ;;
        2)
            Check_Service_Status
            ;;
        3)
            Test_Shadowsocks_Connection
            Test_WireGuard_Connection
            ;;
        4)
            Run_Diagnostics
            ;;
        5)
            Restart_Shadowsocks_Service
            Restart_WireGuard_Service
            ;;
        6)
            Print_Connection_Info
            ;;
        7)
            Configure_Firewall_Rules
            ;;
        8)
            Cleanup_Installation
            ;;
        9)
            log INFO "Exiting..."
            exit 0
            ;;
        *)
            log ERROR "Invalid option. Please try again."
            ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Command line argument handling
Print_Usage() {
    echo -e "
Shadowsocks + WireGuard Dual-Stack Script [${shVersion}]

USAGE:
    bash shadowsocks-warp.sh [COMMAND]

COMMANDS:
    install         Install and configure Shadowsocks + WireGuard dual-stack
    status          Check service status
    test            Run connection tests
    diagnostics     Run full diagnostics
    restart         Restart services
    info            View connection information
    firewall        Configure firewall rules
    cleanup         Cleanup installation
    menu            Show interactive menu
    help            Show this help message

OPTIONS:
    --force         Force execution even without network connectivity
    --port PORT     Set custom Shadowsocks port (default: 8388)
    --password PASS Set custom Shadowsocks password
    --method METHOD Set custom encryption method (default: aes-256-gcm)
"
}

# Main initialization function
Initialize() {
    log INFO "Starting Shadowsocks + WireGuard dual-stack automation script..."
    Create_Log_Directory
    Get_System_Info
    Enable_IPv6_Support
    Get_IP_addr
    Generate_Shadowsocks_Password
}

# Command line argument processing
if [ $# -ge 1 ]; then
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        --force)
            FORCE_MODE='true'
            shift
            ;;
        --port)
            SHADOWSOCKS_PORT="$2"
            shift 2
            ;;
        --password)
            SHADOWSOCKS_PASSWORD="$2"
            shift 2
            ;;
        --method)
            SHADOWSOCKS_METHOD="$2"
            shift 2
            ;;
        install|status|test|diagnostics|restart|info|firewall|cleanup|menu|help)
            COMMAND="$1"
            shift
            ;;
        *)
            log ERROR "Unknown argument: $1"
            Print_Usage
            exit 1
            ;;
        esac
    done
    
    # Initialize with parsed arguments
    Initialize
    
    # Execute command
    case ${COMMAND} in
    install)
        Configure_Shadowsocks_WireGuard_DualStack
        ;;
    status)
        Check_Service_Status
        ;;
    test)
        Test_Shadowsocks_Connection
        Test_WireGuard_Connection
        ;;
    diagnostics)
        Run_Diagnostics
        ;;
    restart)
        Restart_Shadowsocks_Service
        Restart_WireGuard_Service
        ;;
    info)
        Print_Connection_Info
        ;;
    firewall)
        Configure_Firewall_Rules
        ;;
    cleanup)
        Cleanup_Installation
        ;;
    menu)
        Main_Menu
        ;;
    help)
        Print_Usage
        ;;
    *)
        log ERROR "No valid command provided"
        Print_Usage
        exit 1
        ;;
    esac
else
    # If no arguments provided, show interactive menu
    Initialize
    Main_Menu
fi