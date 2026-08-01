#!/usr/bin/env bash
set -euo pipefail

CONFIG="/opt/stellar/health/alert_config.env"
LOG_FILE="/var/log/pi-node-alerts.log"

source "$CONFIG"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ALERT] $*" >> "$LOG_FILE"
}

send_telegram() {
  local msg="$1"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TG_CHAT_ID}" \
    -d text="$msg" >/dev/null
}

send_alert() {
  local text="$1"
  local level="${2:-info}"

  message="[$(hostname)] [$level] $text"
  log "$message"

  if [[ "${ENABLE_TELEGRAM}" == "true" ]]; then
    send_telegram "$message"
  fi
}

if [[ $# -ge 1 ]]; then
  send_alert "$1" "${2:-info}"
fi
