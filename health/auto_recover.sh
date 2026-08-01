#!/usr/bin/env bash

while true; do
  /health/healthcheck.sh
  if [ $? -ne 0 ]; then
    echo "[AUTO-RECOVER] Restarting services..."
    supervisorctl restart stellar-core
    supervisorctl restart horizon
  fi
  sleep 60
done
