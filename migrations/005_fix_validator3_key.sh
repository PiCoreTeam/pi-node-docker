#!/usr/bin/env bash
#
# Migration 005: Replace the 3rd [[VALIDATORS]] block in stellar-core.cfg
#
# Finds the 3rd [[VALIDATORS]] section, verifies it is validator3,
# and replaces the entire block with the correct values.
#

set -euo pipefail

CORE_CFG="/opt/stellar/core/etc/stellar-core.cfg"
BACKUP_DIR="${MIGRATION_BACKUP_DIR:-/opt/stellar/migration_backups}"

EXPECTED_KEY="GAXTE5AV5OCOEGJE4OPVMN5UJHAKDQCSVMXI4P7SZIGQXVO7LP4JKX4M"
EXPECTED_ADDR="34.64.252.77:31402"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [005] [INFO]  $*"; }
ok()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [005] [OK]    $*"; }
die() { echo "$(date '+%Y-%m-%d %H:%M:%S') [005] [ERROR] $*" >&2; exit 1; }

CORRECT_BLOCK=$(cat <<EOF
[[VALIDATORS]]
NAME="validator3"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="${EXPECTED_KEY}"
ADDRESS="${EXPECTED_ADDR}"
HISTORY="curl -sf https://history.mainnet.minepi.com/{0} -o {1}"
EOF
)

verify_field() {
  local field="$1" expected="$2"
  local actual
  actual=$(awk '/^\[\[VALIDATORS\]\]/{n++} n==3 && /'"$field"'=/' "$CORE_CFG")
  echo "$actual" | grep -qF "$expected" \
    || die "Verification failed: $field incorrect in validator3"
}

# --- Main ---

log "Starting migration: Replace 3rd validator block"

[[ -f "$CORE_CFG" ]] || die "Core config not found: $CORE_CFG"
grep -qE 'NETWORK_PASSPHRASE\s*=\s*"Pi Network"' "$CORE_CFG" \
  || { ok "Not mainnet — skipping"; exit 0; }

# Pre-check: 3rd [[VALIDATORS]] must be validator3
third_name=$(awk '/^\[\[VALIDATORS\]\]/{n++} n==3 && /NAME=/{print; exit}' "$CORE_CFG")
[[ -n "$third_name" ]] || die "Could not find 3rd [[VALIDATORS]] section"
echo "$third_name" | grep -qF '"validator3"' \
  || die "3rd [[VALIDATORS]] is not validator3 — aborting"

# Backup
mkdir -p "$BACKUP_DIR"
cp "$CORE_CFG" "$BACKUP_DIR/stellar-core.cfg.$(date +%Y%m%d_%H%M%S)"
log "Backup created"

# Replace the 3rd [[VALIDATORS]] block
awk -v replacement="$CORRECT_BLOCK" '
  /^\[\[VALIDATORS\]\]/ { vcount++ }
  vcount == 3 && /^\[\[VALIDATORS\]\]/ { in_third = 1; print replacement "\n"; next }
  in_third && /^\[/                    { in_third = 0; print; next }
  in_third                             { next }
                                       { print }
' "$CORE_CFG" > "${CORE_CFG}.tmp"
mv "${CORE_CFG}.tmp" "$CORE_CFG"

# Verify
verify_field "PUBLIC_KEY" "$EXPECTED_KEY"
verify_field "ADDRESS"    "$EXPECTED_ADDR"

ok "Migration completed successfully"
