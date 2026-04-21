#!/usr/bin/env bash
# Run a pi-node-docker image against internal/volumes/work-testnet2/ bind-mounted at /opt/stellar.
# Usage: run.sh <image-tag>   e.g. run.sh pinetwork/pi-node-docker:community-v1.1-p23.0.1
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$HERE/work-testnet2"

if [ $# -ne 1 ]; then
    echo "usage: $0 <image-tag>" >&2
    exit 2
fi
IMAGE="$1"

if [ ! -d "$WORK" ] || [ -z "$(ls -A "$WORK" 2>/dev/null || true)" ]; then
    echo "error: $WORK is missing or empty; run clone.sh first" >&2
    exit 1
fi

exec docker run --rm -it --platform linux/amd64 \
    --name pi-work-testnet2 \
    -v "$WORK:/opt/stellar" \
    -e POSTGRES_PASSWORD=postgres \
    -p 8000:8000 \
    -p 8003:8003 \
    -p 11626:11626 \
    -p 31402:31402 \
    "$IMAGE" --testnet2
