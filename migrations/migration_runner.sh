#!/usr/bin/env bash

################################################################################
# Migration Runner Script
#
# Purpose: Execute database/configuration migrations in a containerized environment
# Location: /migrations/migration_runner.sh (in container)
# Tracker: /opt/stellar/migration_status (persisted volume)
#
# Features:
# - Executes .sh migration scripts in alphanumeric order
# - Tracks completed migrations to prevent re-execution
# - Idempotent execution
################################################################################

# Strict error handling
set -e          # Exit immediately if a command exits with a non-zero status
set -u          # Treat unset variables as an error
set -o pipefail # Return value of a pipeline is the status of the last command to exit with a non-zero status

# Configuration
readonly MIGRATIONS_DIR="/migrations"
readonly STELLAR_HOME="/opt/stellar"
readonly MIGRATION_STATUS_FILE="${STELLAR_HOME}/migration_status"
readonly MIGRATION_BACKUP_BASE="${STELLAR_HOME}/migration_backups"
readonly LOG_PREFIX="[MIGRATION]"

################################################################################
# Logging function with timestamp and status indicator
################################################################################
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        OK)
            echo "${timestamp} ${LOG_PREFIX} [OK] ${message}"
            ;;
        SKIP)
            echo "${timestamp} ${LOG_PREFIX} [SKIP] ${message}"
            ;;
        ERROR)
            echo "${timestamp} ${LOG_PREFIX} [ERROR] ${message}" >&2
            ;;
        INFO)
            echo "${timestamp} ${LOG_PREFIX} [INFO] ${message}"
            ;;
        *)
            echo "${timestamp} ${LOG_PREFIX} ${message}"
            ;;
    esac
}

################################################################################
# Initialize migration status file if it doesn't exist
################################################################################
initialize_status_file() {
    if [[ ! -f "${MIGRATION_STATUS_FILE}" ]]; then
        log INFO "Initializing migration status file: ${MIGRATION_STATUS_FILE}"
        touch "${MIGRATION_STATUS_FILE}"
        log OK "Migration status file created"
    else
        log INFO "Migration status file exists: ${MIGRATION_STATUS_FILE}"
    fi
}

################################################################################
# Check if a migration has already been executed
################################################################################
is_migration_executed() {
    local migration_name="$1"

    if grep -Fxq "${migration_name}" "${MIGRATION_STATUS_FILE}"; then
        return 0  # Migration was executed
    else
        return 1  # Migration not executed
    fi
}

################################################################################
# Mark a migration as executed
################################################################################
mark_migration_executed() {
    local migration_name="$1"
    echo "${migration_name}" >> "${MIGRATION_STATUS_FILE}"
    log OK "Marked migration as executed: ${migration_name}"
}

################################################################################
# Create backup directory for this migration run
################################################################################
create_backup_dir() {
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    readonly BACKUP_DIR="${MIGRATION_BACKUP_BASE}/${timestamp}"

    if [[ ! -d "${BACKUP_DIR}" ]]; then
        mkdir -p "${BACKUP_DIR}"
        log INFO "Backup directory created: ${BACKUP_DIR}"
    fi

    # Export for use in migration scripts
    export MIGRATION_BACKUP_DIR="${BACKUP_DIR}"
}

################################################################################
# Execute a single migration script
################################################################################
execute_migration() {
    local migration_file="$1"
    local migration_name
    migration_name=$(basename "${migration_file}")

    log INFO "Executing migration: ${migration_name}"

    # Execute the migration script
    # The script will inherit set -e, so any error will cause immediate exit
    if bash "${migration_file}"; then
        mark_migration_executed "${migration_name}"
        log OK "Migration completed successfully: ${migration_name}"
        return 0
    else
        log ERROR "Migration failed: ${migration_name}"
        log ERROR "Aborting migration process due to failure"
        exit 1
    fi
}

################################################################################
# Main migration runner logic
################################################################################
main() {
    log INFO "=========================================="
    log INFO "Starting Migration Runner"
    log INFO "=========================================="
    log INFO "Migrations directory: ${MIGRATIONS_DIR}"
    log INFO "Status file: ${MIGRATION_STATUS_FILE}"

    # Ensure migrations directory exists
    if [[ ! -d "${MIGRATIONS_DIR}" ]]; then
        log ERROR "Migrations directory does not exist: ${MIGRATIONS_DIR}"
        exit 1
    fi

    # Initialize status file
    initialize_status_file

    # Create backup directory for this run
    create_backup_dir

    # Find all .sh files in migrations directory, sorted alphanumerically
    # Exclude the migration_status file and the runner script itself
    local migration_files
    migration_files=$(find "${MIGRATIONS_DIR}" -maxdepth 1 -type f -name "*.sh" ! -name "migration_runner.sh" | sort)

    if [[ -z "${migration_files}" ]]; then
        log INFO "No migration scripts found in ${MIGRATIONS_DIR}"
        log INFO "Migration runner completed successfully"
        return 0
    fi

    local total_count=0
    local executed_count=0
    local skipped_count=0

    # Process each migration file
    while IFS= read -r migration_file; do
        ((total_count++)) || true

        local migration_name
        migration_name=$(basename "${migration_file}")

        # Check if migration has already been executed
        if is_migration_executed "${migration_name}"; then
            log SKIP "Migration already executed: ${migration_name}"
            ((skipped_count++)) || true
        else
            # Execute the migration
            execute_migration "${migration_file}"
            ((executed_count++)) || true
        fi
    done <<< "${migration_files}"

    # Summary
    log INFO "=========================================="
    log INFO "Migration Runner Summary"
    log INFO "=========================================="
    log INFO "Total migrations found: ${total_count}"
    log INFO "Migrations executed: ${executed_count}"
    log INFO "Migrations skipped: ${skipped_count}"
    log OK "All migrations completed successfully"
}

# Execute main function
main "$@"

