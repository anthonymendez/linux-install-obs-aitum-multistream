#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status,
# if an unset variable is referenced, or if any pipeline fails.
set -euo pipefail

# Capture initial workspace path
WORKSPACE="$(pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
        info "Detected distribution: ${PRETTY_NAME:-$DISTRO_ID} ($DISTRO_ID)"
    else
        DISTRO_ID="unknown"
        DISTRO_LIKE=""
        warn "Could not read /etc/os-release. Unknown distribution."
    fi
}

# Dependency check for Arch Linux & Arch-based distros (e.g. CachyOS, Manjaro)
check_deps_arch() {
    info "Checking dependencies for Arch-based distribution..."
    local missing_deps=()
    local required_deps=("git" "cmake" "make" "gcc" "qt6-base" "obs-studio" "curl")
    
    for dep in "${required_deps[@]}"; do
        if ! pacman -Qq "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        warn "The following dependencies are missing: ${missing_deps[*]}"
        echo -n "Would you like to install them via pacman? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo pacman -S --needed "${missing_deps[@]}"
        else
            error "Cannot proceed without required dependencies."
            exit 1
        fi
    else
        success "All dependencies are installed."
    fi
}

# Stub/placeholder for Debian-based distros (e.g. Ubuntu, Mint)
check_deps_debian() {
    info "Checking dependencies for Debian-based distribution..."
    warn "Debian support is currently in the community contribution stage."
    warn "Ensure the following are installed: git, cmake, build-essential, qt6-base-dev, libobs-dev, libcurl4-openssl-dev."
    
    # FUTURE CONTRIBUTORS: Implement apt check and auto-installation here:
    # local missing_deps=()
    # ...
    # sudo apt-get update && sudo apt-get install -y "${missing_deps[@]}"
    
    echo -n "Proceed with the build assuming dependencies are manually satisfied? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        error "Build cancelled."
        exit 1
    fi
}

# Stub/placeholder for Fedora-based distros (e.g. RHEL, CentOS)
check_deps_fedora() {
    info "Checking dependencies for Fedora-based distribution..."
    warn "Fedora support is currently in the community contribution stage."
    warn "Ensure the following are installed: git, cmake, make, gcc-c++, qt6-qtbase-devel, obs-studio-devel, libcurl-devel."
    
    # FUTURE CONTRIBUTORS: Implement dnf check and auto-installation here:
    # local missing_deps=()
    # ...
    # sudo dnf install -y "${missing_deps[@]}"
    
    echo -n "Proceed with the build assuming dependencies are manually satisfied? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        error "Build cancelled."
        exit 1
    fi
}

# Route to appropriate dependency checker based on distro
verify_dependencies() {
    detect_distro
    
    if [[ "$DISTRO_ID" == "arch" || "$DISTRO_LIKE" == *"arch"* || "$DISTRO_ID" == "cachyos" ]]; then
        check_deps_arch
    elif [[ "$DISTRO_ID" == "debian" || "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *"debian"* || "$DISTRO_LIKE" == *"ubuntu"* ]]; then
        check_deps_debian
    elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_LIKE" == *"rhel"* || "$DISTRO_LIKE" == *"fedora"* ]]; then
        check_deps_fedora
    else
        warn "Unsupported or unknown distribution ($DISTRO_ID)."
        warn "Please ensure you have git, cmake, make, gcc, qt6 (development packages), obs-studio (with development headers), and libcurl installed."
        echo -n "Do you want to proceed with the build anyway? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            error "Build cancelled."
            exit 1
        fi
    fi
}

# Select installation directory based on preference and flatpak presence
select_install_target() {
    echo "--------------------------------------------------"
    echo "Please select an installation target directory:"
    echo "1) User Local (Recommended - ~/.config/obs-studio/plugins/)"
    echo "2) Flatpak User Local (~/.var/app/com.obsproject.Studio/config/obs-studio/plugins/)"
    echo "3) System-wide (Requires sudo - /usr/lib/obs-plugins/)"
    echo "--------------------------------------------------"
    
    # Auto-detect flatpak OBS to suggest it
    local default_choice="1"
    if command -v flatpak &>/dev/null && flatpak list --columns=application | grep -q "com.obsproject.Studio"; then
        info "Detected Flatpak installation of OBS Studio."
        default_choice="2"
    fi

    echo -n "Enter choice [1-3] (Default $default_choice): "
    read -r choice
    choice="${choice:-$default_choice}"

    case "$choice" in
        1)
            INSTALL_MODE="user"
            INSTALL_BIN_DIR="$HOME/.config/obs-studio/plugins/aitum-multistream/bin/64bit"
            INSTALL_DATA_DIR="$HOME/.config/obs-studio/plugins/aitum-multistream/data/locale"
            ;;
        2)
            INSTALL_MODE="flatpak"
            INSTALL_BIN_DIR="$HOME/.var/app/com.obsproject.Studio/config/obs-studio/plugins/aitum-multistream/bin/64bit"
            INSTALL_DATA_DIR="$HOME/.var/app/com.obsproject.Studio/config/obs-studio/plugins/aitum-multistream/data/locale"
            ;;
        3)
            INSTALL_MODE="system"
            INSTALL_BIN_DIR="/usr/lib/obs-plugins"
            INSTALL_DATA_DIR="/usr/share/obs/obs-plugins/aitum-multistream/locale"
            ;;
        *)
            error "Invalid choice: $choice"
            exit 1
            ;;
    esac

    info "Selected installation target binary directory: $INSTALL_BIN_DIR"
    info "Selected installation target locale directory: $INSTALL_DATA_DIR"
}

# Clone, patch, and build the repository
clone_and_build() {
    local temp_dir="build-aitum-multistream"
    info "Creating temporary build directory: $temp_dir"
    
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # Set exit trap to clean up build files automatically
    trap 'cd "$WORKSPACE" && rm -rf "$WORKSPACE/build-aitum-multistream"' EXIT

    info "Cloning https://github.com/Aitum/obs-aitum-multistream.git..."
    git clone --depth 1 -b main https://github.com/Aitum/obs-aitum-multistream.git
    cd obs-aitum-multistream

    info "Patching CMake configuration for Arch Linux compatibility..."
    if [ -f cmake/common/helpers_common.cmake ]; then
        sed -i 's/set_property(TARGET Qt::${component} PROPERTY INTERFACE_COMPILE_FEATURES "")/#set_property(TARGET Qt::${component} PROPERTY INTERFACE_COMPILE_FEATURES "")/' cmake/common/helpers_common.cmake
        success "Applied compile features patch."
    else
        warn "cmake/common/helpers_common.cmake not found. Skipping patch."
    fi

    info "Creating custom toolchain.cmake..."
    cat > ../toolchain.cmake << 'EOF'
# Force Qt6
set(QT_VERSION 6 CACHE STRING "OBS Qt version [AUTO, 5, 6]" FORCE)

# Pre-define the _QT_VERSION variable to bypass some detection logic
set(_QT_VERSION 6 CACHE INTERNAL "")

# Pre-set Qt variables
set(QT_FOUND TRUE CACHE INTERNAL "")
set(QT6_FOUND TRUE CACHE INTERNAL "")
EOF
    success "toolchain.cmake created."

    info "Configuring project with CMake..."
    export CMAKE_PREFIX_PATH="/usr/lib/cmake/Qt6:/usr/lib/cmake"
    cmake -S . -B build \
        -DCMAKE_TOOLCHAIN_FILE="../toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_OUT_OF_TREE=On \
        -DQT_VERSION=6

    info "Building plugin..."
    cmake --build build

    success "Build completed successfully."
}

# Install built plugin and resources to selected target
install_plugin() {
    info "Installing plugin to target paths..."
    
    local built_so="build/aitum-multistream.so"
    if [ ! -f "$built_so" ]; then
        error "Built library not found at $built_so! Build may have failed silently."
        exit 1
    fi

    if [ "$INSTALL_MODE" = "system" ]; then
        info "Installing system-wide (will request sudo credentials if not already root)..."
        sudo mkdir -p "$INSTALL_BIN_DIR"
        sudo mkdir -p "$INSTALL_DATA_DIR"
        sudo install -D -m755 "$built_so" "$INSTALL_BIN_DIR/aitum-multistream.so"
        sudo cp -r data/locale/. "$INSTALL_DATA_DIR/"
    else
        info "Installing user-local..."
        mkdir -p "$INSTALL_BIN_DIR"
        mkdir -p "$INSTALL_DATA_DIR"
        install -m755 "$built_so" "$INSTALL_BIN_DIR/aitum-multistream.so"
        cp -r data/locale/. "$INSTALL_DATA_DIR/"
    fi

    success "Installation completed successfully!"
    echo "=================================================="
    echo "Please restart OBS Studio to load the plugin."
    echo "Go to View -> Docks -> Aitum Multistream to open it."
    echo "=================================================="
}

main() {
    info "Starting OBS Aitum Multistream Plugin Installation..."
    verify_dependencies
    select_install_target
    clone_and_build
    install_plugin
}

main "$@"
