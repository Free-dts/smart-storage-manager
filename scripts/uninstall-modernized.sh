#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Smart Storage Manager - Modernized Uninstall Script
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
declare -r BACKUP_DIR="/var/backups/smart-storage-manager"
declare -r SERVICE_USER="smart-storage"
declare -r SERVICE_GROUP="smart-storage"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_NOT_INSTALLED=3
readonly EXIT_USER_CANCELLED=4

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
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                               ║${NC}"
    echo -e "${RED}║       🗑️ $APP_NAME - Uninstall Script v$SCRIPT_VERSION       ║${NC}"
    echo -e "${RED}║                  Modernized Edition                        ║${NC}"
    echo -e "${RED}║                                                               ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Smart Storage Manager Uninstall Script v$SCRIPT_VERSION

WARNING: This will completely remove Smart Storage Manager from your system.

OPTIONS:
    -y, --yes              Skip confirmation prompts (DANGEROUS)
    -f, --force            Force uninstall even if not installed
    -k, --keep-data        Keep user data and configuration
    -b, --backup           Create backup before uninstall
    -c, --cleanup          Clean up all related packages (MergerFS, SnapRAID)
    -v, --verbose          Enable verbose output
    -h, --help             Show this help message

EXAMPLES:
    $SCRIPT_NAME                # Interactive uninstall with confirmations
    $SCRIPT_NAME --keep-data    # Uninstall but keep data directories
    $SCRIPT_NAME --backup       # Create backup then uninstall
    $SCRIPT_NAME --cleanup      # Complete uninstall including dependencies

SAFETY NOTES:
    - This script will stop and remove all Smart Storage Manager services
    - User data in /mnt/storage will NOT be automatically deleted
    - Configuration in /config/smart-storage can be optionally preserved
    - Use --backup to create a backup before uninstalling

For more information, visit: https://github.com/Free-dts/smart-storage-manager
EOF
}

# Validate command line arguments
validate_arguments() {
    local skip_confirm=0
    local force_uninstall=0
    local keep_data=0
    local create_backup=0
    local cleanup_packages=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                skip_confirm=1
                shift
                ;;
            -f|--force)
                force_uninstall=1
                shift
                ;;
            -k|--keep-data)
                keep_data=1
                shift
                ;;
            -b|--backup)
                create_backup=1
                shift
                ;;
            -c|--cleanup)
                cleanup_packages=1
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
    export SKIP_CONFIRM=$skip_confirm
    export FORCE_UNINSTALL=$force_uninstall
    export KEEP_DATA=$keep_data
    export CREATE_BACKUP=$create_backup
    export CLEANUP_PACKAGES=$cleanup_packages
    
    return 0
}

# Check if application is installed
check_installation() {
    log "INFO" "Checking current installation..."
    
    local is_installed=0
    
    # Check if application directory exists
    if [[ -d "$APP_DIR" ]]; then
        is_installed=1
        log "INFO" "Found application directory: $APP_DIR"
    fi
    
    # Check if systemd service exists
    if systemctl list-unit-files | grep -q "smart-storage-manager.service"; then
        is_installed=1
        log "INFO" "Found systemd service: smart-storage-manager.service"
    fi
    
    # Check if Docker containers exist
    if docker ps -a --format "table {{.Names}}" | grep -q "smart-storage-manager"; then
        is_installed=1
        log "INFO" "Found Docker containers"
    fi
    
    # Check if cron jobs exist
    if crontab -l 2>/dev/null | grep -q "smart-storage-maintenance"; then
        is_installed=1
        log "INFO" "Found cron jobs"
    fi
    
    if [[ $is_installed -eq 0 ]]; then
        log "INFO" "Smart Storage Manager does not appear to be installed"
        
        if [[ "${FORCE_UNINSTALL:-0}" != "1" ]]; then
            return $EXIT_NOT_INSTALLED
        else
            log "WARN" "Forcing uninstall despite not detecting installation"
            return 0
        fi
    fi
    
    # Gather installation information
    local version=$(cd "$APP_DIR" && git describe --tags --always 2>/dev/null || echo "unknown")
    log "INFO" "Installation detected - Version: $version"
    
    return 0
}

# Create backup before uninstall
create_backup() {
    log "INFO" "Creating backup before uninstall..."
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
    
    local backup_name="uninstall-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log "INFO" "Creating backup: $backup_path"
    
    # Create comprehensive backup
    local backup_items=()
    
    if [[ -d "$APP_DIR" ]]; then
        backup_items+=("$(basename "$APP_DIR")")
    fi
    
    if [[ -d "$CONFIG_DIR" ]]; then
        backup_items+=("$CONFIG_DIR")
    fi
    
    if [[ -d "$DATA_DIR" ]]; then
        backup_items+=("$DATA_DIR")
    fi
    
    if [[ ${#backup_items[@]} -eq 0 ]]; then
        log "WARN" "No data to backup"
        return 0
    fi
    
    # Create backup tarball
    tar -czf "$backup_path" \
        -C "/" \
        "${backup_items[@]}" 2>/dev/null || {
        log "WARN" "Failed to create complete backup"
        # Try partial backup
        for item in "${backup_items[@]}"; do
            if [[ -e "/$item" ]]; then
                local item_backup="${backup_path%.tar.gz}-$(basename "$item").tar.gz"
                tar -czf "$item_backup" -C "/" "$item" 2>/dev/null && \
                    log "INFO" "Created partial backup: $item_backup"
            fi
        done
    }
    
    # Verify backup
    if [[ -f "$backup_path" && -s "$backup_path" ]]; then
        local backup_size=$(du -h "$backup_path" | cut -f1)
        log "SUCCESS" "Backup created successfully: $backup_path ($backup_size)"
        echo "$backup_path" > "${BACKUP_DIR}/latest-uninstall"
        return 0
    else
        log "WARN" "Backup verification failed or backup is empty"
        return 0  # Don't fail uninstall if backup fails
    fi
}

# Stop and disable services
stop_services() {
    log "INFO" "Stopping Smart Storage Manager services..."
    
    # Stop systemd service
    if systemctl is-active --quiet smart-storage-manager.service 2>/dev/null; then
        log "INFO" "Stopping systemd service..."
        systemctl stop smart-storage-manager.service || {
            log "WARN" "Failed to stop systemd service"
        }
    fi
    
    if systemctl is-enabled --quiet smart-storage-manager.service 2>/dev/null; then
        log "INFO" "Disabling systemd service..."
        systemctl disable smart-storage-manager.service || {
            log "WARN" "Failed to disable systemd service"
        }
    fi
    
    # Remove systemd service file
    if systemctl list-unit-files | grep -q "smart-storage-manager.service"; then
        log "INFO" "Removing systemd service file..."
        rm -f /etc/systemd/system/smart-storage-manager.service || {
            log "WARN" "Failed to remove systemd service file"
        }
        systemctl daemon-reload || {
            log "WARN" "Failed to reload systemd daemon"
        }
    fi
    
    # Stop Docker containers
    if command -v docker &>/dev/null; then
        cd "$APP_DIR" 2>/dev/null || return 0
        
        if [[ -f "docker-compose.yml" ]]; then
            log "INFO" "Stopping Docker containers..."
            docker-compose down || {
                log "WARN" "Failed to stop Docker containers"
            }
        fi
        
        # Remove Docker images
        local container_names=$(docker ps -a --format "{{.Names}}" | grep "smart-storage-manager" || true)
        if [[ -n "$container_names" ]]; then
            log "INFO" "Removing Docker containers..."
            echo "$container_names" | xargs docker rm -f 2>/dev/null || {
                log "WARN" "Failed to remove some Docker containers"
            }
        fi
    fi
    
    log "SUCCESS" "Services stopped successfully"
    return 0
}

# Remove application files
remove_application() {
    log "INFO" "Removing application files..."
    
    # Remove main application directory
    if [[ -d "$APP_DIR" ]]; then
        log "INFO" "Removing application directory: $APP_DIR"
        rm -rf "$APP_DIR" || {
            log "ERROR" "Failed to remove application directory"
            return $EXIT_ERROR
        }
    fi
    
    # Remove configuration directory
    if [[ -d "$CONFIG_DIR" && "${KEEP_DATA:-0}" != "1" ]]; then
        log "INFO" "Removing configuration directory: $CONFIG_DIR"
        rm -rf "$CONFIG_DIR" || {
            log "WARN" "Failed to remove configuration directory"
        }
    elif [[ -d "$CONFIG_DIR" ]]; then
        log "INFO" "Keeping configuration directory as requested: $CONFIG_DIR"
    fi
    
    # Remove data directory
    if [[ -d "$DATA_DIR" && "${KEEP_DATA:-0}" != "1" ]]; then
        log "INFO" "Removing data directory: $DATA_DIR"
        rm -rf "$DATA_DIR" || {
            log "WARN" "Failed to remove data directory"
        }
    elif [[ -d "$DATA_DIR" ]]; then
        log "INFO" "Keeping data directory as requested: $DATA_DIR"
    fi
    
    # Remove Docker Compose wrapper script
    if [[ -f /usr/local/bin/docker-compose-wrapper ]]; then
        log "INFO" "Removing Docker Compose wrapper..."
        rm -f /usr/local/bin/docker-compose-wrapper || {
            log "WARN" "Failed to remove wrapper script"
        }
    fi
    
    log "SUCCESS" "Application files removed successfully"
    return 0
}

# Remove scheduled tasks
remove_scheduled_tasks() {
    log "INFO" "Removing scheduled tasks..."
    
    # Remove cron jobs
    local cron_backup="/tmp/smart-storage-cron-$(date +%Y%m%d-%H%M%S)"
    if crontab -l 2>/dev/null | grep -q "smart-storage"; then
        log "INFO" "Backing up and removing cron jobs..."
        
        # Backup current crontab
        crontab -l 2>/dev/null > "$cron_backup" || true
        
        # Remove Smart Storage Manager cron jobs
        (crontab -l 2>/dev/null | grep -v "smart-storage" | crontab -) || {
            log "WARN" "Failed to remove cron jobs"
        }
        
        log "INFO" "Cron jobs backed up to: $cron_backup"
    fi
    
    # Remove maintenance script
    if [[ -f /usr/local/bin/smart-storage-maintenance ]]; then
        log "INFO" "Removing maintenance script..."
        rm -f /usr/local/bin/smart-storage-maintenance || {
            log "WARN" "Failed to remove maintenance script"
        }
    fi
    
    # Remove logrotate configuration
    if [[ -f /etc/logrotate.d/smart-storage-manager ]]; then
        log "INFO" "Removing logrotate configuration..."
        rm -f /etc/logrotate.d/smart-storage-manager || {
            log "WARN" "Failed to remove logrotate configuration"
        }
    fi
    
    log "SUCCESS" "Scheduled tasks removed successfully"
    return 0
}

# Remove user and group
remove_user_group() {
    log "INFO" "Removing service user and group..."
    
    # Remove user
    if id "$SERVICE_USER" &>/dev/null; then
        log "INFO" "Removing user: $SERVICE_USER"
        userdel "$SERVICE_USER" 2>/dev/null || {
            log "WARN" "Failed to remove user $SERVICE_USER"
        }
    fi
    
    # Remove group
    if getent group "$SERVICE_GROUP" &>/dev/null; then
        log "INFO" "Removing group: $SERVICE_GROUP"
        groupdel "$SERVICE_GROUP" 2>/dev/null || {
            log "WARN" "Failed to remove group $SERVICE_GROUP"
        }
    fi
    
    log "SUCCESS" "User and group removal completed"
    return 0
}

# Clean up logs
cleanup_logs() {
    log "INFO" "Cleaning up log files..."
    
    if [[ -d "$LOG_DIR" ]]; then
        log "INFO" "Removing log directory: $LOG_DIR"
        rm -rf "$LOG_DIR" || {
            log "WARN" "Failed to remove log directory"
        }
    fi
    
    # Clean up systemd journal entries (if requested with force)
    if [[ "${FORCE_UNINSTALL:-0}" == "1" ]]; then
        log "INFO" "Cleaning up systemd journal entries..."
        journalctl --vacuum-time=1d 2>/dev/null || {
            log "WARN" "Failed to clean journal entries"
        }
    fi
    
    log "SUCCESS" "Log cleanup completed"
    return 0
}

# Clean up optional packages
cleanup_packages() {
    if [[ "${CLEANUP_PACKAGES:-0}" != "1" ]]; then
        log "INFO" "Skipping package cleanup (not requested)"
        return 0
    fi
    
    log "INFO" "Cleaning up related packages..."
    
    local packages_to_check=(
        "mergerfs"
        "snapraid"
        "smartmontools"
        "docker-compose"
    )
    
    for package in "${packages_to_check[@]}"; do
        if dpkg -l | grep -q "^ii.*$package"; then
            log "WARN" "Package $package is still installed"
            log "INFO" "Consider manually removing: apt remove $package"
            
            # Ask for confirmation to remove
            if [[ "${SKIP_CONFIRM:-0}" != "1" ]]; then
                echo -n "Remove $package? (y/N): "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    apt remove -y "$package" || {
                        log "WARN" "Failed to remove $package"
                    }
                fi
            fi
        fi
    done
    
    # Clean up apt cache
    log "INFO" "Cleaning up apt cache..."
    apt-get autoremove -y 2>/dev/null || {
        log "WARN" "Failed to autoremove packages"
    }
    
    apt-get autoclean 2>/dev/null || {
        log "WARN" "Failed to clean apt cache"
    }
    
    log "SUCCESS" "Package cleanup completed"
    return 0
}

# Verify uninstallation
verify_uninstall() {
    log "INFO" "Verifying uninstallation..."
    
    local issues_found=0
    
    # Check if systemd service still exists
    if systemctl list-unit-files | grep -q "smart-storage-manager.service"; then
        log "WARN" "Systemd service still exists"
        issues_found=$((issues_found + 1))
    fi
    
    # Check if Docker containers still exist
    if command -v docker &>/dev/null; then
        if docker ps -a --format "table {{.Names}}" | grep -q "smart-storage-manager"; then
            log "WARN" "Docker containers still exist"
            issues_found=$((issues_found + 1))
        fi
    fi
    
    # Check if cron jobs still exist
    if crontab -l 2>/dev/null | grep -q "smart-storage"; then
        log "WARN" "Cron jobs still exist"
        issues_found=$((issues_found + 1))
    fi
    
    # Check if user still exists
    if id "$SERVICE_USER" &>/dev/null; then
        log "WARN" "Service user still exists"
        issues_found=$((issues_found + 1))
    fi
    
    # Check if application directory still exists
    if [[ -d "$APP_DIR" ]]; then
        log "WARN" "Application directory still exists: $APP_DIR"
        issues_found=$((issues_found + 1))
    fi
    
    if [[ $issues_found -eq 0 ]]; then
        log "SUCCESS" "Uninstallation verification passed"
        return 0
    else
        log "WARN" "Uninstallation verification found $issues_found issues"
        log "INFO" "Some components may require manual cleanup"
        return 0  # Don't fail overall uninstall
    fi
}

# Show uninstall summary
show_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              🧹 Uninstallation Completed! 🧹                  ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📊 Uninstallation Summary:${NC}"
    echo -e "   App Name:  ${APP_NAME}"
    echo -e "   Uninstalled: $(date)"
    echo -e "   Version: $SCRIPT_VERSION"
    echo ""
    
    if [[ "${KEEP_DATA:-0}" == "1" ]]; then
        echo -e "${YELLOW}💾 Data Preservation:${NC}"
        echo -e "   Configuration: ${YELLOW}Preserved${NC} ($CONFIG_DIR)"
        echo -e "   User Data:     ${YELLOW}Preserved${NC} ($DATA_DIR)"
        echo -e "   Storage Data:  ${YELLOW}Preserved${NC} (/mnt/storage)"
        echo ""
    else
        echo -e "${GREEN}🗑️  Removed:${NC}"
        echo -e "   Configuration: ${GREEN}Removed${NC} ($CONFIG_DIR)"
        echo -e "   User Data:     ${GREEN}Removed${NC} ($DATA_DIR)"
        echo -e "   Storage Data:  ${YELLOW}Preserved${NC} (/mnt/storage - not affected)"
        echo ""
    fi
    
    echo -e "${CYAN}📋 Cleanup Actions Performed:${NC}"
    echo "   • Stopped and disabled all services"
    echo "   • Removed systemd service files"
    echo "   • Stopped and removed Docker containers"
    echo "   • Removed application and configuration files"
    echo "   • Removed cron jobs and maintenance scripts"
    echo "   • Cleaned up log files"
    
    if [[ "${CLEANUP_PACKAGES:-0}" == "1" ]]; then
        echo "   • Attempted to remove related packages"
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  Manual Actions Required:${NC}"
    echo "   • Restart your system to ensure all services are stopped"
    echo "   • Check /mnt/storage directory if you want to remove storage data"
    echo "   • Verify fstab entries if you had manual mount points"
    
    if [[ "${CLEANUP_PACKAGES:-0}" != "1" ]]; then
        echo "   • Manually remove packages: mergerfs, snapraid (if not needed)"
    fi
    
    echo ""
    echo -e "${CYAN}🔗 Useful Commands:${NC}"
    echo "   • Check storage: ${YELLOW}ls -la /mnt/storage${NC}"
    echo "   • View logs:     ${YELLOW}ls -la $BACKUP_DIR${NC}"
    echo "   • Reinstall:     ${YELLOW}curl -fsSL https://raw.githubusercontent.com/umbrel/smart-storage-manager/main/scripts/install.sh | bash${NC}"
    echo ""
    echo -e "${GREEN}✅ Smart Storage Manager has been successfully uninstalled!${NC}"
    echo ""
}

# Main uninstall function
main() {
    local skip_confirm="${SKIP_CONFIRM:-0}"
    local keep_data="${KEEP_DATA:-0}"
    local create_backup="${CREATE_BACKUP:-0}"
    local cleanup_packages="${CLEANUP_PACKAGES:-0}"
    
    # Validate arguments
    validate_arguments "${@}"
    
    # Start logging
    local log_file="${LOG_DIR}/uninstall.log"
    echo "=== Smart Storage Manager Uninstallation Started at $(date) ===" > "$log_file"
    
    print_header
    
    # Check if application is installed
    check_installation || return $?
    
    # Show warning and confirmation
    if [[ $skip_confirm -eq 0 ]]; then
        echo -e "${RED}⚠️  WARNING: This will completely remove Smart Storage Manager!${NC}"
        echo ""
        echo -e "${YELLOW}📋 Uninstallation will:${NC}"
        echo "   • Stop and remove all Smart Storage Manager services"
        echo "   • Remove application files from $APP_DIR"
        if [[ $keep_data -eq 1 ]]; then
            echo "   • ${YELLOW}Keep${NC} configuration and user data (--keep-data specified)"
        else
            echo "   • Remove configuration and user data"
        fi
        echo "   • Remove cron jobs and scheduled maintenance"
        echo "   • Clean up log files"
        if [[ $cleanup_packages -eq 1 ]]; then
            echo "   • Attempt to remove related packages (mergerfs, snapraid, etc.)"
        fi
        echo ""
        echo -e "${GREEN}✅ Will NOT be removed:${NC}"
        echo "   • Your storage data in /mnt/storage (safeguarded)"
        echo "   • Other system files and configurations"
        echo ""
        echo -e "${RED}This action CANNOT be undone!${NC}"
        echo ""
        
        if [[ $create_backup -eq 1 ]]; then
            echo -e "${CYAN}💾 A backup will be created before uninstalling${NC}"
            echo ""
        fi
        
        echo -n "Type 'UNINSTALL' to confirm: "
        read -r confirmation
        
        if [[ "$confirmation" != "UNINSTALL" ]]; then
            log "INFO" "Uninstallation cancelled by user"
            return $EXIT_USER_CANCELLED
        fi
        echo ""
    fi
    
    # Create backup if requested
    if [[ $create_backup -eq 1 ]]; then
        create_backup || {
            log "WARN" "Backup failed, continuing with uninstallation..."
        }
    fi
    
    # Run uninstallation steps
    local steps=(
        "stop_services"
        "remove_application"
        "remove_scheduled_tasks"
        "remove_user_group"
        "cleanup_logs"
        "cleanup_packages"
        "verify_uninstall"
    )
    
    local step_number=1
    local total_steps=${#steps[@]}
    local step_failed=0
    
    for step in "${steps[@]}"; do
        log "INFO" "Step $step_number/$total_steps: ${step//_/ }"
        
        if $step; then
            step_number=$((step_number + 1))
        else
            log "ERROR" "Uninstallation step failed: $step"
            step_failed=1
            break
        fi
    done
    
    # Show summary
    show_summary
    
    # Final logging
    echo "=== Smart Storage Manager Uninstallation Completed at $(date) ===" >> "$log_file"
    
    if [[ $step_failed -eq 1 ]]; then
        log "ERROR" "Some uninstallation steps failed, but basic cleanup completed"
        return $EXIT_ERROR
    else
        log "SUCCESS" "Uninstallation completed successfully"
        return $EXIT_SUCCESS
    fi
}

# Run main function with all arguments
main "$@"
