#!/usr/bin/env bash
# Boot the local Postgres cluster the way .github/workflows/db-ci.yml does,
# then apply the auth shim and every migration in the checked-out tree.
# Idempotent: skips init/start when the cluster is already up, and migrations
# are written to re-apply cleanly.
set -euo pipefail

PGBIN=/usr/lib/postgresql/16/bin
PGDATA=/var/lib/mangasm-pg
PGPORT=5433
PGSOCKET=/tmp

if [[ ! -x "$PGBIN/pg_ctl" ]]; then
  echo "PostgreSQL 16 is not installed. Run .cursor/install.sh first." >&2
  exit 1
fi

sudo useradd --create-home --shell /usr/sbin/nologin pgci 2>/dev/null || true
sudo mkdir -p "$PGDATA"
sudo chown pgci:pgci "$PGDATA"

# Data dir is mode 700 and owned by pgci, so the ubuntu user cannot see
# PG_VERSION. `sudo test` is required; a plain [[ -f ]] is a false negative
# and would try to initdb over a live cluster.
if ! sudo test -f "$PGDATA/PG_VERSION"; then
  sudo -u pgci "$PGBIN/initdb" -D "$PGDATA" -U pgci -A trust
fi

if ! sudo -u pgci "$PGBIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
  sudo rm -f "${PGSOCKET}/.s.PGSQL.${PGPORT}" "${PGSOCKET}/.s.PGSQL.${PGPORT}.lock" || true
  sudo -u pgci "$PGBIN/pg_ctl" -D "$PGDATA" \
    -o "-p ${PGPORT} -k ${PGSOCKET} -c listen_addresses=127.0.0.1" \
    -l "$PGDATA/pg.log" \
    -w start
fi

sudo -u pgci "$PGBIN/pg_isready" -h "$PGSOCKET" -p "$PGPORT"

if [[ ! -f supabase/tests/shim.sql ]]; then
  echo "supabase/tests/shim.sql not found; cluster is up but migrations were skipped." >&2
  exit 0
fi

psql -h "$PGSOCKET" -p "$PGPORT" -U pgci -d postgres -v ON_ERROR_STOP=1 \
  -f supabase/tests/shim.sql

shopt -s nullglob
migrations=(supabase/migrations/*.sql)
shopt -u nullglob
if [[ ${#migrations[@]} -eq 0 ]]; then
  echo "No migrations under supabase/migrations." >&2
  exit 1
fi

for f in "${migrations[@]}"; do
  echo "=== applying $f ==="
  psql -h "$PGSOCKET" -p "$PGPORT" -U pgci -d postgres -v ON_ERROR_STOP=1 -f "$f"
done

echo "mangasm postgres ready on port ${PGPORT} (user pgci, socket ${PGSOCKET})"
