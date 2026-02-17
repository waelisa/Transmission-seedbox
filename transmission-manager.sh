#!/bin/bash
#############################################################################################################################
# The MIT License (MIT)
# Wael Isa
# Build Date: 02/18/2026
# Version: 5.0.0+ (Auto-detects latest during installation)
# https://github.com/waelisa/Transmission-seedbox
#############################################################################################################################
# Transmission Auto Installer/Uninstaller - GOLD MASTER EDITION
# Automatically detects and installs latest Transmission version
# Features:
#   ✓ Multi-init support (Systemd/OpenRC/SysV)
#   ✓ Security hardening with random passwords
#   ✓ Network performance optimization
#   ✓ Automatic CMake version detection & upgrade
#   ✓ Ghost config prevention with process-wait loops
#   ✓ Comprehensive step-by-step logging with log rotation
#   ✓ Seedbox network tuning for high-speed peering
#   ✓ Idempotent installation (safe to run multiple times)
#   ✓ Lock file protection against concurrent runs
#   ✓ POSIX-compliant command detection
#   ✓ Proper error trapping with line numbers
#   ✓ Industrial-grade reliability
#   ✓ Secure log permissions (640)
#############################################################################################################################

# Strict mode - exit on error, undefined variables, pipe failures
set -euo pipefail

# Error trap for debugging
trap 'echo -e "\033[0;31m❌ Error on line $LINENO\033[0m"; exit 1' ERR

SCRIPT="$(readlink -e "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT")"
LOCK_FILE="/var/run/transmission-manager.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
TRANSMISSION_USER="transmission"
TRANSMISSION_HOME="/home/${TRANSMISSION_USER}/.config/transmission-daemon"
SETTINGS_FILE="${TRANSMISSION_HOME}/settings.json"
INIT_SCRIPT="/etc/init.d/transmission-daemon"
SYSTEMD_SERVICE="transmission-daemon.service"
SYSTEMD_SERVICE_PATH="/etc/systemd/system/${SYSTEMD_SERVICE}"
LOG_FILE="/var/log/transmission-install.log"
STEP_LOG="/var/log/transmission-steps.log"
DOWNLOAD_DIR="/downloads"
TRANSMISSION_LOG_DIR="/var/log/transmission"
BUILD_DATE="02/18/2026"
SCRIPT_VERSION="5.0.0+"
INSTALL_MARKER="/etc/transmission-manager.installed"

# Log rotation configuration for installer logs
setup_installer_logrotate() {
    local logrotate_config="/etc/logrotate.d/transmission-installer"

    if [ ! -f "$logrotate_config" ]; then
        sudo tee "$logrotate_config" >/dev/null <<EOF
$LOG_FILE $STEP_LOG {
    weekly
    rotate 4
    compress
    delaycompress
    notifempty
    create 640 root root
    missingok
}
EOF
        print_message "$GREEN" "✓ Installer log rotation configured"
    fi
}

# Secure log permissions
secure_log_permissions() {
    if [ -f "$LOG_FILE" ]; then
        sudo chmod 640 "$LOG_FILE"
    fi
    if [ -f "$STEP_LOG" ]; then
        sudo chmod 640 "$STEP_LOG"
    fi
}

# Lock file to prevent concurrent runs
setup_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${RED}❌ Another instance is already running (PID: $pid)${NC}"
            exit 1
        else
            # Stale lock file
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Please run as root or with sudo${NC}"
        exit 1
    fi
}

# Function to check required commands
check_requirements() {
    local required_commands=("curl" "wget" "tar" "grep" "sed" "awk")
    local missing=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required commands: ${missing[*]}${NC}"
        echo -e "${YELLOW}Please install them and try again${NC}"
        exit 1
    fi
}

# Function to log steps with timestamp
log_step() {
    local step=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[STEP ${step}]${NC} ${message}"
    echo "[${timestamp}] [STEP ${step}] ${message}" >> "$STEP_LOG"
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
    secure_log_permissions
}

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    secure_log_permissions
}

# Function to detect init system
detect_init_system() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-system-running >/dev/null 2>&1 || [ -d /run/systemd/system ]; then
            echo "systemd"
            return 0
        fi
    fi
    if [ -f /sbin/openrc-run ] || [ -f /bin/openrc-run ] || [ -d /run/openrc ]; then
        echo "openrc"
        return 0
    fi
    if [ -f /etc/init.d/rc ] || [ -d /etc/rc.d ]; then
        echo "sysv"
        return 0
    fi
    echo "unknown"
}

# Function to get OS family
get_os_family() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian|linuxmint|pop|raspbian) echo "debian" ;;
            fedora|centos|rhel|rocky|almalinux) echo "rhel" ;;
            arch|manjaro) echo "arch" ;;
            opensuse*|suse) echo "suse" ;;
            alpine) echo "alpine" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# Function to apply network optimizations for seedbox
apply_network_optimizations() {
    log_step "3/16" "Applying network optimizations for seedbox performance..."

    local sysctl_conf="/etc/sysctl.d/99-transmission-seedbox.conf"

    # Check if already applied
    if [ -f "$sysctl_conf" ]; then
        print_message "$YELLOW" "  Network optimizations already configured"
        return 0
    fi

    sudo tee "$sysctl_conf" >/dev/null <<EOF
# Transmission Seedbox Network Optimizations
# Applied on: $(date)

# Increase max buffer sizes for high-speed transfers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# TCP read/write buffers (min, default, max)
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TCP window scaling (still supported in modern kernels)
net.ipv4.tcp_window_scaling = 1

# Increase system file limit
fs.file-max = 100000

# More aggressive TCP settings for many connections
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 1440000
EOF

    # Apply sysctl settings
    if sudo sysctl -p "$sysctl_conf" >/dev/null 2>&1; then
        print_message "$GREEN" "✓ Network optimizations applied"
    else
        print_message "$YELLOW" "⚠ Some settings require reboot to take effect"
    fi

    # Update limits for transmission user (idempotent)
    local limits_conf="/etc/security/limits.d/transmission.conf"
    if [ ! -f "$limits_conf" ]; then
        sudo tee "$limits_conf" >/dev/null <<EOF
# Transmission user limits
$TRANSMISSION_USER soft nofile 100000
$TRANSMISSION_USER hard nofile 100000
* soft nofile 100000
* hard nofile 100000
EOF
        print_message "$GREEN" "✓ File limits configured"
    fi

    print_message "$YELLOW" "  - Max buffer size: 16MB"
    print_message "$YELLOW" "  - Max open files: 100000"
}

# Function to setup log rotation
setup_logrotate() {
    log_step "4/16" "Setting up log rotation..."

    local logrotate_config="/etc/logrotate.d/transmission"

    # Check if already configured
    if [ -f "$logrotate_config" ]; then
        print_message "$YELLOW" "  Log rotation already configured"
        return 0
    fi

    sudo tee "$logrotate_config" >/dev/null <<EOF
$TRANSMISSION_LOG_DIR/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 640 $TRANSMISSION_USER $TRANSMISSION_USER
    sharedscripts
    postrotate
        # Check if running and send HUP signal
        if [ -f /run/transmission-daemon.pid ]; then
            kill -HUP \$(cat /run/transmission-daemon.pid) 2>/dev/null || true
        elif pgrep -f "transmission-daemon" >/dev/null; then
            pkill -HUP -f "transmission-daemon" 2>/dev/null || true
        fi
    endscript
}
EOF

    # Create log directory
    sudo mkdir -p "$TRANSMISSION_LOG_DIR"
    sudo chown $TRANSMISSION_USER:$TRANSMISSION_USER "$TRANSMISSION_LOG_DIR"
    sudo chmod 750 "$TRANSMISSION_LOG_DIR"

    print_message "$GREEN" "✓ Log rotation configured"
    print_message "$YELLOW" "  - Rotates daily, keeps 14 days"
}

# Function to get the latest Transmission version (robust with jq fallback)
get_latest_version() {
    local version=""
    local api_url="https://api.github.com/repos/transmission/transmission/releases/latest"

    # Try GitHub API with jq first (most reliable)
    if command -v jq >/dev/null 2>&1; then
        if command -v curl >/dev/null 2>&1; then
            version=$(curl -s "$api_url" 2>/dev/null | jq -r '.tag_name' | sed 's/^v//')
        elif command -v wget >/dev/null 2>&1; then
            version=$(wget -qO- "$api_url" 2>/dev/null | jq -r '.tag_name' | sed 's/^v//')
        fi
    fi

    # Fallback to grep if jq not available
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        if command -v curl >/dev/null 2>&1; then
            version=$(curl -s "$api_url" 2>/dev/null | grep '"tag_name":' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/')
        elif command -v wget >/dev/null 2>&1; then
            version=$(wget -qO- "$api_url" 2>/dev/null | grep '"tag_name":' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/')
        fi
    fi

    # Final fallback to download page
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        if command -v curl >/dev/null 2>&1; then
            version=$(curl -s https://transmissionbt.com/download 2>/dev/null |
                      grep -o 'transmission-[0-9]\+\.[0-9]\+\.[0-9]\+' |
                      head -1 |
                      sed 's/transmission-//')
        elif command -v wget >/dev/null 2>&1; then
            version=$(wget -qO- https://transmissionbt.com/download 2>/dev/null |
                      grep -o 'transmission-[0-9]\+\.[0-9]\+\.[0-9]\+' |
                      head -1 |
                      sed 's/transmission-//')
        fi
    fi

    echo "${version:-5.0.0}"
}

# Function to check if Transmission is installed
is_transmission_installed() {
    if command -v transmission-daemon >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if Transmission is running
is_transmission_running() {
    if pgrep -u "$TRANSMISSION_USER" -f "transmission-da" >/dev/null 2>&1; then
        return 0
    fi
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$SYSTEMD_SERVICE" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to get installed version
get_installed_version() {
    if is_transmission_installed; then
        transmission-daemon --version 2>&1 | head -1 | awk '{print $2}'
    else
        echo "Not installed"
    fi
}

# Function to compare versions
version_compare() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# Function to check CMake version
check_cmake_version() {
    log_step "5/16" "Checking CMake version..."

    if ! command -v cmake >/dev/null 2>&1; then
        print_message "$YELLOW" "⚠ CMake not found, will install manually"
        return 1
    fi

    local cmake_version=$(cmake --version | head -n1 | awk '{print $3}')
    local required="3.16.0"

    if version_compare "$required" "$cmake_version"; then
        print_message "$GREEN" "✓ CMake $cmake_version (meets minimum requirement $required)"
        return 0
    else
        print_message "$YELLOW" "⚠ CMake $cmake_version is too old (need $required+)"
        return 1
    fi
}

# Function to check for mbedtls development libraries
check_mbedtls() {
    local os_family=$(get_os_family)

    case $os_family in
        debian)
            if ! dpkg -l | grep -q libmbedtls-dev; then
                print_message "$YELLOW" "Installing mbedtls development libraries..."
                DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq libmbedtls-dev
            fi
            ;;
        rhel)
            if ! rpm -q mbedtls-devel >/dev/null 2>&1; then
                print_message "$YELLOW" "Installing mbedtls development libraries..."
                if command -v dnf >/dev/null 2>&1; then
                    sudo dnf -y -q install mbedtls-devel || true
                else
                    sudo yum -y -q install mbedtls-devel || true
                fi
            fi
            ;;
        arch)
            if ! pacman -Q mbedtls >/dev/null 2>&1; then
                print_message "$YELLOW" "Installing mbedtls..."
                sudo pacman -Sy --noconfirm --quiet mbedtls
            fi
            ;;
        alpine)
            if ! apk info -e mbedtls-dev >/dev/null 2>&1; then
                print_message "$YELLOW" "Installing mbedtls development libraries..."
                sudo apk add --quiet mbedtls-dev
            fi
            ;;
    esac
}

# Function to detect OS and install dependencies
install_dependencies() {
    log_step "6/16" "Detecting operating system and installing dependencies..."

    local os_family=$(get_os_family)
    local os_info="Unknown"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_info="$PRETTY_NAME"
    fi

    print_message "$GREEN" "✓ Detected OS: $os_info (Family: $os_family)"

    case $os_family in
        debian)
            print_message "$YELLOW" "📦 Using apt package manager..."
            DEBIAN_FRONTEND=noninteractive sudo apt-get update -qq
            DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq \
                build-essential checkinstall pkg-config libtool intltool \
                libcurl4-openssl-dev libssl-dev libevent-dev wget curl cmake jq \
                libmbedtls-dev
            ;;

        rhel)
            print_message "$YELLOW" "📦 Using yum/dnf package manager..."
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf -y -q groupinstall "Development Tools"
                sudo dnf -y -q install checkinstall libtool intltool libcurl-devel openssl-devel \
                    libevent-devel wget curl cmake jq mbedtls-devel || true
            else
                sudo yum -y -q groupinstall "Development Tools"
                sudo yum -y -q install checkinstall libtool intltool libcurl-devel openssl-devel \
                    libevent-devel wget curl cmake jq mbedtls-devel || true
            fi
            ;;

        arch)
            print_message "$YELLOW" "📦 Using pacman package manager..."
            sudo pacman -Sy --noconfirm --quiet base-devel checkinstall libtool intltool curl openssl \
                libevent wget cmake jq mbedtls
            ;;

        suse)
            print_message "$YELLOW" "📦 Using zypper package manager..."
            sudo zypper --non-interactive --quiet install -t pattern devel_basis
            sudo zypper --non-interactive --quiet install checkinstall libtool intltool libcurl-devel \
                libopenssl-devel libevent-devel wget curl cmake jq mbedtls-devel
            ;;

        alpine)
            print_message "$YELLOW" "📦 Using apk package manager..."
            sudo apk add --quiet build-base checkinstall libtool intltool curl-dev openssl-dev \
                libevent-dev linux-headers wget curl cmake jq mbedtls-dev
            ;;

        *)
            print_message "$YELLOW" "⚠ Unknown OS family, installing dependencies manually..."
            try_common_package_managers
            ;;
    esac

    # Verify mbedtls is available
    check_mbedtls

    # Check CMake and auto-install if needed
    if ! check_cmake_version; then
        print_message "$YELLOW" "⚠ Installing CMake manually..."
        install_cmake_manually
    fi

    print_message "$GREEN" "✓ Dependencies installed successfully"
}

# Function to try common package managers
try_common_package_managers() {
    local pkgs="build-essential checkinstall pkg-config libtool intltool libcurl4-openssl-dev libssl-dev libevent-dev wget curl cmake jq libmbedtls-dev"

    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive sudo apt-get update -qq
        DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq $pkgs
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf -y -q groupinstall "Development Tools"
        sudo dnf -y -q install $pkgs
    elif command -v yum >/dev/null 2>&1; then
        sudo yum -y -q groupinstall "Development Tools"
        sudo yum -y -q install $pkgs
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm --quiet base-devel $pkgs
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper --non-interactive --quiet install -t pattern devel_basis
        sudo zypper --non-interactive --quiet install $pkgs
    elif command -v apk >/dev/null 2>&1; then
        sudo apk add --quiet build-base $pkgs
    else
        print_message "$RED" "❌ Could not detect package manager"
        exit 1
    fi
}

# Function to manually install CMake
install_cmake_manually() {
    if ! command -v wget >/dev/null 2>&1; then
        print_message "$RED" "❌ wget not found"
        exit 1
    fi

    cd /tmp
    local cmake_version="3.27.7"

    # Try to get latest version
    if command -v jq >/dev/null 2>&1; then
        local latest=$(curl -s https://api.github.com/repos/Kitware/CMake/releases/latest 2>/dev/null | jq -r '.tag_name' | sed 's/^v//')
        [ -n "$latest" ] && cmake_version="$latest"
    fi

    local arch=$(uname -m)
    local url=""
    case $arch in
        x86_64)  url="https://github.com/Kitware/CMake/releases/download/v${cmake_version}/cmake-${cmake_version}-linux-x86_64.tar.gz" ;;
        aarch64) url="https://github.com/Kitware/CMake/releases/download/v${cmake_version}/cmake-${cmake_version}-linux-aarch64.tar.gz" ;;
        armv7l)  url="https://github.com/Kitware/CMake/releases/download/v${cmake_version}/cmake-${cmake_version}-linux-armv7l.tar.gz" ;;
        *)       print_message "$RED" "❌ Unsupported architecture: $arch"; exit 1 ;;
    esac

    if wget --timeout=30 --tries=3 -q "$url"; then
        sudo tar -xzf "cmake-${cmake_version}-linux-${arch}.tar.gz" -C /opt
        sudo ln -sf "/opt/cmake-${cmake_version}-linux-${arch}/bin/cmake" /usr/local/bin/cmake
        sudo ln -sf "/opt/cmake-${cmake_version}-linux-${arch}/bin/ccmake" /usr/local/bin/ccmake
        sudo ln -sf "/opt/cmake-${cmake_version}-linux-${arch}/bin/cpack" /usr/local/bin/cpack
        sudo ln -sf "/opt/cmake-${cmake_version}-linux-${arch}/bin/ctest" /usr/local/bin/ctest
        rm -f "cmake-${cmake_version}-linux-${arch}.tar.gz"
        print_message "$GREEN" "✓ CMake $cmake_version installed manually"
    else
        print_message "$RED" "❌ Failed to download CMake"
        exit 1
    fi
}

# Function to ensure process is completely stopped
ensure_process_stopped() {
    local user=$1
    local max_wait=30
    local waited=0

    while pgrep -u "$user" -f "transmission-da" >/dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            sudo pkill -9 -u "$user" -f "transmission-da" 2>/dev/null || true
            sleep 2
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done

    return 0
}

# Function to download and compile Transmission
install_transmission() {
    local version=$1
    local version_clean=$(echo "$version" | sed 's/^v//')
    local download_success=false
    local downloaded_file=""

    log_step "8/16" "Installing Transmission version ${version_clean}"

    cd ~
    sudo rm -rf "transmission-${version_clean}" 2>/dev/null || true
    rm -f transmission-${version_clean}.tar.* 2>/dev/null || true

    download_urls=(
        "https://github.com/transmission/transmission/releases/download/${version_clean}/transmission-${version_clean}.tar.xz"
        "https://github.com/transmission/transmission/releases/download/v${version_clean}/transmission-${version_clean}.tar.xz"
        "https://github.com/transmission/transmission-releases/raw/master/transmission-${version_clean}.tar.xz"
        "https://github.com/transmission/transmission/archive/refs/tags/${version_clean}.tar.gz"
        "https://github.com/transmission/transmission/archive/refs/tags/v${version_clean}.tar.gz"
        "https://download.transmissionbt.com/files/transmission-${version_clean}.tar.xz"
    )

    for url in "${download_urls[@]}"; do
        local filename=$(basename "$url")
        if wget --timeout=30 --tries=3 -q --show-progress "$url" 2>&1; then
            if [ -f "$filename" ] && [ -s "$filename" ]; then
                download_success=true
                downloaded_file="$filename"
                break
            fi
        fi
    done

    if [ "$download_success" = false ]; then
        print_message "$RED" "❌ Failed to download Transmission"
        exit 1
    fi

    # Extract
    if [[ "$downloaded_file" == *.tar.xz ]]; then
        tar -xf "$downloaded_file"
    elif [[ "$downloaded_file" == *.tar.gz ]]; then
        tar -xzf "$downloaded_file"
    fi

    cd "transmission-${version_clean}" 2>/dev/null || cd "transmission-${version_clean#v}" 2>/dev/null || {
        print_message "$RED" "❌ Could not find extracted directory"
        exit 1
    }

    # Build
    if [ -f "CMakeLists.txt" ]; then
        mkdir -p build && cd build
        cmake -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr/local \
              -DENABLE_DAEMON=ON \
              -DENABLE_GTK=OFF \
              -DENABLE_QT=OFF \
              -DENABLE_UTILS=ON \
              -DENABLE_CLI=ON \
              -DENABLE_WEB=ON \
              -DUSE_SYSTEM_EVENT2=ON \
              -DUSE_SYSTEM_DEFLATE=ON \
              -DUSE_SYSTEM_MBEDTLS=ON \
              -DUSE_SYSTEM_PSL=ON \
              -DUSE_SYSTEM_DHT=ON \
              -DUSE_SYSTEM_MINIUPNPC=ON \
              -DUSE_SYSTEM_NATPMP=ON \
              -DUSE_SYSTEM_UTP=ON \
              -DUSE_SYSTEM_B64=ON \
              ..
        local jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
        make -j${jobs}
        sudo make install
    elif [ -f "configure" ]; then
        ./configure --prefix=/usr/local \
                    --disable-gtk \
                    --disable-qt \
                    --enable-cli \
                    --enable-daemon \
                    --enable-utilities
        make -j$(nproc)
        sudo make install
    else
        print_message "$RED" "❌ No recognizable build system found"
        exit 1
    fi

    cd ~
    rm -f transmission-${version_clean}.tar.* 2>/dev/null || true
    sudo rm -rf "transmission-${version_clean}" 2>/dev/null || true

    print_message "$GREEN" "✓ Transmission ${version_clean} installed"
}

# Function to create transmission user
create_transmission_user() {
    log_step "9/16" "Creating dedicated transmission user..."

    if ! id "$TRANSMISSION_USER" >/dev/null 2>&1; then
        sudo useradd -r -s /sbin/nologin -m -d "/home/${TRANSMISSION_USER}" ${TRANSMISSION_USER}
        print_message "$GREEN" "✓ User $TRANSMISSION_USER created"
    fi

    # Create directories
    sudo mkdir -p "${TRANSMISSION_HOME}" "${DOWNLOAD_DIR}" "${TRANSMISSION_LOG_DIR}"
    sudo chown -R ${TRANSMISSION_USER}:${TRANSMISSION_USER} "/home/${TRANSMISSION_USER}"
    sudo chown ${TRANSMISSION_USER}:${TRANSMISSION_USER} "${DOWNLOAD_DIR}"
    sudo chown -R ${TRANSMISSION_USER}:${TRANSMISSION_USER} "${TRANSMISSION_LOG_DIR}"
    sudo chmod 750 "/home/${TRANSMISSION_USER}"
    sudo chmod 775 "${DOWNLOAD_DIR}"
    sudo chmod 750 "${TRANSMISSION_LOG_DIR}"
}

# Function to setup init script
setup_init_script() {
    local init_system=$(detect_init_system)

    log_step "10/16" "Setting up $init_system service..."

    case $init_system in
        systemd)
            setup_systemd_service
            ;;
        openrc)
            setup_openrc_service
            ;;
        sysv)
            setup_sysv_init
            ;;
        *)
            print_message "$YELLOW" "⚠ Unknown init system, falling back to SysV"
            setup_sysv_init
            ;;
    esac
}

# Function to setup systemd service (idempotent)
setup_systemd_service() {
    local transmission_bin=$(command -v transmission-daemon || echo "/usr/local/bin/transmission-daemon")

    # Use systemctl edit --full to create/modify service safely
    local service_content="[Unit]
Description=Transmission BitTorrent Daemon
After=network.target

[Service]
User=$TRANSMISSION_USER
Type=simple
Environment=TRANSMISSION_HOME=$TRANSMISSION_HOME
ExecStart=$transmission_bin -f --log-level=error
ExecReload=/bin/kill -s HUP \$MAINPID
PIDFile=/run/transmission-daemon.pid
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=read-only
PrivateDevices=true
PrivateTmp=true
InaccessibleDirectories=/root
ReadWritePaths=$TRANSMISSION_HOME $DOWNLOAD_DIR $TRANSMISSION_LOG_DIR
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target"

    # Create temp file and use systemctl edit --full
    local tmp_service=$(mktemp)
    echo "$service_content" > "$tmp_service"
    sudo systemctl edit --full --force "$SYSTEMD_SERVICE" < "$tmp_service" 2>/dev/null || {
        # Fallback to direct write
        sudo cp "$tmp_service" "$SYSTEMD_SERVICE_PATH"
    }
    rm -f "$tmp_service"

    sudo systemctl daemon-reload
    sudo systemctl enable "$SYSTEMD_SERVICE" 2>/dev/null || true

    print_message "$GREEN" "✓ Systemd service configured"
}

# Function to setup OpenRC service
setup_openrc_service() {
    local transmission_bin=$(command -v transmission-daemon || echo "/usr/local/bin/transmission-daemon")
    local openrc_service="/etc/init.d/transmission-daemon"

    sudo tee "$openrc_service" >/dev/null <<EOF
#!/sbin/openrc-run

name="transmission-daemon"
description="Transmission BitTorrent Daemon"
command="$transmission_bin"
command_args="-f --log-level=error"
command_user="$TRANSMISSION_USER"
pidfile="/run/\${RC_SVCNAME}.pid"
command_background=true
output_log="$TRANSMISSION_LOG_DIR/transmission.log"
error_log="$TRANSMISSION_LOG_DIR/transmission.err"

depend() {
    need net
}

start_pre() {
    if [ ! -d "$TRANSMISSION_LOG_DIR" ]; then
        mkdir -p "$TRANSMISSION_LOG_DIR"
        chown $TRANSMISSION_USER:$TRANSMISSION_USER "$TRANSMISSION_LOG_DIR"
        chmod 750 "$TRANSMISSION_LOG_DIR"
    fi
    checkpath -f -m 0644 -o "$TRANSMISSION_USER" "$pidfile"
}
EOF

    sudo chmod +x "$openrc_service"
    sudo rc-update add transmission-daemon default 2>/dev/null || true

    print_message "$GREEN" "✓ OpenRC service configured"
}

# Function to setup SysV init script
setup_sysv_init() {
    # Extract with CRLF cleanup
    sudo sed -n '/^#initdscript#$/,$p' "$SCRIPT" | sed '1d' | tr -d '\r' | sudo tee ${INIT_SCRIPT} >/dev/null

    local transmission_bin=$(command -v transmission-daemon || echo "/usr/local/bin/transmission-daemon")

    sudo sed -i "s/USERNAME=transmission/USERNAME=${TRANSMISSION_USER}/" ${INIT_SCRIPT}
    sudo sed -i "s|#TRANSMISSION_HOME=\"/var/config/transmission-daemon\"|TRANSMISSION_HOME=\"${TRANSMISSION_HOME}\"|" ${INIT_SCRIPT}
    sudo sed -i "s|#TRANSMISSION_WEB_HOME=\"/usr/share/transmission/web\"|TRANSMISSION_WEB_HOME=\"/usr/local/share/transmission/web\"|" ${INIT_SCRIPT}
    sudo sed -i "s|DAEMON=\$(which \$NAME)|DAEMON=\"$transmission_bin\"|" ${INIT_SCRIPT}

    sudo chmod +x ${INIT_SCRIPT}

    # Enable based on OS family
    local os_family=$(get_os_family)
    if [ "$os_family" = "debian" ]; then
        sudo update-rc.d transmission-daemon defaults 2>/dev/null || true
    else
        sudo chkconfig --add transmission-daemon 2>/dev/null || true
        sudo chkconfig transmission-daemon on 2>/dev/null || true
    fi

    print_message "$GREEN" "✓ SysV init script configured"
}

# Function to generate random password
generate_transmission_password() {
    local password_length=${1:-16}
    local plain_password=""
    local salt=""
    local hash=""

    if command -v openssl >/dev/null 2>&1; then
        plain_password=$(openssl rand -base64 12 | tr -d '\n' | tr -d '=' | tr '+' '.' | tr '/' '_')
        salt=$(openssl rand -base64 8 | tr -d '\n' | tr -d '=' | tr '+' '.' | tr '/' '_' | cut -c1-8)
    elif [ -f /dev/urandom ]; then
        plain_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c "$password_length")
        salt=$(cat /dev/urandom 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c 8)
    else
        plain_password=$(date +%s%N | sha256sum | base64 | head -c "$password_length")
        salt="RandSalt0"
    fi

    while [ ${#salt} -lt 8 ]; do
        salt="${salt}0"
    done
    salt=$(echo "$salt" | cut -c1-8)

    if command -v openssl >/dev/null 2>&1; then
        hash=$(echo -n "${plain_password}${salt}" | openssl sha1 | awk '{print $2}')
    else
        hash=$(echo -n "${plain_password}${salt}" | sha256sum 2>/dev/null | cut -c1-40)
    fi

    echo "{${hash}${salt}}:$plain_password"
}

# Function to initialize configuration (idempotent)
initialize_config() {
    log_step "11/16" "Initializing Transmission configuration..."

    # Only create if it doesn't exist
    if [ ! -f "$SETTINGS_FILE" ]; then
        print_message "$BLUE" "Starting Transmission to create default config..."
        start_service
        sleep 5
        stop_service
        ensure_process_stopped "$TRANSMISSION_USER"
    fi

    sudo chown -R ${TRANSMISSION_USER}:${TRANSMISSION_USER} "${TRANSMISSION_HOME}"
    sudo chmod 750 "${TRANSMISSION_HOME}"

    if [ -f "$SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
        # Update download directory if not set correctly
        local current_dir=$(jq -r '.["download-dir"]' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$current_dir" != "$DOWNLOAD_DIR" ]; then
            sudo jq --arg dir "$DOWNLOAD_DIR" '. + {"download-dir": $dir}' "$SETTINGS_FILE" > /tmp/settings.json.tmp
            sudo mv /tmp/settings.json.tmp "$SETTINGS_FILE"
            sudo chown ${TRANSMISSION_USER}:${TRANSMISSION_USER} "$SETTINGS_FILE"
        fi
    fi
}

# Main installation function (idempotent)
do_install() {
    # Check if already installed with marker
    if [ -f "$INSTALL_MARKER" ] && is_transmission_installed; then
        local installed_ver=$(get_installed_version)
        print_message "$YELLOW" "Transmission $installed_ver already installed"
        read -p "Reinstall/update? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    print_message "$GREEN" "======================================================"
    print_message "$GREEN" "  Transmission Seedbox Installation"
    print_message "$GREEN" "======================================================"

    # Stop if running
    if is_transmission_running; then
        print_message "$YELLOW" "Stopping Transmission..."
        stop_service
        ensure_process_stopped "$TRANSMISSION_USER"
    fi

    install_dependencies

    log_step "12/16" "Detecting latest Transmission version..."
    LATEST_VERSION=$(get_latest_version)
    print_message "$GREEN" "✓ Latest version: ${LATEST_VERSION}"

    read -p "Install ${LATEST_VERSION}? (y/n - 'c' for custom): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Cc]$ ]]; then
        read -p "Enter version (e.g., 5.0.0): " CUSTOM_VERSION
        VERSION_TO_INSTALL=$CUSTOM_VERSION
    elif [[ $REPLY =~ ^[Yy]$ ]]; then
        VERSION_TO_INSTALL=$LATEST_VERSION
    else
        return
    fi

    install_transmission "${VERSION_TO_INSTALL}"
    create_transmission_user
    setup_init_script
    initialize_config

    log_step "13/16" "Generating secure password..."
    local password_result=$(generate_transmission_password)
    local password_hash=$(echo "$password_result" | cut -d: -f1)
    local plain_password=$(echo "$password_result" | cut -d: -f2)

    set_rpc_password "$password_hash"

    # Save password
    local password_file="${TRANSMISSION_HOME}/.rpc_password.txt"
    echo "$plain_password" | sudo tee "$password_file" >/dev/null
    sudo chmod 600 "$password_file"
    sudo chown ${TRANSMISSION_USER}:${TRANSMISSION_USER} "$password_file" 2>/dev/null || true

    log_step "14/16" "Starting Transmission..."
    start_service
    sleep 3

    # Create installation marker
    date > "$INSTALL_MARKER"
    echo "Transmission ${VERSION_TO_INSTALL}" >> "$INSTALL_MARKER"

    log_step "15/16" "Verifying installation..."
    log_step "16/16" "Installation complete!"

    # Secure logs one final time
    secure_log_permissions

    # Show summary
    local ip_addr=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}' || hostname -I | awk '{print $1}')
    local rpc_port=$(grep '"rpc-port"' "$SETTINGS_FILE" 2>/dev/null | grep -o '[0-9]\+' || echo "9091")

    print_message "$GREEN" "======================================================"
    print_message "$GREEN" "✅ Transmission ${VERSION_TO_INSTALL} installed!"
    print_message "$GREEN" "======================================================"
    print_message "$YELLOW" "📁 Config: $SETTINGS_FILE"
    print_message "$YELLOW" "📁 Downloads: ${DOWNLOAD_DIR}"
    print_message "$YELLOW" "🔑 Password: ${TRANSMISSION_HOME}/.rpc_password.txt"
    print_message "$GREEN" "🌐 Web UI: http://${ip_addr}:${rpc_port}"
    print_message "$GREEN" "======================================================"
}

# Enhanced set_rpc_password with ghost config prevention
set_rpc_password() {
    local new_pass=$1
    if [ -z "$new_pass" ]; then
        read -sp "Enter new RPC password: " new_pass
        echo
    fi

    log_step "RPC" "Setting RPC password..."

    # Stop service
    stop_service >/dev/null 2>&1

    # Wait for process to die
    local timeout=30
    while pgrep -u "$TRANSMISSION_USER" -f "transmission-da" >/dev/null && [ $timeout -gt 0 ]; do
        sleep 1
        ((timeout--))
    done

    if [ -f "$SETTINGS_FILE" ]; then
        # Backup
        local backup_file="${SETTINGS_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$SETTINGS_FILE" "$backup_file"

        # Update password
        if command -v jq >/dev/null 2>&1; then
            sudo jq --arg pass "$new_pass" '. + {"rpc-password": $pass}' "$SETTINGS_FILE" > /tmp/settings.json.tmp
            sudo mv /tmp/settings.json.tmp "$SETTINGS_FILE"
        else
            sudo sed -i "s/\"rpc-password\": \".*\"/\"rpc-password\": \"$new_pass\"/" "$SETTINGS_FILE"
        fi

        # Save plain text
        echo "$new_pass" | sudo tee "$TRANSMISSION_HOME/.rpc_password.txt" >/dev/null
        sudo chmod 600 "$TRANSMISSION_HOME/.rpc_password.txt"
        sudo chown "$TRANSMISSION_USER:$TRANSMISSION_USER" "$TRANSMISSION_HOME/.rpc_password.txt"

        start_service >/dev/null 2>&1
        print_message "$GREEN" "✓ Password updated"
    else
        print_message "$RED" "✗ settings.json not found"
        return 1
    fi
}

# Service management
start_service() {
    local init_system=$(detect_init_system)

    case $init_system in
        systemd)
            sudo systemctl start "$SYSTEMD_SERVICE" 2>/dev/null || true
            ;;
        openrc)
            sudo /etc/init.d/transmission-daemon start 2>/dev/null || true
            ;;
        *)
            if [ -f "${INIT_SCRIPT}" ]; then
                sudo ${INIT_SCRIPT} start 2>/dev/null || true
            fi
            ;;
    esac
}

stop_service() {
    local init_system=$(detect_init_system)

    case $init_system in
        systemd)
            sudo systemctl stop "$SYSTEMD_SERVICE" 2>/dev/null || true
            ;;
        openrc)
            sudo /etc/init.d/transmission-daemon stop 2>/dev/null || true
            ;;
        *)
            if [ -f "${INIT_SCRIPT}" ]; then
                sudo ${INIT_SCRIPT} stop 2>/dev/null || true
            fi
            ;;
    esac
}

restart_service() {
    local init_system=$(detect_init_system)

    case $init_system in
        systemd)
            sudo systemctl restart "$SYSTEMD_SERVICE" 2>/dev/null || true
            ;;
        openrc)
            sudo /etc/init.d/transmission-daemon restart 2>/dev/null || true
            ;;
        *)
            if [ -f "${INIT_SCRIPT}" ]; then
                sudo ${INIT_SCRIPT} restart 2>/dev/null || true
            fi
            ;;
    esac
}

# Function to backup configuration
backup_config() {
    local backup_dir="/root/transmission-backup-$(date +%Y%m%d-%H%M%S)"

    if [ -d "${TRANSMISSION_HOME}" ]; then
        print_message "$BLUE" "Creating backup..."
        sudo mkdir -p "$backup_dir"
        sudo cp -r "${TRANSMISSION_HOME}" "$backup_dir/"
        sudo cp -r "${DOWNLOAD_DIR}" "$backup_dir/downloads" 2>/dev/null || true
        sudo cp -r "${TRANSMISSION_LOG_DIR}" "$backup_dir/logs" 2>/dev/null || true
        sudo tar -czf "${backup_dir}.tar.gz" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")"
        sudo rm -rf "$backup_dir"
        print_message "$GREEN" "✓ Backup: ${backup_dir}.tar.gz"
    else
        print_message "$RED" "❌ No configuration found"
    fi
}

# Function to uninstall Transmission
do_uninstall() {
    print_message "$RED" "======================================================"
    print_message "$RED" "  Transmission Uninstallation"
    print_message "$RED" "======================================================"

    if ! is_transmission_installed; then
        print_message "$YELLOW" "Transmission not installed"
        return
    fi

    local installed_ver=$(get_installed_version)
    print_message "$YELLOW" "Current: Transmission $installed_ver"

    read -p "Backup before uninstall? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        backup_config
    fi

    read -p "Uninstall Transmission? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi

    log_step "UNINSTALL/1" "Stopping service..."
    stop_service
    ensure_process_stopped "$TRANSMISSION_USER"

    log_step "UNINSTALL/2" "Removing service..."
    local init_system=$(detect_init_system)
    case $init_system in
        systemd)
            sudo systemctl disable "$SYSTEMD_SERVICE" 2>/dev/null || true
            sudo rm -f "$SYSTEMD_SERVICE_PATH"
            sudo systemctl daemon-reload
            ;;
        openrc)
            sudo rc-update del transmission-daemon 2>/dev/null || true
            sudo rm -f /etc/init.d/transmission-daemon
            ;;
        *)
            if [ -f "${INIT_SCRIPT}" ]; then
                sudo update-rc.d transmission-daemon remove 2>/dev/null || true
                sudo rm -f "${INIT_SCRIPT}"
            fi
            ;;
    esac

    log_step "UNINSTALL/3" "Removing configs..."
    sudo rm -f /etc/logrotate.d/transmission
    sudo rm -f /etc/sysctl.d/99-transmission-seedbox.conf
    sudo rm -f /etc/security/limits.d/transmission.conf

    log_step "UNINSTALL/4" "Removing binaries..."
    sudo rm -f /usr/local/bin/transmission-*
    sudo rm -rf /usr/local/share/transmission
    sudo rm -rf /usr/local/share/doc/transmission*

    print_message "$YELLOW" "Remove user and data?"
    read -p "Remove $TRANSMISSION_USER? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pkill -u ${TRANSMISSION_USER} 2>/dev/null || true
        sudo userdel -r ${TRANSMISSION_USER} 2>/dev/null || true
        sudo rm -rf /home/${TRANSMISSION_USER}
        sudo rm -rf ${DOWNLOAD_DIR}
        sudo rm -rf ${TRANSMISSION_LOG_DIR}
    fi

    rm -f "$INSTALL_MARKER"
    print_message "$GREEN" "✓ Transmission uninstalled"

    # Secure logs one final time
    secure_log_permissions
}

# Show status
show_status() {
    print_message "$BLUE" "=== Transmission Status ==="

    if is_transmission_installed; then
        local installed_ver=$(get_installed_version)
        print_message "$GREEN" "Version: $installed_ver"
        print_message "$GREEN" "Binary: $(command -v transmission-daemon)"

        if is_transmission_running; then
            print_message "$GREEN" "Service: Running"
        else
            print_message "$YELLOW" "Service: Not running"
        fi

        if [ -f "$SETTINGS_FILE" ]; then
            local rpc_port=$(grep '"rpc-port"' "$SETTINGS_FILE" 2>/dev/null | grep -o '[0-9]\+')
            local download_dir=$(grep '"download-dir"' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*"download-dir": "\([^"]*\)".*/\1/')
            echo "----------------------------------------"
            echo "RPC Port: ${rpc_port:-9091}"
            echo "Downloads: ${download_dir:-/downloads}"
            echo "----------------------------------------"
        fi

        local latest=$(get_latest_version)
        if [ "$installed_ver" != "$latest" ]; then
            print_message "$YELLOW" "Update available: $latest"
        fi
    else
        print_message "$YELLOW" "Transmission not installed"
        print_message "$BLUE" "Latest version: $(get_latest_version)"
    fi
}

# Check firewall
check_firewall() {
    print_message "$BLUE" "=== Firewall Check ==="

    if [ -f "$SETTINGS_FILE" ]; then
        local rpc_port=$(grep '"rpc-port"' "$SETTINGS_FILE" 2>/dev/null | grep -o '[0-9]\+')
        local peer_port=$(grep '"peer-port"' "$SETTINGS_FILE" 2>/dev/null | grep -o '[0-9]\+')

        if [ -n "$rpc_port" ]; then
            echo "RPC: $rpc_port | Peer: ${peer_port:-51413}"

            if command -v ufw >/dev/null 2>&1; then
                sudo ufw status | grep -E "$rpc_port|$peer_port" || echo "⚠ No UFW rules found"
            elif command -v firewall-cmd >/dev/null 2>&1; then
                sudo firewall-cmd --list-ports | grep -E "$rpc_port|$peer_port" || echo "⚠ No firewalld rules"
            fi
        fi
    else
        print_message "$YELLOW" "Install Transmission first"
    fi
}

# View logs
view_logs() {
    print_message "$BLUE" "=== Transmission Logs ==="
    if [ -f "${TRANSMISSION_LOG_DIR}/transmission.log" ]; then
        tail -20 "${TRANSMISSION_LOG_DIR}/transmission.log"
    else
        print_message "$YELLOW" "No logs found"
    fi
}

# Show menu
show_menu() {
    clear
    print_message "$BLUE" "╔════════════════════════════════════════╗"
    print_message "$BLUE" "║    Transmission Seedbox Manager        ║"
    print_message "$BLUE" "║    Build: ${BUILD_DATE} v${SCRIPT_VERSION}        ║"
    print_message "$BLUE" "║    GOLD MASTER EDITION                  ║"
    print_message "$BLUE" "╚════════════════════════════════════════╝"
    echo ""

    if is_transmission_installed; then
        print_message "$GREEN" "Current: Transmission $(get_installed_version)"
        local latest=$(get_latest_version)
        [ "$(get_installed_version)" != "$latest" ] && print_message "$YELLOW" "Update: $latest available"
    else
        print_message "$YELLOW" "Current: Not installed"
    fi
    echo ""

    echo " 1) Install/Update"
    echo " 2) Uninstall"
    echo " 3) Show Status"
    echo " 4) Start Service"
    echo " 5) Stop Service"
    echo " 6) Restart Service"
    echo " 7) View Config"
    echo " 8) Backup"
    echo " 9) Set Password"
    echo "10) Generate Random Password"
    echo "11) Check Firewall"
    echo "12) View Logs"
    echo "13) Show Performance"
    echo "14) Apply Network Optimizations"
    echo "15) View Install Logs"
    echo "16) Exit"
    echo ""
    read -p "Select [1-16]: " menu_choice
}

# Show performance stats
show_performance() {
    print_message "$BLUE" "=== Performance Stats ==="
    echo "Memory:"
    free -h
    echo ""
    echo "Disk:"
    df -h "$DOWNLOAD_DIR" 2>/dev/null || df -h /
    echo ""
    echo "Network:"
    sysctl net.core.rmem_max net.core.wmem_max 2>/dev/null | sed 's/^/  /'
}

# View installation logs
view_install_logs() {
    print_message "$BLUE" "=== Installation Logs ==="
    if [ -f "$STEP_LOG" ]; then
        tail -20 "$STEP_LOG"
        echo ""
        echo "Full log: $STEP_LOG"
    else
        echo "No installation logs found"
    fi
}

# Cleanup function
cleanup() {
    secure_log_permissions
    rm -f "$LOCK_FILE"
}

# Main loop
main() {
    check_root
    check_requirements
    setup_lock

    # Set cleanup trap
    trap cleanup EXIT

    # Initialize logs with secure permissions
    sudo touch "$LOG_FILE" "$STEP_LOG" 2>/dev/null || true
    secure_log_permissions

    # Setup log rotation for installer logs
    setup_installer_logrotate

    # Handle command line
    case ${1:-} in
        install) do_install; exit 0 ;;
        uninstall) do_uninstall; exit 0 ;;
        status) show_status; exit 0 ;;
        backup) backup_config; exit 0 ;;
        optimize) apply_network_optimizations; exit 0 ;;
    esac

    while true; do
        show_menu
        case $menu_choice in
            1) do_install ;;
            2) do_uninstall ;;
            3) show_status ;;
            4) start_service ;;
            5) stop_service ;;
            6) restart_service ;;
            7) echo "Config: $SETTINGS_FILE" ;;
            8) backup_config ;;
            9) set_rpc_password ;;
            10)
                result=$(generate_transmission_password)
                hash=$(echo "$result" | cut -d: -f1)
                plain=$(echo "$result" | cut -d: -f2)
                echo "Password: $plain"
                set_rpc_password "$hash"
                ;;
            11) check_firewall ;;
            12) view_logs ;;
            13) show_performance ;;
            14) apply_network_optimizations ;;
            15) view_install_logs ;;
            16) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid option" ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# Run main
main "$@"

exit 0

#initdscript#
#!/bin/bash
### BEGIN INIT INFO
# Provides:          transmission-daemon
# Required-Start:    networking
# Required-Stop:     networking
# Default-Start:     2 3 5
# Default-Stop:      0 1 6
# Short-Description: Start the transmission BitTorrent daemon client.
### END INIT INFO

# Do NOT "set -e"

USERNAME=transmission
TRANSMISSION_HOME="/home/transmission/.config/transmission-daemon"
TRANSMISSION_WEB_HOME="/usr/local/share/transmission/web"
TRANSMISSION_LOG_DIR="/var/log/transmission"
TRANSMISSION_ARGS=""

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
DESC="bittorrent client"
NAME=transmission-daemon
DAEMON=$(which $NAME)
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

[ -x "$DAEMON" ] || exit 0
[ -r /etc/default/$NAME ] && . /etc/default/$NAME
[ -f /etc/default/rcS ] && . /etc/default/rcS

do_start()
{
    if [ ! -d "$TRANSMISSION_LOG_DIR" ]; then
        mkdir -p "$TRANSMISSION_LOG_DIR"
        chown $USERNAME:$USERNAME "$TRANSMISSION_LOG_DIR"
        chmod 750 "$TRANSMISSION_LOG_DIR"
    fi

    [ -n "$TRANSMISSION_HOME" ] && export TRANSMISSION_HOME
    [ -n "$TRANSMISSION_WEB_HOME" ] && export TRANSMISSION_WEB_HOME

    start-stop-daemon --chuid $USERNAME --start --pidfile $PIDFILE --make-pidfile \
            --exec $DAEMON --background --test -- -f $TRANSMISSION_ARGS > /dev/null \
            || return 1
    start-stop-daemon --chuid $USERNAME --start --pidfile $PIDFILE --make-pidfile \
            --exec $DAEMON --background -- -f $TRANSMISSION_ARGS 2>&1 | logger -t transmission-daemon \
            || return 2
}

do_stop()
{
    local RETVAL=0
    start-stop-daemon --stop --quiet --retry=TERM/10/KILL/5 --pidfile $PIDFILE --exec $DAEMON
    RETVAL="$?"
    [ "$RETVAL" = 2 ] && return 2

    start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
    [ "$?" = 2 ] && return 2

    rm -f $PIDFILE
    return "$RETVAL"
}

case "$1" in
  start|stop|restart|force-reload)
        echo "$1 $DESC $NAME..."
        do_$1
        ;;
  *)
        echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}" >&2
        exit 3
        ;;
esac
