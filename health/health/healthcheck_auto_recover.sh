#!/usr/bin/env bash
set -euo pipefail

CHECK_SCRIPT="/opt/stellar/health/healthcheck.sh"
ALERT_SCRIPT="/opt/stellar/health/alert_manager.sh"
LOG_FILE="/var/log/pi-node-recover.log"

MAX_RETRIES=5
BASE_DELAY=10

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RECOVER] $*" | tee -a "$LOG_FILE"
}

attempt_recover() {
  local retry=0
  while (( retry < MAX_RETRIES )); do
    if "$CHECK_SCRIPT"; then
      log "Node healthy again"
      "$ALERT_SCRIPT" "Node recovered successfully" "info"
      return 0
    fi

    delay=$(( BASE_DELAY * (2 ** retry) ))
    log "Health failed. Restarting services... attempt=$((retry+1)) wait=${delay}s"
    "$ALERT_SCRIPT" "Node unhealthy. Restart attempt $((retry+1))" "warning"

    docker compose restart pi-node || true
    sleep "$delay"

    ((retry++))
  done

  log "Max retries reached. Node still unhealthy."
  "$ALERT_SCRIPT" "CRITICAL: Node recovery failed after $MAX_RETRIES attempts" "critical"
  return 1
}

main() {
  if ! "$CHECK_SCRIPT"; then
    log "Health check failed → starting recovery"
    attempt_recover
  fi
}

main
