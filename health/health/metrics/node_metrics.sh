#!/usr/bin/env bash

HORIZON_OK=$(curl -sf http://localhost:8000/ > /dev/null && echo 1 || echo 0)
CORE_OK=$(curl -sf http://localhost:11626/info > /dev/null && echo 1 || echo 0)

echo "# HELP pi_node_horizon_up Horizon service status"
echo "# TYPE pi_node_horizon_up gauge"
echo "pi_node_horizon_up $HORIZON_OK"

echo "# HELP pi_node_core_up Stellar-core service status"
echo "# TYPE pi_node_core_up gauge"
echo "pi_node_core_up $CORE_OK"
