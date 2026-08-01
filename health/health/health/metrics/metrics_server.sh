#!/usr/bin/env bash
set -euo pipefail

PORT=9105
METRICS_SCRIPT="/opt/stellar/metrics/node_metrics.sh"

while true; do
  { 
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
    bash "$METRICS_SCRIPT"
  } | nc -l -p "$PORT" -q 1
done
