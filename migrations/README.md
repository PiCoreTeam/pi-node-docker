# Migration Framework

## Directory Structure

```
/migrations/
├── migration_runner.sh       # Main control script
├── 001_enable_horizon_auto_migrations.sh  # Enable Horizon auto-migrations
├── docs/                                  # Human-readable migration guides
│   └── 001_enable_horizon_auto_migrations.md
└── README.md                 # This file

/opt/stellar/                 # Persisted volume
├── migration_status          # Tracks executed migrations (auto-created)
└── migration_backups/        # Backup files from migrations
```

## Usage

```bash
/migrations/migration_runner.sh
```

## Creating Migrations

### Naming: `NNN_description.sh`

```
001_init_database.sh
002_add_monitoring_config.sh
010_update_horizon_settings.sh
```

### Template

```bash
#!/usr/bin/env bash
set -e -u -o pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MIGRATION] [$1] ${@:2}"
}

main() {
    log "INFO" "Starting"

    # Check if already applied
    if [[ condition ]]; then
        log "OK" "Already applied"
        exit 0
    fi

    # Perform migration

    log "OK" "Completed"
}

main "$@"
```

## Status File

`/opt/stellar/migration_status` - auto-created on persisted volume, tracks executed migrations.

```
001_enable_horizon_auto_migrations.sh
```

## Logging

```
2025-02-03 10:30:45 [MIGRATION] [INFO] Starting Migration Runner
2025-02-03 10:30:45 [MIGRATION] [OK] Migration completed: 001_update_config.sh
2025-02-03 10:30:45 [MIGRATION] [SKIP] Already executed: 002_update_json_config.sh
2025-02-03 10:30:45 [MIGRATION] [ERROR] Migration failed: 003_bad_migration.sh
```

## Behavior

- Executes in alphanumeric order
- Stops immediately on error (fail-fast)
- Failed migrations are NOT marked as executed
- Re-runs failed migration on next execution
- Idempotent - safe to run multiple times

- Creates backups in `/opt/stellar/migration_backups/YYYYMMDD_HHMMSS/`

## Backups

Each run creates timestamped backup directory on persisted volume. Migrations use `$MIGRATION_BACKUP_DIR`:

```bash
# In your migration
cp "$FILE" "$MIGRATION_BACKUP_DIR/$(basename $FILE)"
```

Backup location: `/opt/stellar/migration_backups/20250203_173045/`
