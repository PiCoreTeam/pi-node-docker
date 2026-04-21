#!/usr/bin/env bash
# Rebuild internal/volumes/work-testnet2/ as a fresh cp -a clone of golden-testnet2-22.1/.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN="$HERE/golden-testnet2-22.1"
WORK="$HERE/work-testnet2"

if [ ! -d "$GOLDEN" ] || [ -z "$(ls -A "$GOLDEN" 2>/dev/null || true)" ]; then
    echo "error: $GOLDEN is missing or empty; run seed.sh first" >&2
    exit 1
fi

# Refuse if any container is currently using $WORK as a bind source.
if [ -d "$WORK" ]; then
    if docker ps --format '{{.ID}} {{.Mounts}}' | grep -q "$WORK"; then
        echo "error: $WORK is currently bind-mounted by a running container; stop it first" >&2
        exit 1
    fi
    echo "clone: removing existing $WORK"
    rm -rf "$WORK"
fi

mkdir -p "$WORK"
echo "clone: copying golden → work (cp -a)"
cp -a "$GOLDEN/." "$WORK/"
echo "clone: done. Work data at $WORK"
