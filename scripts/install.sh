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
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly PURPLE=''
    readonly CYAN=''
    readonly NC=''
fi

# Logging configuration
readonly LOG_FILE="/var/log/smart-storage-install.log"
readonly LOG_MAX_SIZE=$((10 * 1024 * 1024))  # 10MB
readonly LOG_BACKUP_COUNT=5

# Application configuration
readonly APP_NAME="Smart Storage Manager"
readonly APP_ID="smart-storage-manager"
readonly APP_VERSION="2.0.0"
readonly APP_DIR="/opt/${APP_ID}"
readonly DATA_DIR="/data/${APP_ID}"
readonly CONFIG_DIR="/config/${APP_ID}"
readonly SERVICE_USER="smart-storage"
readonly NGINX_CONF_DIR="/etc/nginx/sites-available"
readonly SYSTEMD_DIR="/etc/systemd/system"

# Architecture detection
readonly ARCHITECTURE=$(dpkg --print-architecture)
readonly PLATFORM=$(uname -m)

# Network configuration
readonly DEFAULT_PORT=8850
readonly DEFAULT_HOST="0.0.0.0"

# System requirements
readonly MIN_DISK_SPACE_GB=10
readonly MIN_MEMORY_GB=2
readonly REQUIRED_PACKAGES=(
    "curl"
    "wget"
    "git"
    "jq"
    "nginx"
    "smartmontools"
    "util-linux"
    "parted"
    "e2fsprogs"
    "python3"
    "python3-pip"
    "python3-venv"
    "fuse3"
    "fuse"
)

# Docker configuration
readonly DOCKER_IMAGE="ghcr.io/umbrel/${APP_ID}:latest"
readonly DOCKER_COMPOSE_VERSION="2.29.2"

# MergerFS configuration
readonly MERGERFS_VERSION="2.40.2"

# SnapRAID configuration  
readonly SNAPRAID_VERSION="12.3"

# Health check endpoints
readonly HEALTH_ENDPOINT="http://localhost:${DEFAULT_PORT}/health"
readonly API_ENDPOINT="http://localhost:${DEFAULT_PORT}/api/v2/status"

# Backup configuration
readonly BACKUP_DIR="/var/backups/${APP_ID}"
readonly BACKUP_RETENTION_DAYS=30

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_PREREQUISITES=2
readonly EXIT_PERMISSION_DENIED=3
readonly EXIT_NETWORK_ERROR=4
readonly EXIT_SERVICE_FAILURE=5
readonly EXIT_ROLLBACK=6

# Feature flags
declare -g ENABLE_AUTO_UPDATE=true
declare -g ENABLE_NOTIFICATIONS=true
declare -g ENABLE_BACKUP=true
declare -g ENABLE_MONITORING=true
declare -g SKIP_FRONTEND_BUILD=false
declare -g DRY_RUN=false
declare -g VERBOSE=false
declare -g FORCE_INSTALL=false

# Global variables
declare -g INSTALL_START_TIME
declare -g INSTALL_SUCCESS=false
declare -g ROLLBACK_IN_PROGRESS=false
declare -g ORIGINAL_UMASK

# Function: Print colored output
print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

print_info() { print_color "$BLUE" "[INFO] $*"; }
print_success() { print_color "$GREEN" "[✓] $*"; }
print_warning() { print_color "$YELLOW" "[!] $*"; }
print_error() { print_color "$RED" "[✗] $*"; }
print_header() {
    echo ""
    print_color "$PURPLE" "╔═══════════════════════════════════════════════════════════════╗"
    print_color "$PURPLE" "║                                                               ║"
    print_color "$PURPLE" "║       🚀 $APP_NAME - Installation Script       ║"
    print_color "$PURPLE" "║                  Version $APP_VERSION                                ║"
    print_color "$PURPLE" "║                                                               ║"
    print_color "$PURPLE" "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
}

# Function: Enhanced logging with rotation
log_message() {
    local level="$1"
    shift
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Append to log file
    echo "$message" >> "$LOG_FILE"
    
    # Rotate log file if it exceeds max size
    if [[ -f "$LOG_FILE" && $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt $LOG_MAX_SIZE ]]; then
        local backup_file="${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"
        mv "$LOG_FILE" "$backup_file"
        # Keep only recent backups
        ls -t "${LOG_FILE}".* 2>/dev/null | tail -n +$((LOG_BACKUP_COUNT + 1)) | xargs rm -f 2>/dev/null || true
    fi
    
    # Also print to stdout based on level
    case "$level" in
        INFO) print_info "$*" ;;
        SUCCESS) print_success "$*" ;;
        WARNING) print_warning "$*" ;;
        ERROR) print_error "$*" ;;
        *) echo "$message" ;;
    esac
}

# Function: Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message ERROR "This script must be run as root"
        log_message ERROR "Please run: sudo $0 $*"
        exit $EXIT_PERMISSION_DENIED
    fi
}

# Function: Check system architecture compatibility
check_architecture() {
    log_message INFO "Checking system architecture..."
    
    case "$ARCHITECTURE" in
        amd64|arm64|armhf)
            log_message SUCCESS "Architecture $ARCHITECTURE is supported"
            ;;
        *)
            log_message ERROR "Unsupported architecture: $ARCHITECTURE"
            log_message ERROR "Supported architectures: amd64, arm64, armhf"
            exit $EXIT_PREREQUISITES
            ;;
    esac
}

# Function: Check system compatibility
check_system_compatibility() {
    log_message INFO "Checking system compatibility..."
    
    # Check if it's a Debian-based system
    if [[ ! -f /etc/debian_version ]]; then
        log_message ERROR "This script is designed for Debian-based systems only"
        log_message ERROR "Detected OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        exit $EXIT_PREREQUISITES
    fi
    
    local os_version=$(cat /etc/debian_version)
    log_message SUCCESS "Detected Debian version: $os_version"
    
    # Check kernel version
    local kernel_version=$(uname -r)
    log_message INFO "Kernel version: $kernel_version"
    
    # Check if running in container
    if grep -q docker /proc/1/cgroup 2>/dev/null || grep -q lxc /proc/1/cgroup 2>/dev/null; then
        log_message WARNING "Running in container environment"
        if [[ "$FORCE_INSTALL" != true ]]; then
            log_message ERROR "Container installation not supported without --force flag"
            exit $EXIT_PREREQUISITES
        fi
    fi
}

# Function: Check system resources
check_system_resources() {
    log_message INFO "Checking system resources..."
    
    # Check available disk space
    local available_space_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $available_space_gb -lt $MIN_DISK_SPACE_GB ]]; then
        log_message ERROR "Insufficient disk space: ${available_space_gb}GB available, ${MIN_DISK_SPACE_GB}GB required"
        exit $EXIT_PREREQUISITES
    fi
    log_message SUCCESS "Disk space: ${available_space_gb}GB available"
    
    # Check available memory
    local available_memory_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $available_memory_gb -lt $MIN_MEMORY_GB ]]; then
        log_message WARNING "Low memory: ${available_memory_gb}GB available, ${MIN_MEMORY_GB}GB recommended"
        if [[ "$FORCE_INSTALL" != true ]]; then
            log_message ERROR "Install may fail due to insufficient memory"
            exit $EXIT_PREREQUISITES
        fi
    fi
    log_message SUCCESS "Available memory: ${available_memory_gb}GB"
}

# Function: Check network connectivity
check_network_connectivity() {
    log_message INFO "Checking network connectivity..."
    
    local test_urls=(
        "https://api.github.com"
        "https://deb.nodesource.com"
        "https://registry.npmjs.org"
    )
    
    for url in "${test_urls[@]}"; do
        if curl -fsS --connect-timeout 10 --retry 2 "$url" >/dev/null 2>&1; then
            log_message SUCCESS "Network connectivity verified"
            return 0
        fi
    done
    
    log_message ERROR "Network connectivity test failed"
    log_message ERROR "Please check your internet connection and DNS settings"
    exit $EXIT_NETWORK_ERROR
}

# Function: Check existing installation
check_existing_installation() {
    log_message INFO "Checking for existing installation..."
    
    if [[ -d "$APP_DIR" ]] || systemctl is-enabled "$APP_ID" >/dev/null 2>&1; then
        log_message WARNING "Existing installation detected"
        
        if [[ "$FORCE_INSTALL" != true ]]; then
            log_message ERROR "Installation already exists. Use --force to overwrite"
            exit $EXIT_PREREQUISITES
        else
            log_message WARNING "Force installation enabled - will overwrite existing installation"
            log_message WARNING "This will remove existing configuration and data"
        fi
    fi
}

# Function: Update package lists
update_package_lists() {
    log_message INFO "Updating package lists..."
    apt-get update -qq || {
        log_message ERROR "Failed to update package lists"
        exit $EXIT_NETWORK_ERROR
    }
    log_message SUCCESS "Package lists updated"
}

# Function: Install system dependencies
install_system_dependencies() {
    log_message INFO "Installing system dependencies..."
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            log_message INFO "Installing $package..."
            apt-get install -y "$package" || {
                log_message ERROR "Failed to install $package"
                exit $EXIT_PREREQUISITES
            }
        else
            log_message SUCCESS "$package is already installed"
        fi
    done
    
    log_message SUCCESS "All system dependencies installed"
}

# Function: Install Node.js 20.x
install_nodejs() {
    log_message INFO "Installing Node.js 20.x..."
    
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version | sed 's/v//')
        if [[ "${node_version%%.*}" -ge 20 ]]; then
            log_message SUCCESS "Node.js $node_version is already installed"
            return 0
        else
            log_message WARNING "Node.js version $node_version found, upgrading to 20.x"
        fi
    fi
    
    # Install NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - || {
        log_message ERROR "Failed to install Node.js repository"
        exit $EXIT_NETWORK_ERROR
    }
    
    apt-get install -y nodejs || {
        log_message ERROR "Failed to install Node.js"
        exit $EXIT_PREREQUISITES
    }
    
    local installed_version=$(node --version)
    log_message SUCCESS "Node.js $installed_version installed"
}

# Function: Install Docker
install_docker() {
    log_message INFO "Checking Docker installation..."
    
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        log_message SUCCESS "Docker $docker_version is already installed"
        return 0
    fi
    
    log_message INFO "Installing Docker..."
    
    # Install Docker from official repository
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || {
        log_message ERROR "Failed to install Docker"
        exit $EXIT_PREREQUISITES
    }
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    log_message SUCCESS "Docker installed and started"
}

# Function: Install MergerFS
install_mergerfs() {
    log_message INFO "Installing MergerFS..."
    
    if command -v mergerfs >/dev/null 2>&1; then
        local mergerfs_version=$(mergerfs --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        log_message SUCCESS "MergerFS $mergerfs_version is already installed"
        return 0
    fi
    
    local mergerfs_deb
    case "$ARCHITECTURE" in
        amd64)
            mergerfs_deb="mergerfs_${MERGERFS_VERSION}.debian-bookworm_amd64.deb"
            ;;
        arm64)
            mergerfs_deb="mergerfs_${MERGERFS_VERSION}.debian-bookworm_arm64.deb"
            ;;
        armhf)
            mergerfs_deb="mergerfs_${MERGERFS_VERSION}.debian-bookworm_armhf.deb"
            ;;
        *)
            log_message ERROR "Unsupported architecture for MergerFS: $ARCHITECTURE"
            exit $EXIT_PREREQUISITES
            ;;
    esac
    
    local mergerfs_url="https://github.com/trapexit/mergerfs/releases/download/${MERGERFS_VERSION}/${mergerfs_deb}"
    
    cd /tmp
    wget -q "$mergerfs_url" || {
        log_message ERROR "Failed to download MergerFS"
        exit $EXIT_NETWORK_ERROR
    }
    
    dpkg -i "$mergerfs_deb" || {
        log_message WARNING "Dependency installation required, fixing..."
        apt-get install -f -y
    }
    
    rm -f "$mergerfs_deb"
    
    log_message SUCCESS "MergerFS ${MERGERFS_VERSION} installed"
}

# Function: Install SnapRAID
install_snapraid() {
    log_message INFO "Installing SnapRAID..."
    
    if command -v snapraid >/dev/null 2>&1; then
        local snapraid_version=$(snapraid --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        log_message SUCCESS "SnapRAID $snapraid_version is already installed"
        return 0
    fi
    
    local snapraid_url="https://github.com/amadvance/snapraid/releases/download/v${SNAPRAID_VERSION}/snapraid-${SNAPRAID_VERSION}.tar.gz"
    
    cd /tmp
    wget -q "$snapraid_url" || {
        log_message ERROR "Failed to download SnapRAID"
        exit $EXIT_NETWORK_ERROR
    }
    
    tar xzf "snapraid-${SNAPRAID_VERSION}.tar.gz"
    cd "snapraid-${SNAPRAID_VERSION}"
    
    log_message INFO "Building SnapRAID (this may take a few minutes)..."
    ./configure --quiet || {
        log_message ERROR "SnapRAID configure failed"
        exit $EXIT_PREREQUISITES
    }
    
    make -j$(nproc) >/dev/null 2>&1 || {
        log_message ERROR "SnapRAID build failed"
        exit $EXIT_PREREQUISITES
    }
    
    make install >/dev/null 2>&1 || {
        log_message ERROR "SnapRAID installation failed"
        exit $EXIT_PREREQUISITES
    }
    
    cd /tmp
    rm -rf "snapraid-${SNAPRAID_VERSION}"*
    
    log_message SUCCESS "SnapRAID ${SNAPRAID_VERSION} installed"
}

# Function: Create application directories
create_directories() {
    log_message INFO "Creating application directories..."
    
    local directories=(
        "$APP_DIR"
        "$DATA_DIR"
        "$CONFIG_DIR"
        "$BACKUP_DIR"
        "/mnt/storage"
        "/mnt/storage/pool"
        "/var/log/${APP_ID}"
        "/etc/${APP_ID}"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_message SUCCESS "Created directory: $dir"
        else
            log_message INFO "Directory already exists: $dir"
        fi
    done
    
    # Set proper ownership
    chown -R root:root "$APP_DIR" 2>/dev/null || true
    chown -R root:root "$DATA_DIR" 2>/dev/null || true
    chown -R root:root "$CONFIG_DIR" 2>/dev/null || true
    
    log_message SUCCESS "Application directories created"
}

# Function: Create service user
create_service_user() {
    log_message INFO "Creating service user..."
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --home-dir "$APP_DIR" --shell /bin/false "$SERVICE_USER" || {
            log_message WARNING "Failed to create service user, using root"
            SERVICE_USER="root"
        }
        log_message SUCCESS "Created service user: $SERVICE_USER"
    else
        log_message INFO "Service user already exists: $SERVICE_USER"
    fi
}

# Function: Clone or update application
download_application() {
    log_message INFO "Downloading application..."
    
    cd "$APP_DIR"
    
    if [[ -d .git ]]; then
        log_message INFO "Updating existing installation..."
        git fetch --all
        git checkout "v${APP_VERSION}" 2>/dev/null || git checkout main
        git pull
    else
        log_message INFO "Cloning repository..."
        git clone --depth 1 --branch "v${APP_VERSION}" https://github.com/Free-dts/smart-storage-manager.git . || {
            log_message ERROR "Failed to clone repository"
            exit $EXIT_NETWORK_ERROR
        }
    fi
    
    log_message SUCCESS "Application downloaded/updated"
}

# Function: Build frontend
build_frontend() {
    if [[ "$SKIP_FRONTEND_BUILD" == true ]]; then
        log_message INFO "Skipping frontend build (--skip-frontend-build specified)"
        return 0
    fi
    
    log_message INFO "Building frontend..."
    
    cd "$APP_DIR/app/frontend"
    
    # Install dependencies
    log_message INFO "Installing Node.js dependencies..."
    npm ci --silent || npm install --silent || {
        log_message ERROR "Failed to install Node.js dependencies"
        exit $EXIT_PREREQUISITES
    }
    
    # Build frontend
    log_message INFO "Building production bundle..."
    npm run build || {
        log_message ERROR "Frontend build failed"
        exit $EXIT_PREREQUISITES
    }
    
    log_message SUCCESS "Frontend built successfully"
}

# Function: Setup environment configuration
setup_environment() {
    log_message INFO "Setting up environment configuration..."
    
    cat > "$APP_DIR/.env" << EOF
# Smart Storage Manager Environment Configuration
# Generated: $(date)

# Service Configuration
SERVICE_PORT=$DEFAULT_PORT
SERVICE_HOST=$DEFAULT_HOST
SERVICE_USER=$SERVICE_USER

# Directories
APP_DIR=$APP_DIR
DATA_DIR=$DATA_DIR
CONFIG_DIR=$CONFIG_DIR
LOG_DIR=/var/log/$APP_ID

# Docker Configuration
DOCKER_IMAGE=$DOCKER_IMAGE
DOCKER_COMPOSE_VERSION=$DOCKER_COMPOSE_VERSION

# Timezone
TZ=$(cat /etc/timezone 2>/dev/null || echo "UTC")

# Process Settings
PUID=$(id -u $SERVICE_USER 2>/dev/null || echo "1000")
PGID=$(id -g $SERVICE_USER 2>/dev/null || echo "1000")

# Feature Flags
ENABLE_AUTO_UPDATE=$ENABLE_AUTO_UPDATE
ENABLE_NOTIFICATIONS=$ENABLE_NOTIFICATIONS
ENABLE_BACKUP=$ENABLE_BACKUP
ENABLE_MONITORING=$ENABLE_MONITORING

# Security
SECURITY_ENABLE_AUTH=true
SECURITY_RATE_LIMITING=true
SECURITY_MAX_REQUESTS_PER_MINUTE=60

# Logging
LOG_LEVEL=INFO
LOG_MAX_SIZE=10M
LOG_MAX_FILES=5

# Health Check
HEALTH_CHECK_INTERVAL=30
EOF

    log_message SUCCESS "Environment configuration created"
}

# Function: Build Docker images
build_docker_images() {
    log_message INFO "Building Docker images..."
    
    cd "$APP_DIR"
    
    # Pull base images first
    log_message INFO "Pulling base images..."
    docker compose pull || {
        log_message WARNING "Failed to pull base images, continuing with build"
    }
    
    # Build application images
    log_message INFO "Building application images..."
    docker compose build --quiet || {
        log_message ERROR "Docker build failed"
        exit $EXIT_SERVICE_FAILURE
    }
    
    log_message SUCCESS "Docker images built successfully"
}

# Function: Create systemd service
create_systemd_service() {
    log_message INFO "Creating systemd service..."
    
    cat > "${SYSTEMD_DIR}/${APP_ID}.service" << EOF
[Unit]
Description=Smart Storage Manager
Documentation=https://github.com/Free-dts/smart-storage-manager/wiki
After=docker.service nginx.service
Requires=docker.service
Wants=nginx.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
User=$SERVICE_USER
Group=$SERVICE_USER
Environment=APP_ENV=production
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$APP_ID".service
    
    log_message SUCCESS "Systemd service created and enabled"
}

# Function: Configure NGINX
configure_nginx() {
    log_message INFO "Configuring NGINX..."
    
    cat > "${NGINX_CONF_DIR}/${APP_ID}" << EOF
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Static files
    location /static/ {
        alias $APP_DIR/app/frontend/dist/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:$DEFAULT_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:$DEFAULT_PORT/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:$DEFAULT_PORT/health;
        access_log off;
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ \.(env|log|conf)$ {
        deny all;
    }
}
EOF

    # Enable site
    if [[ ! -L "/etc/nginx/sites-enabled/${APP_ID}" ]]; then
        ln -sf "${NGINX_CONF_DIR}/${APP_ID}" "/etc/nginx/sites-enabled/${APP_ID}"
    fi
    
    # Test NGINX configuration
    if ! nginx -t; then
        log_message ERROR "NGINX configuration test failed"
        exit $EXIT_SERVICE_FAILURE
    fi
    
    # Reload NGINX
    systemctl reload nginx
    
    log_message SUCCESS "NGINX configured"
}

# Function: Setup automated maintenance
setup_maintenance() {
    log_message INFO "Setting up automated maintenance..."
    
    # Create maintenance script
    cat > "/usr/local/bin/${APP_ID}-maintenance" << EOF
#!/usr/bin/env bash
# Smart Storage Manager - Automated Maintenance Script
# Version: $APP_VERSION

set -euo pipefail

LOG_FILE="/var/log/${APP_ID}/maintenance.log"
APP_DIR="$APP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MAINTENANCE] \$*" | tee -a "\$LOG_FILE"
}

log "Starting maintenance routine..."

# Change to app directory
cd "\$APP_DIR" || {
    log "ERROR: Failed to change to app directory"
    exit 1
}

# Check if service is running
if ! docker compose ps | grep -q "Up"; then
    log "WARNING: Service not running, skipping maintenance"
    exit 0
fi

# Run SnapRAID maintenance if configured
if command -v snapraid >/dev/null 2>&1; then
    log "Running SnapRAID maintenance..."
    docker exec \$(docker compose ps -q web) python3 -c "
import os
import sys
sys.path.append('/app')
from backend.snapraid_manager import SnapRAIDManager
manager = SnapRAIDManager()
manager.run_maintenance()
" || log "WARNING: SnapRAID maintenance failed"
fi

# Clean up old logs
find /var/log/${APP_ID} -name "*.log" -mtime +30 -delete 2>/dev/null || true

# Clean up old backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null || true

# System health check
docker compose exec -T web curl -f http://localhost:$DEFAULT_PORT/health >/dev/null 2>&1 && \
    log "Health check passed" || \
    log "WARNING: Health check failed"

log "Maintenance completed successfully"
EOF

    chmod +x "/usr/local/bin/${APP_ID}-maintenance"
    
    # Setup cron job
    (crontab -l 2>/dev/null | grep -v "${APP_ID}-maintenance"; echo "0 2 * * * /usr/local/bin/${APP_ID}-maintenance >> /var/log/${APP_ID}/maintenance.log 2>&1") | crontab - || {
        log_message WARNING "Failed to setup cron job"
    }
    
    log_message SUCCESS "Automated maintenance configured"
}

# Function: Start services
start_services() {
    log_message INFO "Starting services..."
    
    cd "$APP_DIR"
    
    # Start Docker services
    docker compose up -d || {
        log_message ERROR "Failed to start Docker services"
        exit $EXIT_SERVICE_FAILURE
    }
    
    # Wait for services to be ready
    log_message INFO "Waiting for services to start..."
    local attempts=30
    local delay=2
    
    for ((i=1; i<=attempts; i++)); do
        if curl -fsS --connect-timeout 5 "$HEALTH_ENDPOINT" >/dev/null 2>&1; then
            log_message SUCCESS "Service is healthy and ready"
            break
        fi
        
        if [[ $i -eq $attempts ]]; then
            log_message ERROR "Service failed to start within expected time"
            docker compose logs --tail=50
            exit $EXIT_SERVICE_FAILURE
        fi
        
        log_message INFO "Waiting for service... ($i/$attempts)"
        sleep $delay
    done
    
    # Start systemd service
    systemctl start "$APP_ID".service
    
    log_message SUCCESS "All services started successfully"
}

# Function: Health check
perform_health_check() {
    log_message INFO "Performing health check..."
    
    local health_score=0
    local max_score=100
    
    # Check Docker service
    if docker compose ps | grep -q "Up"; then
        ((health_score += 20))
        log_message SUCCESS "✓ Docker service is running"
    else
        log_message ERROR "✗ Docker service is not running"
    fi
    
    # Check health endpoint
    if curl -fsS --connect-timeout 10 "$HEALTH_ENDPOINT" >/dev/null 2>&1; then
        ((health_score += 30))
        log_message SUCCESS "✓ Health endpoint is accessible"
    else
        log_message ERROR "✗ Health endpoint is not accessible"
    fi
    
    # Check API endpoint
    if curl -fsS --connect-timeout 10 "$API_ENDPOINT" >/dev/null 2>&1; then
        ((health_score += 30))
        log_message SUCCESS "✓ API endpoint is accessible"
    else
        log_message ERROR "✗ API endpoint is not accessible"
    fi
    
    # Check systemd service
    if systemctl is-active "$APP_ID".service >/dev/null 2>&1; then
        ((health_score += 10))
        log_message SUCCESS "✓ Systemd service is active"
    else
        log_message ERROR "✗ Systemd service is not active"
    fi
    
    # Check NGINX
    if systemctl is-active nginx >/dev/null 2>&1; then
        ((health_score += 10))
        log_message SUCCESS "✓ NGINX is running"
    else
        log_message ERROR "✗ NGINX is not running"
    fi
    
    if [[ $health_score -ge 80 ]]; then
        log_message SUCCESS "Health check passed (Score: $health_score/$max_score)"
        return 0
    else
        log_message ERROR "Health check failed (Score: $health_score/$max_score)"
        return 1
    fi
}

# Function: Show installation summary
show_summary() {
    local install_duration=$((SECONDS - INSTALL_START_TIME))
    local ip_address=$(hostname -I | awk '{print $1}')
    
    echo ""
    print_color "$GREEN" "╔═══════════════════════════════════════════════════════════════╗"
    print_color "$GREEN" "║                                                               ║"
    print_color "$GREEN" "║              ✅ Installation completed successfully! ✅         ║"
    print_color "$GREEN" "║                                                               ║"
    print_color "$GREEN" "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$CYAN" "📊 Installation Summary:"
    echo "   Application: $APP_NAME"
    echo "   Version: $APP_VERSION"
    echo "   Duration: ${install_duration}s"
    echo "   Architecture: $ARCHITECTURE"
    echo ""
    print_color "$CYAN" "🌐 Access URLs:"
    echo "   Local: ${YELLOW}http://localhost:$DEFAULT_PORT${NC}"
    echo "   Network: ${YELLOW}http://$ip_address:$DEFAULT_PORT${NC}"
    echo "   Umbrel: ${YELLOW}http://umbrel.local:$DEFAULT_PORT${NC}"
    echo ""
    print_color "$CYAN" "🔧 Management Commands:"
    echo "   Status: ${YELLOW}systemctl status $APP_ID${NC}"
    echo "   Start: ${YELLOW}systemctl start $APP_ID${NC}"
    echo "   Stop: ${YELLOW}systemctl stop $APP_ID${NC}"
    echo "   Logs: ${YELLOW}journalctl -u $APP_ID -f${NC}"
    echo "   Docker: ${YELLOW}cd $APP_DIR && docker compose logs -f${NC}"
    echo ""
    print_color "$CYAN" "📁 Important Paths:"
    echo "   Application: $APP_DIR"
    echo "   Data: $DATA_DIR"
    echo "   Config: $CONFIG_DIR"
    echo "   Logs: /var/log/$APP_ID/"
    echo "   Backups: $BACKUP_DIR"
    echo ""
    print_color "$CYAN" "🛠️  Maintenance:"
    echo "   Automatic maintenance runs daily at 2:00 AM"
    echo "   Manual maintenance: ${YELLOW}/usr/local/bin/${APP_ID}-maintenance${NC}"
    echo "   Backup location: $BACKUP_DIR"
    echo ""
    print_color "$GREEN" "🎉 $APP_NAME is ready to use!"
    echo ""
    print_color "$YELLOW" "⚠️  Next Steps:"
    echo "   1. Configure your storage devices in the web interface"
    echo "   2. Set up MergerFS pools for your disks"
    echo "   3. Configure SnapRAID for data protection"
    echo "   4. Review security settings in the admin panel"
    echo ""
}

# Function: Cleanup on failure
cleanup_on_failure() {
    log_message ERROR "Installation failed, cleaning up..."
    
    ROLLBACK_IN_PROGRESS=true
    
    # Stop services
    if [[ -d "$APP_DIR" ]]; then
        cd "$APP_DIR"
        docker compose down >/dev/null 2>&1 || true
    fi
    
    # Remove systemd service
    if [[ -f "${SYSTEMD_DIR}/${APP_ID}.service" ]]; then
        systemctl stop "$APP_ID".service >/dev/null 2>&1 || true
        systemctl disable "$APP_ID".service >/dev/null 2>&1 || true
        rm -f "${SYSTEMD_DIR}/${APP_ID}.service"
        systemctl daemon-reload
    fi
    
    # Remove NGINX configuration
    if [[ -f "${NGINX_CONF_DIR}/${APP_ID}" ]]; then
        rm -f "${NGINX_CONF_DIR}/${APP_ID}"
        rm -f "/etc/nginx/sites-enabled/${APP_ID}"
        systemctl reload nginx >/dev/null 2>&1 || true
    fi
    
    # Remove directories (if force install)
    if [[ "$FORCE_INSTALL" == true ]]; then
        rm -rf "$APP_DIR" "$DATA_DIR" "$CONFIG_DIR" "$BACKUP_DIR"
        rm -f "/usr/local/bin/${APP_ID}-maintenance"
    fi
    
    # Remove cron job
    crontab -l 2>/dev/null | grep -v "${APP_ID}-maintenance" | crontab - 2>/dev/null || true
    
    # Remove service user (if force install)
    if [[ "$FORCE_INSTALL" == true ]] && id "$SERVICE_USER" &>/dev/null; then
        userdel "$SERVICE_USER" 2>/dev/null || true
    fi
    
    log_message SUCCESS "Cleanup completed"
}

# Function: Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit $EXIT_SUCCESS
                ;;
            --version|-v)
                echo "$APP_NAME v$APP_VERSION"
                exit $EXIT_SUCCESS
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --skip-frontend-build)
                SKIP_FRONTEND_BUILD=true
                shift
                ;;
            --disable-auto-update)
                ENABLE_AUTO_UPDATE=false
                shift
                ;;
            --disable-notifications)
                ENABLE_NOTIFICATIONS=false
                shift
                ;;
            --disable-backup)
                ENABLE_BACKUP=false
                shift
                ;;
            --disable-monitoring)
                ENABLE_MONITORING=false
                shift
                ;;
            *)
                log_message ERROR "Unknown option: $1"
                show_help
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    done
}

# Function: Show help
show_help() {
    cat << EOF
$APP_NAME Installation Script v$APP_VERSION

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -v, --version           Show version information
    --dry-run              Show what would be done without executing
    --verbose              Enable verbose output
    --force                Force installation over existing setup
    --skip-frontend-build  Skip frontend build process
    --disable-auto-update  Disable automatic updates
    --disable-notifications Disable notifications
    --disable-backup       Disable backup functionality
    --disable-monitoring   Disable monitoring features

Examples:
    # Standard installation
    sudo $0
    
    # Force installation (overwrite existing)
    sudo $0 --force
    
    # Dry run to see what would be done
    sudo $0 --dry-run
    
    # Skip frontend build for faster installation
    sudo $0 --skip-frontend-build

Requirements:
    - Debian-based Linux distribution
    - Root privileges
    - Internet connection
    - Minimum 2GB RAM, 10GB disk space

For more information, visit: https://github.com/Free-dts/smart-storage-manager
EOF
}

# Function: Main installation process
main_installation() {
    log_message INFO "Starting installation of $APP_NAME v$APP_VERSION"
    INSTALL_START_TIME=$SECONDS
    
    # Set trap for cleanup on failure
    trap cleanup_on_failure ERR
    
    # Run installation steps
    check_root
    check_architecture
    check_system_compatibility
    check_system_resources
    check_network_connectivity
    check_existing_installation
    
    update_package_lists
    install_system_dependencies
    install_nodejs
    install_docker
    install_mergerfs
    install_snapraid
    
    create_directories
    create_service_user
    download_application
    
    if [[ "$DRY_RUN" != true ]]; then
        build_frontend
        setup_environment
        build_docker_images
        create_systemd_service
        configure_nginx
        setup_maintenance
        start_services
        perform_health_check
    fi
    
    INSTALL_SUCCESS=true
    log_message SUCCESS "Installation completed successfully"
}

# Main execution
main() {
    # Save original umask
    ORIGINAL_UMASK=$(umask)
    
    # Initialize logging
    log_message INFO "Starting $APP_NAME installation script"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show header
    print_header
    
    # Handle dry run
    if [[ "$DRY_RUN" == true ]]; then
        log_message INFO "DRY RUN MODE - No changes will be made"
        print_color "$YELLOW" "This is a dry run. The following actions would be performed:"
        echo ""
        echo "✓ Check system compatibility"
        echo "✓ Install system dependencies"
        echo "✓ Install Node.js 20.x"
        echo "✓ Install Docker"
        echo "✓ Install MergerFS"
        echo "✓ Install SnapRAID"
        echo "✓ Create application directories"
        echo "✓ Download application"
        if [[ "$SKIP_FRONTEND_BUILD" != true ]]; then
            echo "✓ Build frontend"
        else
            echo "⚠ Skip frontend build"
        fi
        echo "✓ Setup environment configuration"
        echo "✓ Build Docker images"
        echo "✓ Create systemd service"
        echo "✓ Configure NGINX"
        echo "✓ Setup automated maintenance"
        echo "✓ Start services"
        echo "✓ Perform health check"
        echo ""
        print_color "$GREEN" "Dry run completed successfully!"
        exit $EXIT_SUCCESS
    fi
    
    # Run main installation
    if main_installation; then
        # Reset umask
        umask "$ORIGINAL_UMASK"
        
        # Show summary
        show_summary
        
        log_message SUCCESS "Installation script completed successfully"
        exit $EXIT_SUCCESS
    else
        log_message ERROR "Installation failed"
        cleanup_on_failure
        exit $EXIT_SERVICE_FAILURE
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi