#!/usr/bin/env bash
#
# Migration 008: refresh planner statistics with vacuumdb --analyze-in-stages.
#
# pg_upgrade does not carry pg_statistic across major-version upgrades — the
# PG 16 cluster starts with empty planner stats, so the optimizer makes poor
# join/scan decisions until ANALYZE has run. /common/postgresql/bin/upgrade-
# pg12-to-pg16.sh invokes pg_upgrade's analyze_new_cluster.sh with `|| true`,
# so any failure there leaves the cluster un-analyzed silently.
#
# This migration re-runs vacuumdb in --analyze-in-stages mode (three passes
# of progressively-deeper statistics) across all databases with parallelism.
# Safe on a freshly-upgraded cluster and on a steady-state one — re-running
# just refreshes the stats (cheap on a healthy cluster, essential on a fresh
# upgrade).
#
# Postgres must be running. migration_runner is invoked from /start after
# init_horizon and before stop_postgres, so PG is available at this point.

set -euo pipefail

readonly JOBS=4

if ! command -v pg_isready >/dev/null 2>&1; then
    echo "[008] pg_isready not found; skipping"
    exit 0
fi

if ! pg_isready -q; then
    echo "[008] postgres is not running; skipping (run vacuumdb manually later)"
    exit 0
fi

echo "[008] running vacuumdb --all --analyze-in-stages -j ${JOBS} ..."
sudo -u postgres vacuumdb --all --analyze-in-stages -j "${JOBS}"
echo "[008] vacuumdb completed"
