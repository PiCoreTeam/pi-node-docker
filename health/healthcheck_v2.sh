#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/pi-node-health.log"
MIN_DISK_GB=10
HORIZON_URL="http://localhost:8000"
CORE_PORT=11626

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH] $*" | tee -a "$LOG_FILE"
}

check_service() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    log "OK: $name"
    return 0
  else
    log "FAIL: $name"
    return 1
  fi
}

check_disk() {
  local avail
  avail=$(df -BG / | awk 'NR==2{gsub("G","",$4);print $4}')
  if (( avail < MIN_DISK_GB )); then
    log "FAIL: Disk space low (${avail}GB)"
    return 1
  fi
  log "OK: Disk space ${avail}GB"
}

main() {
  log "Starting health check..."

  check_service "Horizon API" "curl -sf ${HORIZON_URL}/" || return 1
  check_service "Stellar-Core Port" "nc -z localhost ${CORE_PORT}" || return 1
  check_service "PostgreSQL" "pg_isready" || return 1
  check_disk || return 1

  log "Health check PASSED"
  return 0
}

main
