#!/usr/bin/env bash
#
# Migration 007: refresh planner statistics with vacuumdb --analyze-in-stages.
#
# Defensive backstop for volumes carried over from community v1.1-p23.0.1,
# where the PG 12 → PG 16 cluster upgrade ran in-image. pg_upgrade does not
# carry pg_statistic across major-version upgrades, and the prior image's
# analyze_new_cluster.sh invocation was gated with `|| true`, so a transient
# failure there could leave the cluster un-analyzed silently.
#
# Re-runs vacuumdb in --analyze-in-stages mode (three passes of progressively-
# deeper statistics) across all databases with parallelism. Cheap on a healthy
# cluster, essential on a stale one — re-running just refreshes the stats.
#
# Postgres must be running. migration_runner is invoked from /start after
# init_horizon and before stop_postgres, so PG is available at this point.

set -euo pipefail

readonly JOBS=4

if ! command -v pg_isready >/dev/null 2>&1; then
    echo "[007] pg_isready not found; skipping"
    exit 0
fi

if ! pg_isready -q; then
    echo "[007] postgres is not running; skipping (run vacuumdb manually later)"
    exit 0
fi

echo "[007] running vacuumdb --all --analyze-in-stages -j ${JOBS} ..."
sudo -u postgres vacuumdb --all --analyze-in-stages -j "${JOBS}"
echo "[007] vacuumdb completed"
