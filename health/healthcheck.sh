#!/usr/bin/env bash
set -e

HORIZON_URL="http://localhost:8000/"
CORE_INFO_URL="http://localhost:11626/info"

# Check Horizon
if ! curl -sf "$HORIZON_URL" > /dev/null; then
  echo "[HEALTH] Horizon is DOWN"
  exit 1
fi

# Check stellar-core
if ! curl -sf "$CORE_INFO_URL" > /dev/null; then
  echo "[HEALTH] stellar-core is DOWN"
  exit 1
fi

echo "[HEALTH] Pi Node is HEALTHY"
exit 0
