#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Smart Storage Manager - Modernized Update Script
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
declare -r LOG_FILE="${LOG_DIR}/update.log"
declare -r BACKUP_DIR="/var/backups/smart-storage-manager"
declare -r ROLLBACK_FILE="${BACKUP_DIR}/rollback-$(date +%Y%m%d-%H%M%S).tar.gz"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_NOT_INSTALLED=3
readonly EXIT_UPDATE_FAILED=4
readonly EXIT_ROLLBACK_SUCCESS=5

# Version management
readonly CURRENT_VERSION="$SCRIPT_VERSION"
declare -r CHECK_UPDATE_URL="https://api.github.com/repos/umbrel/smart-storage-manager/releases/latest"
declare -r GITHUB_REPO="https://github.com/Free-dts/smart-storage-manager"

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
    echo -e "${PURPLE}║       🔄 $APP_NAME - Update Script v$SCRIPT_VERSION       ║${NC}"
    echo -e "${PURPLE}║                  Modernized Edition                        ║${NC}"
    echo -e "${PURPLE}║                                                               ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Smart Storage Manager Update Script v$SCRIPT_VERSION

OPTIONS:
    -c, --check         Check for available updates without updating
    -r, --rollback      Rollback to previous version
    -b, --backup        Create backup before update
    -f, --force         Force update even if not needed
    -y, --yes           Skip confirmation prompts
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

EXAMPLES:
    $SCRIPT_NAME              # Interactive update
    $SCRIPT_NAME --check      # Check for updates only
    $SCRIPT_NAME --backup     # Create backup
    $SCRIPT_NAME --rollback   # Rollback to previous version

For more information, visit: https://github.com/Free-dts/smart-storage-manager
EOF
}

# Validate command line arguments
validate_arguments() {
    local check_only=0
    local rollback=0
    local backup_first=0
    local force_update=0
    local skip_confirm=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--check)
                check_only=1
                shift
                ;;
            -r|--rollback)
                rollback=1
                shift
                ;;
            -b|--backup)
                backup_first=1
                shift
                ;;
            -f|--force)
                force_update=1
                shift
                ;;
            -y|--yes)
                skip_confirm=1
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
    
    # Set global flags based on parsed arguments
    if [[ $check_only -eq 1 ]]; then
        export CHECK_ONLY=1
    fi
    if [[ $rollback -eq 1 ]]; then
        export ROLLBACK_MODE=1
    fi
    if [[ $backup_first -eq 1 ]]; then
        export BACKUP_FIRST=1
    fi
    if [[ $force_update -eq 1 ]]; then
        export FORCE_UPDATE=1
    fi
    if [[ $skip_confirm -eq 1 ]]; then
        export SKIP_CONFIRM=1
    fi
    
    return 0
}

# Check if application is installed
check_installation() {
    log "INFO" "Checking current installation..."
    
    if [[ ! -d "$APP_DIR" ]]; then
        log "ERROR" "Smart Storage Manager is not installed"
        log "INFO" "Installation directory not found: $APP_DIR"
        return $EXIT_NOT_INSTALLED
    fi
    
    if [[ ! -f "${APP_DIR}/.env" ]]; then
        log "ERROR" "Configuration file not found"
        return $EXIT_NOT_INSTALLED
    fi
    
    # Check if it's a git repository
    if [[ ! -d "$APP_DIR/.git" ]]; then
        log "WARN" "Not a git repository, updates may be limited"
        return 0
    fi
    
    # Get current version
    local current_version=$(cd "$APP_DIR" && git describe --tags --always 2>/dev/null || echo "unknown")
    log "INFO" "Current version: $current_version"
    
    return 0
}

# Get latest version from GitHub
get_latest_version() {
    log "INFO" "Checking for latest version..."
    
    # Try to get version from GitHub API
    if command -v curl &>/dev/null; then
        local api_response=$(curl -s "$CHECK_UPDATE_URL" 2>/dev/null || echo "")
        local latest_version=$(echo "$api_response" | jq -r '.tag_name' 2>/dev/null || echo "")
        
        if [[ -n "$latest_version" && "$latest_version" != "null" ]]; then
            echo "$latest_version"
            return 0
        fi
    fi
    
    # Fallback: try to get from git
    if command -v git &>/dev/null && [[ -d "$APP_DIR/.git" ]]; then
        local git_version=$(cd "$APP_DIR" && git fetch --all --tags 2>/dev/null && git describe --tags --abbrev=0 2>/dev/null || echo "")
        if [[ -n "$git_version" ]]; then
            echo "$git_version"
            return 0
        fi
    fi
    
    log "ERROR" "Could not determine latest version"
    return $EXIT_ERROR
}

# Create backup before update
create_backup() {
    log "INFO" "Creating backup before update..."
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
    
    # Create comprehensive backup
    local backup_name="backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log "INFO" "Creating backup: $backup_path"
    
    # Create backup tarball
    tar -czf "$backup_path" \
        -C "$(dirname "$APP_DIR")" \
        "$(basename "$APP_DIR")" \
        "$CONFIG_DIR" \
        "$DATA_DIR" 2>/dev/null || {
        log "ERROR" "Failed to create backup"
        return $EXIT_ERROR
    }
    
    # Verify backup
    if [[ -f "$backup_path" && -s "$backup_path" ]]; then
        local backup_size=$(du -h "$backup_path" | cut -f1)
        log "SUCCESS" "Backup created successfully: $backup_path ($backup_size)"
        
        # Store backup path for potential rollback
        echo "$backup_path" > "${BACKUP_DIR}/latest"
        return 0
    else
        log "ERROR" "Backup verification failed"
        rm -f "$backup_path"
        return $EXIT_ERROR
    fi
}

# Check for updates
check_for_updates() {
    log "INFO" "Checking for available updates..."
    
    # Get current version
    local current_version=$(cd "$APP_DIR" && git describe --tags --always 2>/dev/null || echo "unknown")
    local latest_version=$(get_latest_version)
    
    if [[ $? -ne 0 ]]; then
        log "WARN" "Could not check for updates"
        return $EXIT_ERROR
    fi
    
    log "INFO" "Current version: $current_version"
    log "INFO" "Latest version:  $latest_version"
    
    # Compare versions (simplified)
    if [[ "$current_version" == "$latest_version" ]]; then
        log "SUCCESS" "Smart Storage Manager is already up to date"
        return $EXIT_SUCCESS
    else
        log "INFO" "Update available: $current_version -> $latest_version"
        return 1  # Update available
    fi
}

# Stop services before update
stop_services() {
    log "INFO" "Stopping Smart Storage Manager services..."
    
    # Stop systemd service
    if systemctl is-active --quiet smart-storage-manager.service; then
        log "INFO" "Stopping systemd service..."
        systemctl stop smart-storage-manager.service || {
            log "WARN" "Failed to stop systemd service"
        }
    fi
    
    # Stop Docker containers
    if [[ -f "${APP_DIR}/docker-compose.yml" ]]; then
        cd "$APP_DIR"
        docker-compose down || {
            log "WARN" "Failed to stop Docker containers"
        }
    fi
    
    log "SUCCESS" "Services stopped successfully"
    return 0
}

# Update application code
update_application() {
    log "INFO" "Updating Smart Storage Manager application..."
    
    cd "$APP_DIR"
    
    # Stash any local changes
    if git diff --quiet; then
        log "INFO" "No local changes to stash"
    else
        log "INFO" "Stashing local changes..."
        git stash push -m "Auto-stash before update $(date)" || {
            log "WARN" "Failed to stash local changes"
        }
    fi
    
    # Fetch latest changes
    log "INFO" "Fetching latest changes..."
    git fetch --all --tags || {
        log "ERROR" "Failed to fetch latest changes"
        return $EXIT_ERROR
    }
    
    # Get latest version
    local latest_version=$(get_latest_version)
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to get latest version"
        return $EXIT_ERROR
    fi
    
    # Checkout latest version
    log "INFO" "Updating to version: $latest_version"
    git checkout "$latest_version" || {
        log "ERROR" "Failed to checkout latest version"
        return $EXIT_ERROR
    }
    
    # Verify update
    local updated_version=$(git describe --tags --always 2>/dev/null || echo "unknown")
    log "SUCCESS" "Application updated successfully"
    log "INFO" "New version: $updated_version"
    
    return 0
}

# Update Docker images
update_docker_images() {
    log "INFO" "Updating Docker images..."
    
    cd "$APP_DIR"
    
    # Pull latest images
    if [[ -f "${APP_DIR}/docker-compose.yml" ]]; then
        docker-compose pull || {
            log "WARN" "Failed to pull latest Docker images"
            # Try building from local Dockerfile
            log "INFO" "Building Docker image from local Dockerfile..."
            docker-compose build || {
                log "ERROR" "Failed to build Docker image"
                return $EXIT_ERROR
            }
        }
    else
        log "WARN" "No docker-compose.yml found, skipping Docker update"
    fi
    
    log "SUCCESS" "Docker images updated successfully"
    return 0
}

# Update frontend application
update_frontend() {
    log "INFO" "Updating frontend application..."
    
    cd "$APP_DIR/app/frontend"
    
    # Check if package.json exists
    if [[ ! -f "package.json" ]]; then
        log "WARN" "No package.json found, skipping frontend update"
        return 0
    fi
    
    # Check if Node.js is available
    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        log "WARN" "Node.js or npm not available, skipping frontend update"
        return 0
    fi
    
    # Update dependencies
    log "INFO" "Updating frontend dependencies..."
    npm ci --silent || {
        log "WARN" "Failed to update with npm ci, trying npm install"
        npm install --silent || {
            log "WARN" "Failed to update dependencies, trying existing build"
        }
    }
    
    # Build application
    if [[ -d "node_modules" ]]; then
        log "INFO" "Building frontend application..."
        npm run build || {
            log "WARN" "Frontend build failed, using previous build"
        }
    fi
    
    log "SUCCESS" "Frontend update completed"
    return 0
}

# Start services after update
start_services() {
    log "INFO" "Starting Smart Storage Manager services..."
    
    cd "$APP_DIR"
    
    # Start Docker containers
    if [[ -f "${APP_DIR}/docker-compose.yml" ]]; then
        docker-compose up -d || {
            log "ERROR" "Failed to start Docker containers"
            return $EXIT_ERROR
        }
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
            return $EXIT_ERROR
        fi
    done
    
    # Start systemd service
    if systemctl is-enabled --quiet smart-storage-manager.service 2>/dev/null; then
        systemctl start smart-storage-manager.service || {
            log "WARN" "Failed to start systemd service"
        }
    fi
    
    log "SUCCESS" "All services started successfully"
    return 0
}

# Verify update
verify_update() {
    log "INFO" "Verifying update..."
    
    local tests_passed=0
    local tests_total=3
    
    # Test 1: Health check
    if curl -sf http://localhost:8850/health &>/dev/null; then
        log "SUCCESS" "✓ Health check passed"
        tests_passed=$((tests_passed + 1))
    else
        log "ERROR" "✗ Health check failed"
    fi
    
    # Test 2: API status
    if curl -sf http://localhost:8850/api/status &>/dev/null; then
        log "SUCCESS" "✓ API status check passed"
        tests_passed=$((tests_passed + 1))
    else
        log "ERROR" "✗ API status check failed"
    fi
    
    # Test 3: Docker containers
    if docker ps | grep -q smart-storage-manager; then
        log "SUCCESS" "✓ Docker container check passed"
        tests_passed=$((tests_passed + 1))
    else
        log "ERROR" "✗ Docker container check failed"
    fi
    
    log "INFO" "Verification tests passed: $tests_passed/$tests_total"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log "SUCCESS" "Update verification successful"
        return 0
    else
        log "ERROR" "Update verification failed"
        return $EXIT_ERROR
    fi
}

# Rollback to previous version
rollback_update() {
    log "INFO" "Starting rollback process..."
    
    # Find latest backup
    local backup_file=""
    if [[ -f "${BACKUP_DIR}/latest" ]]; then
        backup_file=$(cat "${BACKUP_DIR}/latest")
    else
        # Find most recent backup
        backup_file=$(find "$BACKUP_DIR" -name "backup-*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    fi
    
    if [[ -z "$backup_file" || ! -f "$backup_file" ]]; then
        log "ERROR" "No backup file found for rollback"
        return $EXIT_ERROR
    fi
    
    log "INFO" "Rolling back using backup: $backup_file"
    
    # Stop services
    stop_services
    
    # Remove current installation
    log "INFO" "Removing current installation..."
    rm -rf "$APP_DIR" "$DATA_DIR" "$CONFIG_DIR" || {
        log "ERROR" "Failed to remove current installation"
        return $EXIT_ERROR
    }
    
    # Restore from backup
    log "INFO" "Restoring from backup..."
    cd "$(dirname "$APP_DIR")"
    tar -xzf "$backup_file" || {
        log "ERROR" "Failed to restore from backup"
        return $EXIT_ERROR
    }
    
    # Start services
    start_services
    
    # Verify rollback
    if verify_update; then
        log "SUCCESS" "Rollback completed successfully"
        return $EXIT_ROLLBACK_SUCCESS
    else
        log "ERROR" "Rollback verification failed"
        return $EXIT_ERROR
    fi
}

# Clean up old backups
cleanup_backups() {
    log "INFO" "Cleaning up old backups..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        return 0
    fi
    
    # Keep only last 5 backups
    local backup_count=$(find "$BACKUP_DIR" -name "backup-*.tar.gz" -type f | wc -l)
    
    if [[ $backup_count -gt 5 ]]; then
        find "$BACKUP_DIR" -name "backup-*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | head -n $((backup_count - 5)) | cut -d' ' -f2- | xargs rm -f || {
            log "WARN" "Failed to clean up some old backups"
        }
        log "INFO" "Cleaned up old backups, keeping latest 5"
    else
        log "DEBUG" "No cleanup needed, backup count: $backup_count"
    fi
    
    return 0
}

# Show update summary
show_summary() {
    local new_version=$(cd "$APP_DIR" && git describe --tags --always 2>/dev/null || echo "unknown")
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              ✅ Update Completed Successfully! ✅             ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📊 Update Summary:${NC}"
    echo -e "   App Name:  ${APP_NAME}"
    echo -e "   New Version: ${new_version}"
    echo -e "   Updated:   $(date)"
    echo -e "   Location:  ${APP_DIR}"
    echo ""
    echo -e "${CYAN}🌐 Access Information:${NC}"
    echo -e "   Web UI:    ${YELLOW}http://localhost:8850${NC}"
    echo -e "   Health:    ${YELLOW}http://localhost:8850/health${NC}"
    echo ""
    echo -e "${CYAN}⚡ Management Commands:${NC}"
    echo -e "   Status:    ${YELLOW}systemctl status smart-storage-manager${NC}"
    echo -e "   Restart:   ${YELLOW}systemctl restart smart-storage-manager${NC}"
    echo -e "   Logs:      ${YELLOW}journalctl -u smart-storage-manager -f${NC}"
    echo ""
    echo -e "${CYAN}💾 Backup Information:${NC}"
    echo -e "   Backups:   ${YELLOW}${BACKUP_DIR}${NC}"
    echo -e "   Rollback:  ${YELLOW}$SCRIPT_NAME --rollback${NC}"
    echo ""
    echo -e "${GREEN}🎉 Smart Storage Manager has been updated successfully!${NC}"
    echo ""
}

# Main update function
main() {
    local check_only="${CHECK_ONLY:-0}"
    local rollback_mode="${ROLLBACK_MODE:-0}"
    local backup_first="${BACKUP_FIRST:-0}"
    local force_update="${FORCE_UPDATE:-0}"
    local skip_confirm="${SKIP_CONFIRM:-0}"
    
    # Validate arguments
    validate_arguments "${@}"
    
    # Start logging
    echo "=== Smart Storage Manager Update Started at $(date) ===" > "$LOG_FILE"
    
    print_header
    
    # Check if application is installed
    check_installation || return $?
    
    # Handle rollback mode
    if [[ "${ROLLBACK_MODE:-0}" == "1" ]]; then
        log "INFO" "Rollback mode requested"
        rollback_update
        local rollback_result=$?
        
        if [[ $rollback_result -eq $EXIT_ROLLBACK_SUCCESS ]]; then
            log "SUCCESS" "Rollback completed successfully"
        else
            log "ERROR" "Rollback failed"
        fi
        
        return $rollback_result
    fi
    
    # Check for updates
    if ! check_for_updates && [[ "${FORCE_UPDATE:-0}" != "1" ]]; then
        if [[ "${CHECK_ONLY:-0}" == "1" ]]; then
            return $EXIT_SUCCESS
        fi
        log "INFO" "No updates available"
        return $EXIT_SUCCESS
    fi
    
    # Show update confirmation
    if [[ $skip_confirm -eq 0 && "${CHECK_ONLY:-0}" != "1" ]]; then
        local current_version=$(cd "$APP_DIR" && git describe --tags --always 2>/dev/null || echo "unknown")
        local latest_version=$(get_latest_version)
        
        echo -e "${YELLOW}📋 Update Information:${NC}"
        echo "   Current Version: $current_version"
        echo "   Latest Version:  $latest_version"
        echo "   Update Time:     $(date)"
        echo ""
        echo -e "${YELLOW}⚠️  This update will:${NC}"
        echo "   • Stop Smart Storage Manager services"
        echo "   • Update application code to latest version"
        echo "   • Update Docker images"
        echo "   • Rebuild frontend if needed"
        echo "   • Restart all services"
        echo "   • Verify update completion"
        echo ""
        
        if [[ $backup_first -eq 0 ]]; then
            echo -e "${YELLOW}💾 Backup Recommendation:${NC}"
            echo "   It's recommended to create a backup before updating."
            echo "   Use: $SCRIPT_NAME --backup"
            echo ""
        fi
        
        read -p "Continue with update? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Update cancelled by user"
            return $EXIT_SUCCESS
        fi
        echo ""
    fi
    
    # Create backup if requested
    if [[ $backup_first -eq 1 ]]; then
        create_backup || {
            log "ERROR" "Backup failed, aborting update"
            return $EXIT_ERROR
        }
    fi
    
    # Run update steps
    local steps=(
        "stop_services"
        "update_application"
        "update_docker_images"
        "update_frontend"
        "start_services"
        "verify_update"
    )
    
    local step_number=1
    local total_steps=${#steps[@]}
    
    for step in "${steps[@]}"; do
        log "INFO" "Step $step_number/$total_steps: ${step//_/ }"
        
        if $step; then
            step_number=$((step_number + 1))
        else
            log "ERROR" "Update failed at step: $step"
            log "INFO" "You can rollback using: $SCRIPT_NAME --rollback"
            return $EXIT_UPDATE_FAILED
        fi
    done
    
    # Clean up old backups
    cleanup_backups
    
    # Show summary
    show_summary
    
    # Final logging
    echo "=== Smart Storage Manager Update Completed Successfully at $(date) ===" >> "$LOG_FILE"
    
    return $EXIT_SUCCESS
}

# Run main function with all arguments
main "$@"
