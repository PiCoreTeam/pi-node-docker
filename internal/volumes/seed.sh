#!/usr/bin/env bash
# Produce a pristine testnet2 data set from pinetwork/pi-node-docker:community-v1.0-p22.1.
# Writes to internal/volumes/golden-testnet2-22.1/. One-time; re-run with --force to reseed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN="$HERE/golden-testnet2-22.1"
IMAGE="pinetwork/pi-node-docker:community-v1.0-p22.1"
NAME="pi-seed-testnet2-22.1"
TIMEOUT_SEC="${TIMEOUT_SEC:-1800}"   # 30 min default
STABLE_SEC="${STABLE_SEC:-60}"       # required consecutive RUNNING duration
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        *) echo "usage: $0 [--force]" >&2; exit 2 ;;
    esac
done

if [ -d "$GOLDEN" ] && [ -n "$(ls -A "$GOLDEN" 2>/dev/null || true)" ]; then
    if [ "$FORCE" -ne 1 ]; then
        echo "error: $GOLDEN exists and is non-empty; pass --force to reseed" >&2
        exit 1
    fi
    echo "--force given; wiping $GOLDEN"
    rm -rf "$GOLDEN"
fi
mkdir -p "$GOLDEN"

cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "seed: pulling $IMAGE"
docker pull --platform linux/amd64 "$IMAGE"

echo "seed: starting container $NAME"
docker run -d --rm --platform linux/amd64 --name "$NAME" \
    -v "$GOLDEN:/opt/stellar" \
    -e POSTGRES_PASSWORD=postgres \
    "$IMAGE" --testnet2 >/dev/null

started=$(date +%s)
stable_since=0

while true; do
    now=$(date +%s)
    if [ $((now - started)) -gt "$TIMEOUT_SEC" ]; then
        echo "seed: timed out after ${TIMEOUT_SEC}s waiting for readiness" >&2
        docker logs --tail 200 "$NAME" >&2 || true
        exit 1
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "^${NAME}$"; then
        echo "seed: container exited prematurely" >&2
        docker logs --tail 200 "$NAME" >&2 || true
        exit 1
    fi

    pgver=$(docker exec "$NAME" sh -c 'cat /opt/stellar/postgresql/data/PG_VERSION 2>/dev/null || true' | tr -d '[:space:]')
    buckets=$(docker exec "$NAME" sh -c 'ls /opt/stellar/core/buckets/*.xdr.gz 2>/dev/null | head -n 1 || true')
    status=$(docker exec "$NAME" supervisorctl status 2>/dev/null || true)
    core_run=$(echo "$status"   | awk '/^stellar-core/    {print $2}')
    horizon_run=$(echo "$status" | awk '/^horizon/        {print $2}')

    if [ "$pgver" = "12" ] && [ -n "$buckets" ] && [ "$core_run" = "RUNNING" ] && [ "$horizon_run" = "RUNNING" ]; then
        if [ "$stable_since" -eq 0 ]; then
            stable_since=$now
            echo "seed: both services RUNNING, waiting ${STABLE_SEC}s for stability..."
        elif [ $((now - stable_since)) -ge "$STABLE_SEC" ]; then
            break
        fi
    else
        stable_since=0
    fi

    sleep 5
done

echo "seed: readiness reached, stopping container gracefully"
docker stop "$NAME" >/dev/null
echo "seed: done. Golden data at $GOLDEN"
