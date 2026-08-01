#!/usr/bin/env bash

while true; do
  /health/healthcheck.sh
  if [ $? -ne 0 ]; then
    MSG="Node unhealthy. Restarting services..."
    echo "[AUTO] $MSG"
    /health/alert_telegram.sh "$MSG"
    supervisorctl restart stellar-core
    supervisorctl restart horizon
  fi
  sleep 60
done
