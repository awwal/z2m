#!/bin/bash

# Backup and Restore Script for Zigbee2MQTT Docker Stack
# Usage: ./backup-restore.sh [backup|restore|list] [backup_file]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/z2m_backup_${TIMESTAMP}.tar.gz"

# Load .env if it exists
if [ -f .env ]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ ! "$line" =~ ^# && "$line" =~ = ]]; then
            export "${line%%=*}"="${line#*=}"
        fi
    done < .env
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to print messages
print_message() {
    local level=$1
    local message=$2

    case $level in
        success)
            echo -e "${GREEN}✓${NC} $message"
            ;;
        error)
            echo -e "${RED}✗${NC} $message"
            ;;
        warn)
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        info)
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Function to backup configuration and data
backup() {
    print_message "info" "Starting backup: $BACKUP_FILE"

    # Define paths to backup
    local z2m_data=${DATA_DIR:-./zigbee2mqtt/data}
    local z2m_config=${CONFIG_DIR:-./zigbee2mqtt/config}
    local mosq_config=${MOSQUITTO_CONFIG_DIR:-./mosquitto/config}
    local mosq_data=${MOSQUITTO_DATA_DIR:-./mosquitto/data}

    # Create backup archive
    tar -czf "$BACKUP_FILE" \
        --exclude="${z2m_data}/ota/*.bin" \
        "$z2m_config" \
        "$z2m_data" \
        "$mosq_config" \
        "$mosq_data" \
        docker-compose.yml \
        .env* \
        2>/dev/null || {
            print_message "error" "Backup failed"
            return 1
        }

    local backup_size=$(du -h "$BACKUP_FILE" | cut -f1)
    print_message "success" "Backup completed ($backup_size)"
}

# Function to restore from backup
restore() {
    local backup_file=$1

    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        print_message "error" "Valid backup file required"
        return 1
    fi

    print_message "warn" "Restoring from $backup_file. Current config will be overwritten!"
    read -p "Continue? (yes/no): " confirm
    [ "$confirm" != "yes" ] && { print_message "info" "Restore cancelled"; return 1; }

    print_message "info" "Stopping services and creating pre-restore backup..."
    docker compose down 2>/dev/null || true
    
    tar -czf "${BACKUP_DIR}/pre_restore_backup_${TIMESTAMP}.tar.gz" \
        "${CONFIG_DIR:-./zigbee2mqtt/config}" "${DATA_DIR:-./zigbee2mqtt/data}" 2>/dev/null || true

    print_message "info" "Extracting backup..."
    if tar -xzf "$backup_file"; then
        print_message "success" "Restore completed"
        docker compose up -d
    else
        print_message "error" "Restore failed"
        return 1
    fi
}

# Function to list backups
list_backups() {
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        print_message "warn" "No backups found"
        return
    fi

    echo "Available Backups:"
    ls -lh "$BACKUP_DIR"/z2m_backup*.tar.gz 2>/dev/null | awk '{print $9, "("$5")"}' || true
    
    echo -e "\nUsage: du -sh $BACKUP_DIR"
    du -sh "$BACKUP_DIR"
}

# Function to clean old backups
cleanup_old_backups() {
    local keep_days=${1:-7}
    print_message "info" "Cleaning backups older than $keep_days days..."

    [ ! -d "$BACKUP_DIR" ] && return

    find "$BACKUP_DIR" -name "z2m_backup*.tar.gz" -mtime +$keep_days -delete -print | while read -r file; do
        print_message "info" "Deleted: $(basename "$file")"
    done
    print_message "success" "Cleanup completed"
}

# Function to verify backup integrity
verify_backup() {
    local backup_file=$1

    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        print_message "error" "Valid backup file required"
        return 1
    fi

    print_message "info" "Verifying: $backup_file"

    if tar -tzf "$backup_file" > /dev/null 2>&1; then
        local size=$(du -h "$backup_file" | cut -f1)
        local count=$(tar -tzf "$backup_file" | wc -l)
        print_message "success" "Verified: $size, $count files"
    else
        print_message "error" "Backup corrupted"
        return 1
    fi
}

# Function to show help
show_help() {
    cat << EOF
Zigbee2MQTT Backup and Restore Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    backup                  Create a full system backup
    restore <file>         Restore from a backup file
    list                   List all available backups
    verify <file>          Verify backup integrity
    cleanup [days]         Remove backups older than specified days (default: 7)
    help                   Show this help message

EXAMPLES:
    # Create a backup
    $0 backup

    # List available backups
    $0 list

    # Restore latest backup
    $0 restore ./backups/z2m_backup_20240224_120000.tar.gz

    # Verify backup
    $0 verify ./backups/z2m_backup_20240224_120000.tar.gz

    # Clean backups older than 30 days
    $0 cleanup 30

BACKUP INCLUDES:
    - Zigbee2MQTT configuration and data
    - Mosquitto configuration and data
    - docker-compose.yml
    - .env files

NOTES:
    - Backups are stored in: $BACKUP_DIR
    - Pre-restore backups are automatically created
    - OTA binary files are excluded to save space
    - Always verify backups before critical restores

EOF
}

# Main
case "${1:-help}" in
    backup)
        backup
        ;;
    restore)
        restore "$2"
        ;;
    list)
        list_backups
        ;;
    verify)
        verify_backup "$2"
        ;;
    cleanup)
        cleanup_old_backups "$2"
        ;;
    help)
        show_help
        ;;
    *)
        print_message "error" "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

