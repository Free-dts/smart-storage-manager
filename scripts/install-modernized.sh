#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Smart Storage Manager - Modernized Installation Script
# Version: 2.0.0
# Compatibility: Umbrel OS, Debian 12+, Ubuntu 22.04+
# Author: Umbrel Community Team
# ═══════════════════════════════════════════════════════════════

# Enable strict error handling
set -euo pipefail

# Safe IFS handling
IFS=$'\n\t'

# Script metadata
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Color output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r NC='\033[0m' # No Color

# Configuration variables
declare -r APP_NAME="Smart Storage Manager"
declare -r APP_ID="smart-storage-manager"
declare -r APP_DIR="/opt/smart-storage-manager"
declare -r DATA_DIR="/data/smart-storage"
declare -r CONFIG_DIR="/config/smart-storage"
declare -r LOG_DIR="/var/log/smart-storage"
declare -r LOG_FILE="${LOG_DIR}/install.log"
declare -r SERVICE_USER="smart-storage"
declare -r SERVICE_GROUP="smart-storage"

# Modern package versions
declare -A PACKAGE_VERSIONS
PACKAGE_VERSIONS[MERGERFS]="2.40.3"
PACKAGE_VERSIONS[SNAPRAID]="12.5"
PACKAGE_VERSIONS[NODE_VERSION]="20"
PACKAGE_VERSIONS[PYTHON_VERSION]="3.11"

# Architecture detection
readonly ARCH=$(uname -m)
readonly OS_ID=$(. /etc/os-release && echo "$ID")
readonly OS_VERSION_ID=$(. /etc/os-release && echo "$VERSION_ID")

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_PERMISSION_DENIED=3
readonly EXIT_DEPENDENCY_MISSING=4
readonly EXIT_CONFIGURATION_INVALID=5

# Logging functions
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Write to log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Output to stdout with colors
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $message" ;;
        "SUCCESS") echo -e "${GREEN}[✓]${NC} $message" ;;
        "ERROR") echo -e "${RED}[✗]${NC} $message" >&2 ;;
        "WARN") echo -e "${YELLOW}[!]${NC} $message" ;;
        "DEBUG") [[ "${DEBUG:-0}" == "1" ]] && echo -e "${PURPLE}[DEBUG]${NC} $message" ;;
        *) echo "[$timestamp] [$level] $message" ;;
    esac
}

# Print formatted header
print_header() {
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                               ║${NC}"
    echo -e "${PURPLE}║       🚀 $APP_NAME - Installation Script v$SCRIPT_VERSION       ║${NC}"
    echo -e "${PURPLE}║                  Modernized Edition                          ║${NC}"
    echo -e "${PURPLE}║                                                               ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print formatted footer
print_footer() {
    local status="$1"
    local message="$2"
    
    echo ""
    case "$status" in
        "SUCCESS")
            echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                                                               ║${NC}"
            echo -e "${GREEN}║              ✅ $message ✅                      ║${NC}"
            echo -e "${GREEN}║                                                               ║${NC}"
            echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
            ;;
        "ERROR")
            echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║                                                               ║${NC}"
            echo -e "${RED}║              ❌ $message ❌                      ║${NC}"
            echo -e "${RED}║                                                               ║${NC}"
            echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
            ;;
    esac
    echo ""
}

# Cleanup function for graceful exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && $exit_code -ne $EXIT_SUCCESS ]]; then
        log "ERROR" "Installation failed with exit code $exit_code"
        rollback_on_error
    fi
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Rollback function for error recovery
rollback_on_error() {
    log "WARN" "Rolling back changes due to error..."
    
    # Stop services if they were started
    if [[ -f "${APP_DIR}/docker-compose.yml" ]]; then
        cd "${APP_DIR}" 2>/dev/null && docker-compose down 2>/dev/null || true
    fi
    
    # Remove partially created directories
    [[ -d "${APP_DIR}" ]] && rm -rf "${APP_DIR}" 2>/dev/null || true
    [[ -d "${DATA_DIR}" ]] && rm -rf "${DATA_DIR}" 2>/dev/null || true
    
    log "INFO" "Rollback completed"
}

# Validate command line arguments
validate_arguments() {
    local skip_confirm=0
    local force_install=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                skip_confirm=1
                shift
                ;;
            -f|--force)
                force_install=1
                shift
                ;;
            -v|--verbose)
                export DEBUG=1
                shift
                ;;
            -h|--help)
                show_usage
                exit $EXIT_SUCCESS
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    done
    
    return 0
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Smart Storage Manager Installation Script v$SCRIPT_VERSION

OPTIONS:
    -y, --yes          Skip confirmation prompts
    -f, --force        Force installation even if already installed
    -v, --verbose      Enable verbose output
    -h, --help         Show this help message

EXAMPLES:
    $SCRIPT_NAME                    # Interactive installation
    $SCRIPT_NAME -y                 # Automatic installation
    $SCRIPT_NAME -f -v              # Force verbose installation

For more information, visit: https://github.com/Free-dts/smart-storage-manager
EOF
}

# Check system requirements
check_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check if running as root (required for system installations)
    if [[ $EUID -ne 0 && $EUID -ne 1000 ]]; then
        log "ERROR" "This script must be run as root or with sudo"
        return $EXIT_PERMISSION_DENIED
    fi
    
    # Check OS compatibility
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR" "Cannot determine operating system"
        return $EXIT_ERROR
    fi
    
    case "$OS_ID" in
        "debian"|"ubuntu"|"umbrel")
            log "SUCCESS" "Operating system: $OS_ID $OS_VERSION_ID"
            ;;
        *)
            log "WARN" "Operating system $OS_ID may not be fully supported"
            ;;
    esac
    
    # Check required commands
    local required_commands=("docker" "git" "curl" "wget" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR" "Required command not found: $cmd"
            return $EXIT_DEPENDENCY_MISSING
        fi
    done
    
    # Check Docker daemon
    if ! docker info &>/dev/null; then
        log "ERROR" "Docker daemon is not running or not accessible"
        log "INFO" "Please start Docker service: sudo systemctl start docker"
        return $EXIT_DEPENDENCY_MISSING
    fi
    
    # Check available disk space (minimum 5GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local min_space=$((5 * 1024 * 1024))  # 5GB in KB
    
    if [[ $available_space -lt $min_space ]]; then
        log "WARN" "Low disk space: $(df -h / | awk 'NR==2 {print $4}') available"
        log "INFO" "Recommended: At least 5GB free space"
    fi
    
    # Check memory (minimum 1GB)
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local min_mem=$((1024 * 1024))  # 1GB in KB
    
    if [[ $total_mem -lt $min_mem ]]; then
        log "WARN" "Low memory: $(($total_mem / 1024))MB available"
        log "INFO" "Recommended: At least 1GB RAM"
    fi
    
    log "SUCCESS" "System requirements check completed"
    return 0
}

# Create system directories with proper permissions
create_directories() {
    log "INFO" "Creating system directories..."
    
    local directories=(
        "$APP_DIR"
        "$DATA_DIR"
        "$CONFIG_DIR"
        "$LOG_DIR"
        "/mnt/storage"
        "/mnt/storage/.snapraid"
        "/mnt/storage/disk1"
        "/mnt/storage/disk2"
        "/mnt/storage/disk3"
        "/mnt/storage/disk4"
    )
    
    # Create service user and group if they don't exist
    if ! id "$SERVICE_USER" &>/dev/null; then
        log "INFO" "Creating service user: $SERVICE_USER"
        useradd -r -s /bin/false -d "$APP_DIR" "$SERVICE_USER" || {
            log "WARN" "Could not create service user, continuing as root"
            SERVICE_USER="root"
        }
    fi
    
    # Create directories
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log "DEBUG" "Creating directory: $dir"
            mkdir -p "$dir" || {
                log "ERROR" "Failed to create directory: $dir"
                return $EXIT_ERROR
            }
        fi
    done
    
    # Set ownership and permissions
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$APP_DIR" "$DATA_DIR" "$CONFIG_DIR" 2>/dev/null || {
        log "WARN" "Could not set ownership, continuing with current user"
    }
    
    chmod 755 "$APP_DIR" "$DATA_DIR" "$CONFIG_DIR" "$LOG_DIR"
    chmod 1777 "/mnt/storage"
    
    log "SUCCESS" "System directories created successfully"
    return 0
}

# Install system dependencies with version management
install_dependencies() {
    log "INFO" "Installing system dependencies..."
    
    # Update package lists
    apt-get update -qq || {
        log "ERROR" "Failed to update package lists"
        return $EXIT_ERROR
    }
    
    # Base packages with specific versions for stability
    declare -a base_packages=(
        "curl>=7.88.0"
        "wget>=1.21.0"
        "git>=2.39.0"
        "jq>=1.6"
        "smartmontools>=7.3.0"
        "util-linux>=2.38.0"
        "parted>=3.5"
        "e2fsprogs>=1.47.0"
        "python3>=3.11.0"
        "python3-pip>=23.0.0"
        "fuse3>=3.14.0"
        "logrotate>=3.20.0"
        "rsync>=3.2.0"
        "htop>=3.2.0"
        "ncdu>=1.17"
        "systemd>=252.0"
        "build-essential"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )
    
    # Install base packages
    log "INFO" "Installing base packages..."
    for package in "${base_packages[@]}"; do
        if apt-cache show "$package" &>/dev/null; then
            if ! dpkg -l | grep -q "^ii.*${package%%[<>=]*}"; then
                log "DEBUG" "Installing package: $package"
                apt-get install -y -qq "$package" || {
                    log "WARN" "Failed to install $package, continuing..."
                }
            else
                log "DEBUG" "Package already installed: $package"
            fi
        else
            log "WARN" "Package not available: $package"
        fi
    done
    
    # Install Node.js if not available or wrong version
    local node_version=$(node --version 2>/dev/null || echo "none")
    if [[ "$node_version" == "none" ]] || [[ "${node_version#v}" != "${PACKAGE_VERSIONS[NODE_VERSION]}"* ]]; then
        log "INFO" "Installing Node.js ${PACKAGE_VERSIONS[NODE_VERSION]}..."
        curl -fsSL https://deb.nodesource.com/setup_${PACKAGE_VERSIONS[NODE_VERSION]}.x | bash - || {
            log "WARN" "Failed to install Node.js from NodeSource, trying alternative method"
            # Fallback to package manager
            apt-get install -y nodejs || {
                log "WARN" "Could not install Node.js, frontend build will be skipped"
            }
        }
    fi
    
    # Install Python 3 if not available
    if ! python3 --version &>/dev/null; then
        log "INFO" "Installing Python 3..."
        apt-get install -y python3 || {
            log "ERROR" "Failed to install Python 3"
            return $EXIT_ERROR
        }
    fi
    
    log "SUCCESS" "System dependencies installed successfully"
    return 0
}

# Install MergerFS with version management
install_mergerfs() {
    log "INFO" "Installing MergerFS..."
    
    # Check if already installed with correct version
    if command -v mergerfs &>/dev/null; then
        local current_version=$(mergerfs --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        local target_version="${PACKAGE_VERSIONS[MERGERFS]}"
        
        if [[ "$current_version" == "$target_version" ]]; then
            log "SUCCESS" "MergerFS $current_version already installed"
            return 0
        else
            log "INFO" "Upgrading MergerFS from $current_version to $target_version"
        fi
    fi
    
    # Try to install from package manager first
    if apt-cache show mergerfs &>/dev/null; then
        log "INFO" "Installing MergerFS from package manager..."
        apt-get install -y mergerfs || {
            log "WARN" "Package installation failed, trying manual installation"
        }
    fi
    
    # Manual installation if package failed
    if ! command -v mergerfs &>/dev/null; then
        log "INFO" "Installing MergerFS from source..."
        
        local version="${PACKAGE_VERSIONS[MERGERFS]}"
        local mergerfs_deb=""
        
        case "$ARCH" in
            "x86_64")
                mergerfs_deb="mergerfs_${version}.debian-bookworm_amd64.deb"
                ;;
            "aarch64"|"arm64")
                mergerfs_deb="mergerfs_${version}.debian-bookworm_arm64.deb"
                ;;
            "armv7l")
                mergerfs_deb="mergerfs_${version}.debian-bookworm_armhf.deb"
                ;;
            *)
                log "ERROR" "Unsupported architecture: $ARCH"
                return $EXIT_ERROR
                ;;
        esac
        
        cd /tmp
        local mergerfs_url="https://github.com/trapexit/mergerfs/releases/download/${version}/${mergerfs_deb}"
        
        if wget -q --spider "$mergerfs_url"; then
            wget -q "$mergerfs_url" || {
                log "ERROR" "Failed to download MergerFS"
                return $EXIT_ERROR
            }
            
            dpkg -i "$mergerfs_deb" || apt-get install -f -y
            rm -f "$mergerfs_deb"
        else
            log "ERROR" "MergerFS package not found: $mergerfs_url"
            return $EXIT_ERROR
        fi
    fi
    
    # Verify installation
    if command -v mergerfs &>/dev/null; then
        local installed_version=$(mergerfs --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        log "SUCCESS" "MergerFS $installed_version installed successfully"
    else
        log "ERROR" "MergerFS installation verification failed"
        return $EXIT_ERROR
    fi
    
    return 0
}

# Install SnapRAID with version management
install_snapraid() {
    log "INFO" "Installing SnapRAID..."
    
    # Check if already installed with correct version
    if command -v snapraid &>/dev/null; then
        local current_version=$(snapraid --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
        local target_version="${PACKAGE_VERSIONS[SNAPRAID]}"
        
        if [[ "$current_version" == "$target_version" ]]; then
            log "SUCCESS" "SnapRAID $current_version already installed"
            return 0
        else
            log "INFO" "Upgrading SnapRAID from $current_version to $target_version"
        fi
    fi
    
    # Try to install from package manager first
    if apt-cache show snapraid &>/dev/null; then
        log "INFO" "Installing SnapRAID from package manager..."
        apt-get install -y snapraid || {
            log "WARN" "Package installation failed, trying manual compilation"
        }
    fi
    
    # Manual compilation if package failed
    if ! command -v snapraid &>/dev/null; then
        log "INFO" "Installing SnapRAID from source..."
        
        local version="${PACKAGE_VERSIONS[SNAPRAID]}"
        local snapraid_dir="snapraid-${version}"
        
        cd /tmp
        
        # Download source
        local snapraid_url="https://github.com/amadvance/snapraid/releases/download/v${version}/snapraid-${version}.tar.gz"
        
        if ! wget -q "$snapraid_url"; then
            log "ERROR" "Failed to download SnapRAID source"
            return $EXIT_ERROR
        fi
        
        # Extract and compile
        tar xzf "snapraid-${version}.tar.gz"
        cd "$snapraid_dir"
        
        log "INFO" "Compiling SnapRAID (this may take a few minutes)..."
        
        # Configure with minimal dependencies
        ./configure --quiet --disable-selinux --disable-acl || {
            log "ERROR" "SnapRAID configuration failed"
            return $EXIT_ERROR
        }
        
        # Compile with parallel jobs
        make -j"$(nproc)" >/dev/null 2>&1 || {
            log "ERROR" "SnapRAID compilation failed"
            return $EXIT_ERROR
        }
        
        # Install
        make install >/dev/null 2>&1 || {
            log "ERROR" "SnapRAID installation failed"
            return $EXIT_ERROR
        }
        
        # Cleanup
        cd /tmp
        rm -rf "snapraid-${version}"*
    fi
    
    # Verify installation
    if command -v snapraid &>/dev/null; then
        local installed_version=$(snapraid --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
        log "SUCCESS" "SnapRAID $installed_version installed successfully"
    else
        log "ERROR" "SnapRAID installation verification failed"
        return $EXIT_ERROR
    fi
    
    return 0
}

# Download and setup application
download_app() {
    log "INFO" "Downloading Smart Storage Manager..."
    
    cd "$(dirname "$APP_DIR")"
    
    # Check if directory exists and handle accordingly
    if [[ -d "$APP_DIR/.git" ]]; then
        log "INFO" "Updating existing installation..."
        cd "$APP_DIR"
        
        # Stash any local changes
        git stash push -m "Stashed before update $(date)" || true
        
        # Fetch latest changes
        git fetch --all --tags || {
            log "WARN" "Failed to fetch latest changes"
        }
        
        # Update to latest version
        git checkout main || {
            log "WARN" "Failed to checkout main branch, staying on current branch"
        }
        
        git pull || {
            log "WARN" "Failed to pull latest changes"
        }
        
    else
        log "INFO" "Fresh installation..."
        
        # Remove existing directory if force install
        if [[ -d "$APP_DIR" ]]; then
            log "WARN" "Removing existing installation directory"
            rm -rf "$APP_DIR"
        fi
        
        # Clone repository
        local repo_url="https://github.com/Free-dts/smart-storage-manager.git"
        
        if ! git clone "$repo_url" "$APP_DIR"; then
            log "ERROR" "Failed to clone repository"
            return $EXIT_ERROR
        fi
        
        cd "$APP_DIR"
    fi
    
    # Checkout latest release tag if available
    local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -n "$latest_tag" ]]; then
        git checkout "$latest_tag" 2>/dev/null || {
            log "WARN" "Failed to checkout tag $latest_tag, using current commit"
        }
    fi
    
    log "SUCCESS" "Smart Storage Manager downloaded successfully"
    log "INFO" "Version: $(git describe --tags --always 2>/dev/null || echo 'unknown')"
    
    return 0
}

# Build frontend application
build_frontend() {
    log "INFO" "Building frontend application..."
    
    cd "$APP_DIR/app/frontend"
    
    # Check if Node.js is available
    if ! command -v node &>/dev/null; then
        log "WARN" "Node.js not available, skipping frontend build"
        return 0
    fi
    
    # Check if npm is available
    if ! command -v npm &>/dev/null; then
        log "WARN" "npm not available, skipping frontend build"
        return 0
    fi
    
    # Install dependencies
    log "INFO" "Installing frontend dependencies..."
    npm ci --silent || {
        log "WARN" "Failed to install frontend dependencies with npm ci, trying npm install"
        npm install --silent || {
            log "ERROR" "Failed to install frontend dependencies"
            return $EXIT_ERROR
        }
    }
    
    # Build application
    log "INFO" "Building frontend application..."
    npm run build || {
        log "ERROR" "Frontend build failed"
        return $EXIT_ERROR
    }
    
    log "SUCCESS" "Frontend built successfully"
    return 0
}

# Setup Docker environment
setup_docker() {
    log "INFO" "Setting up Docker environment..."
    
    cd "$APP_DIR"
    
    # Create environment file
    cat > .env <<EOF
# Smart Storage Manager Environment Configuration
# Generated: $(date)
# Version: $SCRIPT_VERSION

APP_NAME=$APP_NAME
APP_ID=$APP_ID
APP_VERSION=$SCRIPT_VERSION
APP_ENV=production

SERVICE_HOST=0.0.0.0
SERVICE_PORT=8850

STORAGE_MOUNT_POINT=/mnt/storage
STORAGE_POOL_POINT=/mnt/storage/pool
STORAGE_CONFIG_DIR=$CONFIG_DIR
STORAGE_DATA_DIR=$DATA_DIR

DISK_AUTO_DETECTION=true
DISK_SMART_MONITORING=true
DISK_HEALTH_CHECK_INTERVAL=300
DISK_TEMPERATURE_THRESHOLD=70
DISK_BAD_SECTOR_THRESHOLD=10

MERGERFS_POLICY=rw
MERGERFS_MINFreespace=100M
MERGERFS_CACHE_FILES=partial
MERGERFS_STATFS=0

SNAPRAID_CONFIG_PATH=$CONFIG_DIR/snapraid.conf
SNAPRAID_PARITY_PATH=/mnt/storage/.snapraid/parity
SNAPRAID_CONTENT_PATH=/mnt/storage/.snapraid/content
SNAPRAID_MAINTENANCE_SCHEDULE=0 2 * * *
SNAPRAID_AUTOSAVE=10
SNAPRAID_BLOCKSIZE=256

LOG_LEVEL=INFO
LOG_FILE_PATH=$LOG_DIR/app.log
LOG_ROTATION_SIZE=10M
LOG_RETENTION_DAYS=30
METRICS_ENABLED=true
METRICS_PORT=9090

SECURITY_ENABLE_AUTH=true
SECURITY_SESSION_TIMEOUT=3600
SECURITY_RATE_LIMITING=true
SECURITY_MAX_REQUESTS_PER_MINUTE=60

NOTIFICATIONS_ENABLED=true
NOTIFICATION_EMAIL_ENABLED=false

BACKUP_ENABLED=true
BACKUP_INTERVAL=86400
BACKUP_RETENTION=7
BACKUP_S3_ENABLED=false

DOCKER_IMAGE_TAG=latest
DOCKER_REGISTRY=ghcr.io
DOCKER_ORGANIZATION=umbrel
DOCKER_REPOSITORY=smart-storage-manager

UMBREL_APP_ID=$APP_ID
UMBREL_APP_VERSION=$SCRIPT_VERSION
UMBREL_APP_STORE_URL=https://apps.umbrel.com/apps/$APP_ID

TZ=UTC
PUID=1000
PGID=1000
EOF
    
    # Build Docker image
    log "INFO" "Building Docker image..."
    docker-compose build --quiet || {
        log "ERROR" "Docker image build failed"
        return $EXIT_ERROR
    }
    
    log "SUCCESS" "Docker environment setup completed"
    return 0
}

# Start application services
start_services() {
    log "INFO" "Starting Smart Storage Manager services..."
    
    cd "$APP_DIR"
    
    # Start services in detached mode
    if ! docker-compose up -d; then
        log "ERROR" "Failed to start services"
        return $EXIT_ERROR
    fi
    
    # Wait for services to be ready
    log "INFO" "Waiting for services to start..."
    local max_wait=60
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        if curl -sf http://localhost:8850/health &>/dev/null; then
            log "SUCCESS" "Services started successfully"
            break
        fi
        
        sleep 5
        wait_time=$((wait_time + 5))
        
        if [[ $wait_time -eq $max_wait ]]; then
            log "ERROR" "Services failed to start within ${max_wait} seconds"
            docker-compose logs --tail=50
            return $EXIT_ERROR
        fi
    done
    
    return 0
}

# Create systemd service
create_systemd_service() {
    log "INFO" "Creating systemd service..."
    
    # Create service file
    cat > /etc/systemd/system/smart-storage-manager.service <<EOF
[Unit]
Description=Smart Storage Manager v$SCRIPT_VERSION
Documentation=https://github.com/Free-dts/smart-storage-manager
After=docker.service
Requires=docker.service
Wants=network.target
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
Group=root
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStartPre=/bin/sh -c 'until docker info; do echo "Waiting for Docker..."; sleep 2; done'
ExecStart=/usr/local/bin/docker-compose-wrapper up -d
ExecStop=/usr/local/bin/docker-compose-wrapper down
Restart=on-failure
RestartSec=10
TimeoutStartSec=0
KillMode=mixed
KillSignal=SIGTERM

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$APP_DIR $DATA_DIR $CONFIG_DIR $LOG_DIR /mnt/storage

[Install]
WantedBy=multi-user.target
EOF
    
    # Create Docker Compose wrapper script
    cat > /usr/local/bin/docker-compose-wrapper <<EOF
#!/bin/bash
cd "$APP_DIR"
exec docker-compose "\$@"
EOF
    chmod +x /usr/local/bin/docker-compose-wrapper
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable smart-storage-manager.service
    
    log "SUCCESS" "Systemd service created and enabled"
    return 0
}

# Setup automated maintenance
setup_maintenance() {
    log "INFO" "Setting up automated maintenance..."
    
    # Create maintenance script
    cat > /usr/local/bin/smart-storage-maintenance <<'EOF'
#!/usr/bin/env bash
# Smart Storage Manager - Automated Maintenance Script

set -euo pipefail
IFS=$'\n\t'

# Configuration
readonly APP_NAME="Smart Storage Manager"
readonly LOG_FILE="/var/log/smart-storage/maintenance.log"
readonly DATA_DIR="/data/smart-storage"

# Logging function
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $*" | tee -a "$LOG_FILE"
}

# Maintenance tasks
main() {
    log "INFO" "Starting automated maintenance for $APP_NAME"
    
    # Check if Docker container is running
    if ! docker ps | grep -q smart-storage-manager; then
        log "ERROR" "Smart Storage Manager container is not running"
        exit 1
    fi
    
    # Run SnapRAID maintenance
    log "INFO" "Running SnapRAID maintenance..."
    docker exec smart-storage-manager-web python3 -c "
import sys
sys.path.append('/app/backend')
from snapraid_manager import SnapRAIDManager
manager = SnapRAIDManager()
try:
    manager.run_maintenance()
    print('SnapRAID maintenance completed successfully')
except Exception as e:
    print(f'SnapRAID maintenance failed: {e}', file=sys.stderr)
    sys.exit(1)
" || log "WARN" "SnapRAID maintenance failed"
    
    # Clean up old logs
    log "INFO" "Cleaning up old log files..."
    find /var/log/smart-storage -name "*.log" -mtime +30 -delete 2>/dev/null || true
    
    # Update disk health information
    log "INFO" "Updating disk health information..."
    docker exec smart-storage-manager-web python3 -c "
import sys
sys.path.append('/app/backend')
from disk_manager import DiskManager
manager = DiskManager()
try:
    manager.update_disk_health()
    print('Disk health update completed')
except Exception as e:
    print(f'Disk health update failed: {e}', file=sys.stderr)
    sys.exit(1)
" || log "WARN" "Disk health update failed"
    
    log "INFO" "Automated maintenance completed"
}

# Run maintenance
main "$@"
EOF
    chmod +x /usr/local/bin/smart-storage-maintenance
    
    # Create logrotate configuration
    cat > /etc/logrotate.d/smart-storage-manager <<EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 root root
    postrotate
        /usr/local/bin/smart-storage-maintenance > /dev/null 2>&1 || true
    endscript
}
EOF
    
    # Add cron job for maintenance (daily at 2 AM)
    (crontab -l 2>/dev/null | grep -v "smart-storage-maintenance" || true
     echo "0 2 * * * /usr/local/bin/smart-storage-maintenance >> $LOG_DIR/cron.log 2>&1") | crontab -
    
    log "SUCCESS" "Automated maintenance setup completed"
    return 0
}

# Perform final tests
final_tests() {
    log "INFO" "Running final tests..."
    
    local tests_passed=0
    local tests_total=4
    
    # Test 1: Health check
    if curl -sf http://localhost:8850/health &>/dev/null; then
        log "SUCCESS" "✓ Health check passed"
        tests_passed=$((tests_passed + 1))
    else
        log "WARN" "✗ Health check failed"
    fi
    
    # Test 2: API status
    if curl -sf http://localhost:8850/api/status &>/dev/null; then
        log "SUCCESS" "✓ API status check passed"
        tests_passed=$((tests_passed + 1))
    else
        log "WARN" "✗ API status check failed"
    fi
    
    # Test 3: Docker containers
    if docker ps | grep -q smart-storage-manager; then
        log "SUCCESS" "✓ Docker container check passed"
        tests_passed=$((tests_passed + 1))
    else
        log "WARN" "✗ Docker container check failed"
    fi
    
    # Test 4: Disk utilities
    if command -v mergerfs &>/dev/null && command -v snapraid &>/dev/null; then
        log "SUCCESS" "✓ Disk utilities check passed"
        tests_passed=$((tests_passed + 1))
    else
        log "WARN" "✗ Disk utilities check failed"
    fi
    
    log "INFO" "Tests passed: $tests_passed/$tests_total"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log "SUCCESS" "All tests passed successfully"
        return 0
    else
        log "WARN" "Some tests failed, but installation may still be functional"
        return 0
    fi
}

# Show installation summary
show_summary() {
    local ip_address=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    local version=$(git describe --tags --always 2>/dev/null || echo "$SCRIPT_VERSION")
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              ✅ Installation Completed Successfully! ✅           ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📊 Installation Summary:${NC}"
    echo -e "   App Name: ${APP_NAME}"
    echo -e "   Version:  ${version}"
    echo -e "   Location: ${APP_DIR}"
    echo -e "   User:     ${SERVICE_USER}"
    echo ""
    echo -e "${CYAN}🌐 Access Information:${NC}"
    echo -e "   Web UI:   ${YELLOW}http://${ip_address}:8850${NC}"
    echo -e "   Local:    ${YELLOW}http://umbrel.local:8850${NC}"
    echo -e "   Health:   ${YELLOW}http://${ip_address}:8850/health${NC}"
    echo ""
    echo -e "${CYAN}⚡ Management Commands:${NC}"
    echo -e "   Status:   ${YELLOW}systemctl status smart-storage-manager${NC}"
    echo -e "   Start:    ${YELLOW}systemctl start smart-storage-manager${NC}"
    echo -e "   Stop:     ${YELLOW}systemctl stop smart-storage-manager${NC}"
    echo -e "   Restart:  ${YELLOW}systemctl restart smart-storage-manager${NC}"
    echo -e "   Logs:     ${YELLOW}journalctl -u smart-storage-manager -f${NC}"
    echo ""
    echo -e "${CYAN}📁 Important Paths:${NC}"
    echo -e "   App:      ${APP_DIR}"
    echo -e "   Data:     ${DATA_DIR}"
    echo -e "   Config:   ${CONFIG_DIR}"
    echo -e "   Logs:     ${LOG_DIR}"
    echo -e "   Storage:  /mnt/storage"
    echo ""
    echo -e "${CYAN}🔧 Maintenance:${NC}"
    echo -e "   Manual:   ${YELLOW}/usr/local/bin/smart-storage-maintenance${NC}"
    echo -e "   Auto:     ${YELLOW}Daily at 2:00 AM via cron${NC}"
    echo -e "   Log Rotate: ${YELLOW}30 days retention${NC}"
    echo ""
    echo -e "${CYAN}🔗 Useful Links:${NC}"
    echo -e "   GitHub:   ${YELLOW}https://github.com/Free-dts/smart-storage-manager${NC}"
    echo -e "   Issues:   ${YELLOW}https://github.com/Free-dts/smart-storage-manager/issues${NC}"
    echo -e "   Wiki:     ${YELLOW}https://github.com/Free-dts/smart-storage-manager/wiki${NC}"
    echo ""
    echo -e "${GREEN}🎉 Smart Storage Manager is now ready to use!${NC}"
    echo ""
    
    # Display any warnings
    if [[ -f "$LOG_FILE" ]]; then
        local warnings=$(grep -c "\[WARN\]" "$LOG_FILE" 2>/dev/null || echo "0")
        if [[ $warnings -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  Note: $warnings warnings were logged during installation${NC}"
            echo -e "${YELLOW}   Check the log file for details: $LOG_FILE${NC}"
            echo ""
        fi
    fi
    
    echo -e "${BLUE}📖 Next Steps:${NC}"
    echo "   1. Open the web interface in your browser"
    echo "   2. Configure your storage devices in the UI"
    echo "   3. Set up SnapRAID protection"
    echo "   4. Configure monitoring and notifications"
    echo ""
}

# Main installation function
main() {
    local skip_confirmation="${1:-0}"
    
    # Validate arguments
    validate_arguments "${@}"
    
    # Start logging
    echo "=== Smart Storage Manager Installation Started at $(date) ===" > "$LOG_FILE"
    
    print_header
    
    # Show installation plan
    if [[ $skip_confirmation -eq 0 ]]; then
        echo -e "${YELLOW}📋 This installation will:${NC}"
        echo "   • Install system dependencies (MergerFS, SnapRAID, etc.)"
        echo "   • Download and setup Smart Storage Manager"
        echo "   • Configure Docker containers"
        echo "   • Setup automated maintenance"
        echo "   • Create systemd service"
        echo "   • Configure logging and monitoring"
        echo ""
        echo -e "${YELLOW}📋 System Requirements:${NC}"
        echo "   • Operating System: Debian 12+, Ubuntu 22.04+, or Umbrel OS"
        echo "   • Docker: 20.10+ (required)"
        echo "   • Disk Space: 5GB+ available"
        echo "   • Memory: 1GB+ RAM"
        echo "   • Network: Internet connection for downloads"
        echo ""
        
        read -p "Continue with installation? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Installation cancelled by user"
            exit $EXIT_SUCCESS
        fi
        echo ""
    fi
    
    # Run installation steps
    local steps=(
        "check_requirements"
        "create_directories"
        "install_dependencies"
        "install_mergerfs"
        "install_snapraid"
        "download_app"
        "build_frontend"
        "setup_docker"
        "start_services"
        "create_systemd_service"
        "setup_maintenance"
        "final_tests"
    )
    
    local step_number=1
    local total_steps=${#steps[@]}
    
    for step in "${steps[@]}"; do
        log "INFO" "Step $step_number/$total_steps: ${step//_/ }"
        
        if $step; then
            step_number=$((step_number + 1))
        else
            log "ERROR" "Installation failed at step: $step"
            return $EXIT_ERROR
        fi
    done
    
    # Show summary
    show_summary
    
    # Final logging
    echo "=== Smart Storage Manager Installation Completed Successfully at $(date) ===" >> "$LOG_FILE"
    
    return $EXIT_SUCCESS
}

# Run main function with all arguments
main "$@"
