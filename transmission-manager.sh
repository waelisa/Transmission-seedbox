#!/bin/bash
#############################################################################################################################
# The MIT License (MIT)
# Wael Isa
# 2/17/2026
# https://github.com/waelisa/Transmission-seedbox
#############################################################################################################################
# Transmission Auto Installer/Uninstaller - Automatically detects and installs latest version
#############################################################################################################################
set -e
SCRIPT="$(readlink -e "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TRANSMISSION_USER="transmission"
TRANSMISSION_HOME="/home/${TRANSMISSION_USER}/.config/transmission-daemon"
INIT_SCRIPT="/etc/init.d/transmission-daemon"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_message "$RED" "Please run as root or with sudo"
        exit 1
    fi
}

# Function to get the latest Transmission version from GitHub (returns only version number, no output)
get_latest_version() {
    local version=""

    # Try to get the latest release from GitHub API
    if command -v curl >/dev/null 2>&1; then
        version=$(curl -s https://api.github.com/repos/transmission/transmission/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//' 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- https://api.github.com/repos/transmission/transmission/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//' 2>/dev/null)
    fi

    # Fallback to scraping the download page if GitHub API fails
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        if command -v curl >/dev/null 2>&1; then
            version=$(curl -s https://transmissionbt.com/download | grep -oP 'transmission-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1 2>/dev/null)
        elif command -v wget >/dev/null 2>&1; then
            version=$(wget -qO- https://transmissionbt.com/download | grep -oP 'transmission-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1 2>/dev/null)
        fi
    fi

    # Hardcoded fallback if all detection methods fail
    if [ -z "$version" ]; then
        version="4.1.0"
    fi

    echo "$version"
}

# Function to check if Transmission is installed
is_transmission_installed() {
    if command -v transmission-daemon >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get installed version
get_installed_version() {
    if is_transmission_installed; then
        transmission-daemon --version 2>&1 | head -1 | awk '{print $2}'
    else
        echo "Not installed"
    fi
}

# Function to detect OS and install dependencies
install_dependencies() {
    print_message "$BLUE" "Detecting operating system..."

    # Detect OS type
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi

    print_message "$GREEN" "Detected OS: $OS $VER"
    print_message "$BLUE" "Installing build dependencies..."

    case $OS in
        ubuntu|debian|linuxmint|pop|raspbian)
            # Debian/Ubuntu and derivatives
            print_message "$YELLOW" "Using apt package manager..."
            sudo apt-get update
            sudo apt-get -y install build-essential checkinstall pkg-config libtool intltool \
                libcurl4-openssl-dev libssl-dev libevent-dev wget curl cmake
            sudo sed -i 's/TRANSLATE=1/TRANSLATE=0/' /etc/checkinstallrc 2>/dev/null || true
            ;;

        fedora|centos|rhel|rocky|almalinux)
            # Red Hat/Fedora derivatives
            print_message "$YELLOW" "Using yum/dnf package manager..."
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf -y groupinstall "Development Tools"
                sudo dnf -y install checkinstall libtool intltool libcurl-devel openssl-devel \
                    libevent-devel wget curl cmake
            else
                sudo yum -y groupinstall "Development Tools"
                sudo yum -y install checkinstall libtool intltool libcurl-devel openssl-devel \
                    libevent-devel wget curl cmake
            fi
            ;;

        arch|manjaro)
            # Arch Linux derivatives
            print_message "$YELLOW" "Using pacman package manager..."
            sudo pacman -Sy --noconfirm base-devel checkinstall libtool intltool curl openssl \
                libevent wget cmake
            ;;

        opensuse*|suse)
            # openSUSE
            print_message "$YELLOW" "Using zypper package manager..."
            sudo zypper --non-interactive install -t pattern devel_basis
            sudo zypper --non-interactive install checkinstall libtool intltool libcurl-devel \
                libopenssl-devel libevent-devel wget curl cmake
            ;;

        alpine)
            # Alpine Linux
            print_message "$YELLOW" "Using apk package manager..."
            sudo apk add build-base checkinstall libtool intltool curl-dev openssl-dev \
                libevent-dev wget curl cmake
            ;;

        *)
            # Unknown OS - try common package managers
            print_message "$YELLOW" "Unknown OS: $OS. Trying common package managers..."

            # Try apt (Debian/Ubuntu)
            if command -v apt-get >/dev/null 2>&1; then
                print_message "$YELLOW" "Found apt package manager..."
                sudo apt-get update
                sudo apt-get -y install build-essential checkinstall pkg-config libtool intltool \
                    libcurl4-openssl-dev libssl-dev libevent-dev wget curl cmake
                sudo sed -i 's/TRANSLATE=1/TRANSLATE=0/' /etc/checkinstallrc 2>/dev/null || true

            # Try yum/dnf (RHEL/Fedora)
            elif command -v dnf >/dev/null 2>&1; then
                print_message "$YELLOW" "Found dnf package manager..."
                sudo dnf -y groupinstall "Development Tools"
                sudo dnf -y install checkinstall libtool intltool libcurl-devel openssl-devel \
                    libevent-devel wget curl cmake
            elif command -v yum >/dev/null 2>&1; then
                print_message "$YELLOW" "Found yum package manager..."
                sudo yum -y groupinstall "Development Tools"
                sudo yum -y install checkinstall libtool intltool libcurl-devel openssl-devel \
                    libevent-devel wget curl cmake

            # Try pacman (Arch)
            elif command -v pacman >/dev/null 2>&1; then
                print_message "$YELLOW" "Found pacman package manager..."
                sudo pacman -Sy --noconfirm base-devel checkinstall libtool intltool curl openssl \
                    libevent wget cmake

            # Try zypper (openSUSE)
            elif command -v zypper >/dev/null 2>&1; then
                print_message "$YELLOW" "Found zypper package manager..."
                sudo zypper --non-interactive install -t pattern devel_basis
                sudo zypper --non-interactive install checkinstall libtool intltool libcurl-devel \
                    libopenssl-devel libevent-devel wget curl cmake

            # Try apk (Alpine)
            elif command -v apk >/dev/null 2>&1; then
                print_message "$YELLOW" "Found apk package manager..."
                sudo apk add build-base checkinstall libtool intltool curl-dev openssl-dev \
                    libevent-dev wget curl cmake

            else
                print_message "$RED" "✗ Could not detect package manager. Please install dependencies manually:"
                print_message "$YELLOW" "Required packages: build-essential, checkinstall, pkg-config, libtool, intltool,"
                print_message "$YELLOW" "libcurl, openssl, libevent, wget, curl, and cmake"
                exit 1
            fi
            ;;
    esac

    # Verify CMake installation
    if command -v cmake >/dev/null 2>&1; then
        CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
        print_message "$GREEN" "✓ CMake version $CMAKE_VERSION installed successfully"
    else
        print_message "$YELLOW" "CMake installation via package manager failed, attempting manual install..."
        install_cmake_manually
    fi

    print_message "$GREEN" "✓ Dependencies installed successfully"
}

# Function to manually install CMake if package manager fails
install_cmake_manually() {
    print_message "$BLUE" "Installing CMake manually..."

    # Check if wget is available
    if ! command -v wget >/dev/null 2>&1; then
        print_message "$RED" "wget not found. Please install wget first."
        exit 1
    fi

    # Download and install latest CMake version
    cd /tmp
    CMAKE_VERSION="3.27.7"  # Latest stable as of writing

    # Try to get the latest version dynamically
    LATEST_CMAKE=$(wget -qO- https://cmake.org/files/LatestRelease/cmake-latest-linux-x86_64.sh | grep -oP 'cmake-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$LATEST_CMAKE" ]; then
        CMAKE_VERSION=$LATEST_CMAKE
    fi

    print_message "$YELLOW" "Downloading CMake $CMAKE_VERSION..."

    # Try different architecture options
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz"
            ;;
        aarch64)
            CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz"
            ;;
        armv7l)
            CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-armv7l.tar.gz"
            ;;
        *)
            print_message "$RED" "Unknown architecture: $ARCH. Please install CMake manually."
            exit 1
            ;;
    esac

    if wget --timeout=30 --tries=3 "$CMAKE_URL"; then
        print_message "$GREEN" "Downloaded CMake successfully"

        # Extract to /opt
        sudo tar -xzf "cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz" -C /opt

        # Create symlinks
        sudo ln -sf "/opt/cmake-${CMAKE_VERSION}-linux-${ARCH}/bin/cmake" /usr/local/bin/cmake
        sudo ln -sf "/opt/cmake-${CMAKE_VERSION}-linux-${ARCH}/bin/ccmake" /usr/local/bin/ccmake
        sudo ln -sf "/opt/cmake-${CMAKE_VERSION}-linux-${ARCH}/bin/cpack" /usr/local/bin/cpack
        sudo ln -sf "/opt/cmake-${CMAKE_VERSION}-linux-${ARCH}/bin/ctest" /usr/local/bin/ctest

        # Clean up
        rm -f "cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz"

        # Verify installation
        if command -v cmake >/dev/null 2>&1; then
            CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
            print_message "$GREEN" "✓ CMake $CMAKE_VERSION installed manually"
        else
            print_message "$RED" "✗ Manual CMake installation failed"
            exit 1
        fi
    else
        print_message "$RED" "Failed to download CMake. Please install it manually:"
        print_message "$YELLOW" "sudo apt install cmake  # For Debian/Ubuntu"
        print_message "$YELLOW" "sudo yum install cmake  # For RHEL/CentOS"
        print_message "$YELLOW" "sudo dnf install cmake  # For Fedora"
        print_message "$YELLOW" "sudo pacman -S cmake    # For Arch"
        exit 1
    fi
}

# Function to download and compile Transmission
# Function to download and compile Transmission
install_transmission() {
    local version=$1
    local version_clean=$(echo "$version" | sed 's/^v//')  # Remove 'v' prefix if present
    local download_success=false
    local filename=""
    local downloaded_file=""

    print_message "$GREEN" "======================================================"
    print_message "$GREEN" "Installing Transmission version ${version_clean}"
    print_message "$GREEN" "======================================================"

    cd ~
    # Clean up any previous attempts
    sudo rm -rf "transmission-${version_clean}" 2>/dev/null || true
    rm -f transmission-${version_clean}.tar.* 2>/dev/null || true

    # Array of download URLs to try (in order of preference)
    download_urls=(
        "https://github.com/transmission/transmission/releases/download/${version_clean}/transmission-${version_clean}.tar.xz"
        "https://github.com/transmission/transmission/releases/download/v${version_clean}/transmission-${version_clean}.tar.xz"
        "https://github.com/transmission/transmission-releases/raw/master/transmission-${version_clean}.tar.xz"
        "https://github.com/transmission/transmission/archive/refs/tags/${version_clean}.tar.gz"
        "https://github.com/transmission/transmission/archive/refs/tags/v${version_clean}.tar.gz"
        "https://download.transmissionbt.com/files/transmission-${version_clean}.tar.xz"
    )

    print_message "$BLUE" "Downloading Transmission ${version_clean}..."

    # Try each URL until one works
    for url in "${download_urls[@]}"; do
        print_message "$YELLOW" "Trying: $url"

        # Determine output filename based on URL
        if [[ "$url" == *.tar.xz ]]; then
            output_file="transmission-${version_clean}.tar.xz"
        else
            output_file="transmission-${version_clean}.tar.gz"
        fi

        # Try to download with wget (follow redirects, show progress)
        if wget --timeout=30 --tries=3 --retry-connrefused --progress=bar -O "$output_file" "$url" 2>&1; then
            # Verify file exists and has content
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
                if [ "$file_size" -gt 1000000 ]; then  # Larger than 1MB is good
                    print_message "$GREEN" "✓ Successfully downloaded from: $url (Size: $file_size bytes)"
                    download_success=true
                    downloaded_file="$output_file"
                    break
                else
                    print_message "$YELLOW" "File too small (${file_size} bytes), might be error page"
                    rm -f "$output_file" 2>/dev/null
                fi
            else
                print_message "$RED" "✗ Downloaded file is empty or corrupted"
                rm -f "$output_file" 2>/dev/null
            fi
        else
            print_message "$RED" "✗ Download failed"
            rm -f "$output_file" 2>/dev/null
        fi
    done

    # If all URLs failed, try with curl as fallback
    if [ "$download_success" = false ] && command -v curl >/dev/null 2>&1; then
        print_message "$YELLOW" "Trying curl as fallback..."
        for url in "${download_urls[@]}"; do
            print_message "$YELLOW" "Curl trying: $url"

            if [[ "$url" == *.tar.xz ]]; then
                output_file="transmission-${version_clean}.tar.xz"
            else
                output_file="transmission-${version_clean}.tar.gz"
            fi

            if curl -L --connect-timeout 30 --retry 3 -o "$output_file" "$url" 2>/dev/null; then
                if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                    file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
                    if [ "$file_size" -gt 1000000 ]; then
                        print_message "$GREEN" "✓ Successfully downloaded with curl from: $url (Size: $file_size bytes)"
                        download_success=true
                        downloaded_file="$output_file"
                        break
                    else
                        rm -f "$output_file" 2>/dev/null
                    fi
                fi
            fi
        done
    fi

    # Final check if download succeeded
    if [ "$download_success" = false ]; then
        print_message "$RED" "======================================================"
        print_message "$RED" "✗ FAILED TO DOWNLOAD TRANSMISSION"
        print_message "$RED" "======================================================"
        print_message "$YELLOW" "Please try one of these methods manually:"
        print_message "$YELLOW" "1. Download from: https://transmissionbt.com/download"
        print_message "$YELLOW" "2. Clone the repository:"
        print_message "$YELLOW" "   git clone https://github.com/transmission/transmission.git"
        print_message "$YELLOW" "   cd transmission"
        print_message "$YELLOW" "   git checkout ${version_clean}"
        print_message "$YELLOW" "3. Use your distribution's package manager:"
        print_message "$YELLOW" "   sudo apt install transmission-daemon"
        exit 1
    fi

    # Extract the archive
    print_message "$BLUE" "Extracting files from ${downloaded_file}..."

    local extract_dir=""
    if [[ "$downloaded_file" == *.tar.xz ]]; then
        if tar -xf "$downloaded_file"; then
            extract_dir="transmission-${version_clean}"
            print_message "$GREEN" "✓ Extracted .tar.xz archive"
        else
            print_message "$RED" "✗ Failed to extract .tar.xz archive"
            exit 1
        fi
    elif [[ "$downloaded_file" == *.tar.gz ]]; then
        if tar -xzf "$downloaded_file"; then
            # The extracted directory name might be different
            if [ -d "transmission-${version_clean}" ]; then
                extract_dir="transmission-${version_clean}"
            elif [ -d "transmission-${version_clean#v}" ]; then
                extract_dir="transmission-${version_clean#v}"
            else
                # Try to find any transmission directory
                extract_dir=$(find . -maxdepth 1 -type d -name "transmission*" | head -1 | sed 's|^\./||')
            fi
            print_message "$GREEN" "✓ Extracted .tar.gz archive to: $extract_dir"
        else
            print_message "$RED" "✗ Failed to extract .tar.gz archive"
            exit 1
        fi
    fi

    # Navigate to extracted directory
    if [ -n "$extract_dir" ] && [ -d "$extract_dir" ]; then
        cd "$extract_dir"
    elif [ -d "transmission-${version_clean}" ]; then
        cd "transmission-${version_clean}"
    elif [ -d "transmission-${version_clean#v}" ]; then
        cd "transmission-${version_clean#v}"
    else
        # Last resort: find any directory with transmission in the name
        extract_dir=$(find . -maxdepth 1 -type d -name "transmission*" ! -name "*.tar.*" | head -1 | sed 's|^\./||')
        if [ -n "$extract_dir" ] && [ -d "$extract_dir" ]; then
            cd "$extract_dir"
        else
            print_message "$RED" "✗ Could not find extracted directory"
            ls -la
            exit 1
        fi
    fi

    print_message "$GREEN" "✓ Changed to directory: $(pwd)"

    # Check if we have source files
    if [ ! -f "configure" ] && [ ! -f "CMakeLists.txt" ]; then
        print_message "$YELLOW" "Warning: No configure script found. Listing directory contents:"
        ls -la
        print_message "$YELLOW" "This might not be the correct source directory."
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message "$RED" "Installation cancelled."
            exit 1
        fi
    fi

    # Compile and install - FIXED VERSION
    print_message "$BLUE" "Configuring build..."

    # Try different build systems
    if [ -f "./configure" ]; then
        # Traditional autotools build
        ./configure
        print_message "$BLUE" "Compiling (this may take a while)..."
        make -j$(nproc)
        print_message "$BLUE" "Installing..."
        if command -v checkinstall >/dev/null 2>&1; then
            sudo checkinstall -y --pkgname=transmission --pkgversion="${version_clean}" --default
        else
            sudo make install
        fi
    elif [ -f "CMakeLists.txt" ]; then
        # CMake build
        mkdir -p build
        cd build
        cmake ..
        print_message "$BLUE" "Compiling (this may take a while)..."
        make -j$(nproc)
        print_message "$BLUE" "Installing..."
        if command -v checkinstall >/dev/null 2>&1; then
            # checkinstall doesn't work well with out-of-tree builds, so use make install
            sudo make install
        else
            sudo make install
        fi
        cd ..
    else
        print_message "$RED" "No configure script or CMakeLists.txt found"
        exit 1
    fi

    cd ~

    # Cleanup
    rm -f transmission-${version_clean}.tar.* 2>/dev/null || true
    sudo rm -rf "transmission-${version_clean}" 2>/dev/null || true

    print_message "$GREEN" "✓ Transmission ${version_clean} installed successfully"
}

# Function to create transmission user
create_transmission_user() {
    if [ ! $(grep "^${TRANSMISSION_USER}:" /etc/passwd) ]; then
        print_message "$BLUE" "Creating transmission user..."
        sudo adduser --disabled-password --disabled-login --gecos "" ${TRANSMISSION_USER}
    else
        print_message "$YELLOW" "Transmission user already exists"
    fi
}

# Function to setup init script
setup_init_script() {
    print_message "$BLUE" "Setting up init script..."

    # Extract init script from this file
    tail -n +$(($(grep -n "^#initdscript#" "$SCRIPT"|grep -Eo '^[^:]+')+1)) "$SCRIPT" | sudo tee ${INIT_SCRIPT} >/dev/null

    # Update the USERNAME in the init script if needed
    sudo sed -i "s/USERNAME=transmission/USERNAME=${TRANSMISSION_USER}/" ${INIT_SCRIPT}

    sudo chmod +x ${INIT_SCRIPT}
    sudo update-rc.d transmission-daemon defaults

    print_message "$GREEN" "✓ Init script installed"
}

# Function to generate a random password and its hash
generate_transmission_password() {
    local password_length=${1:-16}  # Default 16 characters
    local plain_password=""
    local salt=""
    local hash=""

    print_message "$BLUE" "Generating random Transmission password..."

    # Generate random password (alphanumeric + special chars)
    if command -v openssl >/dev/null 2>&1; then
        plain_password=$(openssl rand -base64 12 | tr -d '\n' | tr -d '=' | tr '+' '.' | tr '/' '_')
    elif [ -f /dev/urandom ]; then
        plain_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c "$password_length")
    else
        # Fallback to simple random generation
        plain_password=$(date +%s%N | sha256sum | base64 | head -c "$password_length")
    fi

    # Generate random 8-character salt
    if command -v openssl >/dev/null 2>&1; then
        salt=$(openssl rand -base64 8 | tr -d '\n' | tr -d '=' | tr '+' '.' | tr '/' '_' | head -c 8)
    else
        salt=$(cat /dev/urandom 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c 8 || echo "RandSalt")
    fi

    # Make sure salt is exactly 8 characters
    while [ ${#salt} -lt 8 ]; do
        salt="${salt}0"
    done
    salt=$(echo "$salt" | cut -c1-8)

    # Create the hash (SHA1 of password + salt)
    if command -v openssl >/dev/null 2>&1; then
        hash=$(echo -n "${plain_password}${salt}" | openssl sha1 | awk '{print $2}')
    else
        # Fallback to a simple hash (less secure but works)
        hash=$(echo -n "${plain_password}${salt}" | sha256sum 2>/dev/null | cut -c1-40 || echo "0000000000000000000000000000000000000000")
    fi

    # Format as Transmission expects: {hash}{salt}
    local transmission_hash="{${hash}${salt}}"

    echo "$transmission_hash:$plain_password"
}

# Function to set a random RPC password
set_random_rpc_password() {
    print_message "$BLUE" "=== Set Random RPC Password ==="

    # Generate password and hash
    local result=$(generate_transmission_password 16)
    local transmission_hash=$(echo "$result" | cut -d: -f1)
    local plain_password=$(echo "$result" | cut -d: -f2)

    print_message "$GREEN" "Generated random password: $plain_password"
    print_message "$YELLOW" "Hash: $transmission_hash"

    # Set the password
    set_rpc_password "$transmission_hash"

    # Save password to file for reference
    local password_file="${TRANSMISSION_HOME}/rpc_password.txt"
    echo "Transmission RPC Password" | sudo tee "$password_file" >/dev/null
    echo "Generated on: $(date)" | sudo tee -a "$password_file" >/dev/null
    echo "Password: $plain_password" | sudo tee -a "$password_file" >/dev/null
    echo "Hash: $transmission_hash" | sudo tee -a "$password_file" >/dev/null
    sudo chmod 600 "$password_file"
    sudo chown ${TRANSMISSION_USER}:${TRANSMISSION_USER} "$password_file" 2>/dev/null || true

    print_message "$GREEN" "✓ Password saved to: $password_file"
}

# Function to manually set a password (let Transmission hash it)
set_plain_rpc_password() {
    local plain_password=$1
    local settings_file="${TRANSMISSION_HOME}/settings.json"

    print_message "$BLUE" "Setting plain text RPC password..."

    if [ ! -f "$settings_file" ]; then
        print_message "$RED" "Settings file not found. Install Transmission first."
        return 1
    fi

    # Backup settings
    sudo cp "$settings_file" "${settings_file}.backup"

    # Stop Transmission
    if pgrep -f "transmission-daemon" >/dev/null 2>&1; then
        print_message "$YELLOW" "Stopping Transmission..."
        sudo ${INIT_SCRIPT} stop 2>/dev/null || true
        sleep 2
    fi

    # Update with plain text password (Transmission will hash it on next start)
    if command -v jq >/dev/null 2>&1; then
        sudo jq --arg pass "$plain_password" '. + {"rpc-password": $pass}' "$settings_file" > /tmp/settings.json.tmp
        sudo mv /tmp/settings.json.tmp "$settings_file"
    else
        sudo sed -i "s/\"rpc-password\": \".*\"/\"rpc-password\": \"${plain_password}\"/" "$settings_file"
    fi

    sudo chown ${TRANSMISSION_USER}:${TRANSMISSION_USER} "$settings_file" 2>/dev/null || true

    # Start Transmission (it will hash the password automatically)
    print_message "$YELLOW" "Starting Transmission to hash the password..."
    sudo ${INIT_SCRIPT} start 2>/dev/null || true
    sleep 3

    # Stop again to see the hashed password
    sudo ${INIT_SCRIPT} stop 2>/dev/null || true
    sleep 2

    # Show the new hash
    print_message "$GREEN" "✓ Password set. New hash in settings.json:"
    grep '"rpc-password"' "$settings_file"
}

# Function to start/stop Transmission to create config
initialize_config() {
    print_message "$BLUE" "Initializing Transmission configuration..."
    sudo ${INIT_SCRIPT} start
    sleep 3
    sudo ${INIT_SCRIPT} stop
    sleep 2
    print_message "$GREEN" "✓ Configuration initialized at ${TRANSMISSION_HOME}/settings.json"
}

# Main installation function
do_install() {
    print_message "$GREEN" "=== Starting Transmission Installation ==="

    # Check if already installed
    if is_transmission_installed; then
        local installed_ver=$(get_installed_version)
        print_message "$YELLOW" "Transmission ${installed_ver} is already installed."
        read -p "Do you want to reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message "$YELLOW" "Installation cancelled."
            return
        fi
    fi

    # Install dependencies
    install_dependencies

    # Detect latest version (call once and store)
    print_message "$BLUE" "Detecting latest Transmission version..."
    LATEST_VERSION=$(get_latest_version)
    print_message "$GREEN" "Latest Transmission version detected: ${LATEST_VERSION}"

    # Ask for version to install
    read -p "Install version ${LATEST_VERSION}? (y/n - enter 'c' to custom version): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Cc]$ ]]; then
        read -p "Enter version number (e.g., 4.1.0): " CUSTOM_VERSION
        VERSION_TO_INSTALL=$CUSTOM_VERSION
    elif [[ $REPLY =~ ^[Yy]$ ]]; then
        VERSION_TO_INSTALL=$LATEST_VERSION
    else
        print_message "$YELLOW" "Installation cancelled."
        return
    fi

    # Install Transmission
    install_transmission "${VERSION_TO_INSTALL}"

    # Create user
    create_transmission_user

    # Setup init script
    setup_init_script

    # Initialize config
    initialize_config

    print_message "$GREEN" "======================================================"
    print_message "$GREEN" "✅ Transmission ${VERSION_TO_INSTALL} installation complete!"
    print_message "$GREEN" "======================================================"
    print_message "$YELLOW" "Settings file: ${TRANSMISSION_HOME}/settings.json"
    print_message "$YELLOW" ""
    print_message "$YELLOW" "To start Transmission: sudo ${INIT_SCRIPT} start"
    print_message "$YELLOW" "To stop Transmission:  sudo ${INIT_SCRIPT} stop"
    print_message "$YELLOW" "To restart:           sudo ${INIT_SCRIPT} restart"
    print_message "$GREEN" "======================================================"
}

# Function to set RPC password
set_rpc_password() {
    local password_hash=$1
    local settings_file="${TRANSMISSION_HOME}/settings.json"

    print_message "$BLUE" "Setting RPC password..."

    # Check if settings file exists
    if [ ! -f "$settings_file" ]; then
        print_message "$YELLOW" "Settings file not found. Starting Transmission to create it..."
        sudo ${INIT_SCRIPT} start 2>/dev/null || true
        sleep 3
        sudo ${INIT_SCRIPT} stop 2>/dev/null || true
        sleep 2
    fi

    if [ -f "$settings_file" ]; then
        # Backup the original settings
        sudo cp "$settings_file" "${settings_file}.backup"
        print_message "$GREEN" "✓ Backup created at ${settings_file}.backup"

        # Stop Transmission if running
        if pgrep -f "transmission-daemon" >/dev/null 2>&1; then
            print_message "$YELLOW" "Stopping Transmission to modify settings..."
            sudo ${INIT_SCRIPT} stop 2>/dev/null || true
            sleep 2
        fi

        # Update the password in settings.json
        print_message "$YELLOW" "Updating rpc-password in settings.json..."

        # Use jq if available, otherwise use sed
        if command -v jq >/dev/null 2>&1; then
            # jq provides cleaner JSON manipulation
            sudo jq --arg pass "$password_hash" '. + {"rpc-password": $pass}' "$settings_file" > /tmp/settings.json.tmp
            sudo mv /tmp/settings.json.tmp "$settings_file"
            sudo chown ${TRANSMISSION_USER}:${TRANSMISSION_USER} "$settings_file" 2>/dev/null || true
            print_message "$GREEN" "✓ Password updated using jq"
        else
            # Fallback to sed (less reliable but works)
            print_message "$YELLOW" "jq not found, using sed for JSON manipulation (may be less reliable)"

            # Check if rpc-password exists in the file
            if grep -q '"rpc-password"' "$settings_file"; then
                # Replace existing password
                sudo sed -i "s/\"rpc-password\": \".*\"/\"rpc-password\": \"${password_hash}\"/" "$settings_file"
            else
                # Insert password before the last }
                sudo sed -i "s/\(.*\)}/\1,\n    \"rpc-password\": \"${password_hash}\"\n}/" "$settings_file"
            fi
            print_message "$GREEN" "✓ Password updated using sed"
        fi

        # Fix permissions
        sudo chown ${TRANSMISSION_USER}:${TRANSMISSION_USER} "$settings_file" 2>/dev/null || true
        sudo chmod 600 "$settings_file" 2>/dev/null || true

        print_message "$GREEN" "✓ RPC password configured successfully"
        print_message "$YELLOW" "Password hash: ${password_hash}"

        # Restart Transmission to apply changes
        print_message "$BLUE" "Restarting Transmission to apply changes..."
        sudo ${INIT_SCRIPT} start 2>/dev/null || true
        sleep 2

        # Verify the password was set correctly
        if grep -q "$password_hash" "$settings_file"; then
            print_message "$GREEN" "✓ Password verified in settings file"
        else
            print_message "$RED" "✗ Password may not have been set correctly"
        fi
    else
        print_message "$RED" "✗ Settings file still not found at: $settings_file"
        print_message "$YELLOW" "Please check Transmission installation"
    fi
}

# Function to uninstall Transmission
do_uninstall() {
    print_message "$RED" "=== Transmission Uninstallation ==="

    if ! is_transmission_installed; then
        print_message "$YELLOW" "Transmission is not installed."
        return
    fi

    local installed_ver=$(get_installed_version)
    print_message "$YELLOW" "Transmission ${installed_ver} is currently installed."

    # Confirm uninstallation
    read -p "Are you sure you want to uninstall Transmission? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "$YELLOW" "Uninstallation cancelled."
        return
    fi

    # Stop service if running
    print_message "$BLUE" "Stopping Transmission service..."
    if [ -f "${INIT_SCRIPT}" ]; then
        sudo ${INIT_SCRIPT} stop 2>/dev/null || true
        sleep 2
    fi

    # Remove from startup
    print_message "$BLUE" "Removing from startup..."
    if [ -f "${INIT_SCRIPT}" ]; then
        sudo update-rc.d transmission-daemon remove 2>/dev/null || true
        sudo rm -f "${INIT_SCRIPT}"
    fi

    # Remove binary and related files
    print_message "$BLUE" "Removing Transmission binaries..."
    # Try to remove using checkinstall package
    if dpkg -l | grep -q transmission; then
        sudo dpkg -r transmission 2>/dev/null || true
    fi

    # Manually remove binary files
    sudo rm -f /usr/local/bin/transmission-* 2>/dev/null || true
    sudo rm -rf /usr/local/share/transmission 2>/dev/null || true
    sudo rm -rf /usr/local/share/doc/transmission* 2>/dev/null || true

    # Ask about config and user data
    print_message "$YELLOW" "Do you want to remove the transmission user and configuration?"
    read -p "Remove user ${TRANSMISSION_USER} and all data? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Kill any remaining processes
        sudo pkill -u ${TRANSMISSION_USER} 2>/dev/null || true

        # Remove user and home directory
        sudo userdel -r ${TRANSMISSION_USER} 2>/dev/null || true
        sudo rm -rf /home/${TRANSMISSION_USER} 2>/dev/null || true
        print_message "$GREEN" "✓ Transmission user and data removed"
    else
        print_message "$YELLOW" "User ${TRANSMISSION_USER} and configuration kept"
    fi

    print_message "$GREEN" "✓ Transmission has been uninstalled"
}

# Function to show status
show_status() {
    print_message "$BLUE" "=== Transmission Status ==="

    if is_transmission_installed; then
        local installed_ver=$(get_installed_version)
        print_message "$GREEN" "Installed version: ${installed_ver}"

        # Check if service is running - FIXED VERSION
        if [ -f "${INIT_SCRIPT}" ]; then
            if sudo ${INIT_SCRIPT} status 2>/dev/null | grep -q "running"; then
                print_message "$GREEN" "Service status: Running"
            else
                # Check if process is running directly (using -f for full command line)
                if pgrep -f "transmission-daemon" >/dev/null 2>&1; then
                    print_message "$GREEN" "Service status: Running (process exists)"
                else
                    print_message "$YELLOW" "Service status: Not running"
                fi
            fi
        else
            # Check if process is running directly (using -f for full command line)
            if pgrep -f "transmission-daemon" >/dev/null 2>&1; then
                print_message "$GREEN" "Service status: Running (process exists, no init script)"
            else
                print_message "$YELLOW" "Service status: Not running"
            fi
        fi

        # Check config file
        if [ -f "${TRANSMISSION_HOME}/settings.json" ]; then
            print_message "$GREEN" "Config file: ${TRANSMISSION_HOME}/settings.json"

            # Optional: Show some basic config info
            print_message "$BLUE" "Configuration preview:"
            echo "----------------------------------------"
            grep -E '"rpc-port"|"rpc-enabled"|"download-dir"' "${TRANSMISSION_HOME}/settings.json" | head -3
            echo "----------------------------------------"
        else
            print_message "$YELLOW" "Config file: Not found"
        fi

        # Check user
        if grep -q "^${TRANSMISSION_USER}:" /etc/passwd; then
            print_message "$GREEN" "User ${TRANSMISSION_USER}: Exists"

            # Show user ID and groups
            USER_ID=$(id -u ${TRANSMISSION_USER} 2>/dev/null)
            USER_GID=$(id -g ${TRANSMISSION_USER} 2>/dev/null)
            print_message "$BLUE" "  UID: $USER_ID, GID: $USER_GID"
        else
            print_message "$YELLOW" "User ${TRANSMISSION_USER}: Not found"
        fi

    else
        print_message "$YELLOW" "Transmission is not installed"
    fi

    # Show latest available version
    print_message "$BLUE" "Detecting latest available version..."
    LATEST_VERSION=$(get_latest_version)
    print_message "$BLUE" "Latest available version: ${LATEST_VERSION}"

    # Show system info
    print_message "$BLUE" "System information:"
    echo "----------------------------------------"
    echo "OS: $(uname -s) $(uname -r)"
    echo "Architecture: $(uname -m)"
    if command -v transmission-daemon >/dev/null 2>&1; then
        echo "Transmission binary: $(which transmission-daemon)"
    fi
    echo "----------------------------------------"
}

# Function to show menu
show_menu() {
    clear
    print_message "$BLUE" "╔════════════════════════════════════════╗"
    print_message "$BLUE" "║    Transmission Seedbox Manager        ║"
    print_message "$BLUE" "╚════════════════════════════════════════╝"
    echo ""

    # Show current status
    if is_transmission_installed; then
        local installed_ver=$(get_installed_version)
        print_message "$GREEN" "Current: Transmission ${installed_ver} installed"

        # Check if newer version available
        print_message "$BLUE" "Checking for updates..."
        LATEST_VERSION=$(get_latest_version)
        if [ "${installed_ver}" != "${LATEST_VERSION}" ]; then
            print_message "$YELLOW" "Update available: ${LATEST_VERSION}"
        else
            print_message "$GREEN" "You have the latest version"
        fi
    else
        print_message "$YELLOW" "Current: Transmission not installed"
    fi
    echo ""

    print_message "$GREEN" "Menu Options:"
    echo "1) Install Transmission"
    echo "2) Uninstall Transmission"
    echo "3) Show Status"
    echo "4) Start Service"
    echo "5) Stop Service"
    echo "6) Restart Service"
    echo "7) View Config Location"
    echo "8) Set Custom RPC Password Hash"
    echo "9) Generate Random RPC Password"
    echo "10) Set Plain Text RPC Password"
    echo "11) Exit"
    echo ""
    read -p "Select option [1-11]: " menu_choice
}

# Function to start service
start_service() {
    if [ -f "${INIT_SCRIPT}" ]; then
        print_message "$BLUE" "Starting Transmission service..."
        sudo ${INIT_SCRIPT} start

        # Wait a moment and check if it started
        sleep 2
        if pgrep -f "transmission-daemon" >/dev/null 2>&1; then
            print_message "$GREEN" "✓ Transmission started successfully"
        else
            print_message "$YELLOW" "Service may not have started. Check with: sudo ${INIT_SCRIPT} status"
        fi
    else
        print_message "$RED" "Init script not found. Transmission may not be installed."

        # Try to start directly if binary exists
        if command -v transmission-daemon >/dev/null 2>&1; then
            print_message "$YELLOW" "Attempting to start transmission-daemon directly..."
            sudo -u ${TRANSMISSION_USER} transmission-daemon
            sleep 2
            if pgrep -f "transmission-daemon" >/dev/null 2>&1; then
                print_message "$GREEN" "✓ Transmission started successfully"
            else
                print_message "$RED" "Failed to start transmission-daemon"
            fi
        fi
    fi
}

# Function to stop service
stop_service() {
    if [ -f "${INIT_SCRIPT}" ]; then
        print_message "$BLUE" "Stopping Transmission service..."
        sudo ${INIT_SCRIPT} stop

        # Wait a moment and check if it stopped
        sleep 2
        if ! pgrep -f "transmission-daemon" >/dev/null 2>&1; then
            print_message "$GREEN" "✓ Transmission stopped successfully"
        else
            print_message "$YELLOW" "Service may still be running. Force kill? (y/n): "
            read -n 1 -r force_kill
            echo
            if [[ $force_kill =~ ^[Yy]$ ]]; then
                sudo pkill -f "transmission-daemon"
                sleep 1
                if ! pgrep -f "transmission-daemon" >/dev/null 2>&1; then
                    print_message "$GREEN" "✓ Transmission force-stopped"
                else
                    print_message "$RED" "Could not stop Transmission"
                fi
            fi
        fi
    else
        print_message "$RED" "Init script not found. Transmission may not be installed."

        # Try to kill directly if binary exists
        if pgrep -f "transmission-daemon" >/dev/null 2>&1; then
            print_message "$YELLOW" "Attempting to kill transmission-daemon directly..."
            sudo pkill -f "transmission-daemon"
            sleep 2
            if ! pgrep -f "transmission-daemon" >/dev/null 2>&1; then
                print_message "$GREEN" "✓ Transmission stopped successfully"
            else
                print_message "$RED" "Failed to stop transmission-daemon"
            fi
        else
            print_message "$YELLOW" "Transmission is not running"
        fi
    fi
}

# Function to restart service
restart_service() {
    print_message "$BLUE" "Restarting Transmission service..."

    # Stop the service
    stop_service

    # Wait a moment
    sleep 3

    # Start the service
    start_service

    # Final status
    if pgrep -f "transmission-daemon" >/dev/null 2>&1; then
        print_message "$GREEN" "✓ Transmission restarted successfully"
    else
        print_message "$RED" "✗ Transmission failed to restart"
    fi
}

# Function to show config location
show_config() {
    if [ -f "${TRANSMISSION_HOME}/settings.json" ]; then
        print_message "$GREEN" "Configuration file: ${TRANSMISSION_HOME}/settings.json"
        print_message "$YELLOW" "To edit: sudo nano ${TRANSMISSION_HOME}/settings.json"
        print_message "$YELLOW" "After editing, restart the service: sudo ${INIT_SCRIPT} restart"
    else
        print_message "$YELLOW" "Configuration file not found. Install and start Transmission first."
    fi
}

# Main menu loop
main() {
    # Check if script is run with argument (for command-line usage)
    if [ "$1" = "install" ]; then
        do_install
        exit 0
    elif [ "$1" = "uninstall" ]; then
        do_uninstall
        exit 0
    elif [ "$1" = "status" ]; then
        show_status
        exit 0
    fi

    # Interactive menu
    while true; do
        show_menu

        case $menu_choice in
            1)
                do_install
                read -p "Press Enter to continue..."
                ;;
            2)
                do_uninstall
                read -p "Press Enter to continue..."
                ;;
            3)
                show_status
                read -p "Press Enter to continue..."
                ;;
            4)
                start_service
                read -p "Press Enter to continue..."
                ;;
            5)
                stop_service
                read -p "Press Enter to continue..."
                ;;
            6)
                restart_service
                read -p "Press Enter to continue..."
                ;;
            7)
                show_config
                read -p "Press Enter to continue..."
                ;;
            8)
                print_message "$BLUE" "=== Set Custom RPC Password Hash ==="
                read -p "Enter password hash (format: {hash}): " PASSWORD_HASH
                if [ -n "$PASSWORD_HASH" ]; then
                set_rpc_password "$PASSWORD_HASH"
                else
                print_message "$RED" "No password provided"
                fi
                read -p "Press Enter to continue..."
                ;;
            9)
                set_random_rpc_password
                read -p "Press Enter to continue..."
                ;;
            10)
                print_message "$BLUE" "=== Set Plain Text RPC Password ==="
                read -sp "Enter plain text password: " PLAIN_PASSWORD
                echo
                read -sp "Confirm password: " PLAIN_PASSWORD_CONFIRM
                echo
                if [ "$PLAIN_PASSWORD" = "$PLAIN_PASSWORD_CONFIRM" ] && [ -n "$PLAIN_PASSWORD" ]; then
                set_plain_rpc_password "$PLAIN_PASSWORD"
                else
                print_message "$RED" "Passwords do not match or are empty"
                fi
                read -p "Press Enter to continue..."
                ;;
            11)
                print_message "$GREEN" "Goodbye!"
                exit 0
                ;;
            *)
                print_message "$RED" "Invalid option. Please select 1-8"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Run main function with all arguments
main "$@"

exit 0


#initdscript#  (from `https://trac.transmissionbt.com/wiki/Scripts/initd` 2015.03.31)
#!/bin/sh
### BEGIN INIT INFO
# Provides:          transmission-daemon
# Required-Start:    networking
# Required-Stop:     networking
# Default-Start:     2 3 5
# Default-Stop:      0 1 6
# Short-Description: Start the transmission BitTorrent daemon client.
### END INIT INFO

# Original Author: Lennart A. J�Rtte, based on Rob Howell's script
# Modified by Maarten Van Coile & others (on IRC)

# Do NOT "set -e"

#
# ----- CONFIGURATION -----
#
# For the default location Transmission uses, visit:
# http://trac.transmissionbt.com/wiki/ConfigFiles
# For a guide on how set the preferences, visit:
# http://trac.transmissionbt.com/wiki/EditConfigFiles
# For the available environement variables, visit:
# http://trac.transmissionbt.com/wiki/EnvironmentVariables
#
# The name of the user that should run Transmission.
# It's RECOMENDED to run Transmission in it's own user,
# by default, this is set to 'transmission'.
# For the sake of security you shouldn't set a password
# on this user
USERNAME=transmission


# ----- *ADVANCED* CONFIGURATION -----
# Only change these options if you know what you are doing!
#
# The folder where Transmission stores the config & web files.
# ONLY change this you have it at a non-default location
#TRANSMISSION_HOME="/var/config/transmission-daemon"
#TRANSMISSION_WEB_HOME="/usr/share/transmission/web"
#
# The arguments passed on to transmission-daemon.
# ONLY change this you need to, otherwise use the
# settings file as per above.
#TRANSMISSION_ARGS=""


# ----- END OF CONFIGURATION -----
#
# PATH should only include /usr/* if it runs after the mountnfs.sh script.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
DESC="bittorrent client"
NAME=transmission-daemon
DAEMON=$(which $NAME)
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
[ -f /etc/default/rcS ] && . /etc/default/rcS

#
# Function that starts the daemon/service
#

do_start()
{
    # Export the configuration/web directory, if set
    if [ -n "$TRANSMISSION_HOME" ]; then
          export TRANSMISSION_HOME
    fi
    if [ -n "$TRANSMISSION_WEB_HOME" ]; then
          export TRANSMISSION_WEB_HOME
    fi

    # Return
    #   0 if daemon has been started
    #   1 if daemon was already running
    #   2 if daemon could not be started
    start-stop-daemon --chuid $USERNAME --start --pidfile $PIDFILE --make-pidfile \
            --exec $DAEMON --background --test -- -f $TRANSMISSION_ARGS > /dev/null \
            || return 1
    start-stop-daemon --chuid $USERNAME --start --pidfile $PIDFILE --make-pidfile \
            --exec $DAEMON --background -- -f $TRANSMISSION_ARGS \
            || return 2
}

#
# Function that stops the daemon/service
#
do_stop()
{
        # Return
        #   0 if daemon has been stopped
        #   1 if daemon was already stopped
        #   2 if daemon could not be stopped
        #   other if a failure occurred
        start-stop-daemon --stop --quiet --retry=TERM/10/KILL/5 --pidfile $PIDFILE --exec $DAEMON
        RETVAL="$?"
        [ "$RETVAL" = 2 ] && return 2

        # Wait for children to finish too if this is a daemon that forks
        # and if the daemon is only ever run from this initscript.
        # If the above conditions are not satisfied then add some other code
        # that waits for the process to drop all resources that could be
        # needed by services started subsequently.  A last resort is to
        # sleep for some time.

        start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
        [ "$?" = 2 ] && return 2

        # Many daemons don't delete their pidfiles when they exit.
        rm -f $PIDFILE

        return "$RETVAL"
}

case "$1" in
  start)
        echo "Starting $DESC" "$NAME..."
        do_start
        case "$?" in
                0|1) echo "   Starting $DESC $NAME succeeded" ;;
                *)   echo "   Starting $DESC $NAME failed" ;;
        esac
        ;;
  stop)
        echo "Stopping $DESC $NAME..."
        do_stop
        case "$?" in
                0|1) echo "   Stopping $DESC $NAME succeeded" ;;
                *)   echo "   Stopping $DESC $NAME failed" ;;
        esac
        ;;
  restart|force-reload)
        #
        # If the "reload" option is implemented then remove the
        # 'force-reload' alias
        #
        echo "Restarting $DESC $NAME..."
        do_stop
        case "$?" in
          0|1)
                do_start
                case "$?" in
                    0|1) echo "   Restarting $DESC $NAME succeeded" ;;
                    *)   echo "   Restarting $DESC $NAME failed: couldn't start $NAME" ;;
                esac
                ;;
          *)
                echo "   Restarting $DESC $NAME failed: couldn't stop $NAME" ;;
        esac
        ;;
  *)
        echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}" >&2
        exit 3
        ;;
esac
