#!/usr/bin/env bash
# Idempotent Cloud Agent install for mangasm-backend.
# Installs the same Postgres 16 + PostGIS + pgvector stack CI uses, then
# the Ganesh engine Node dependencies. Safe to run more than once.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

need_apt=0
for pkg in postgresql-16 postgresql-contrib postgresql-16-postgis-3 postgresql-16-pgvector; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    need_apt=1
    break
  fi
done

if [[ "$need_apt" -eq 1 ]]; then
  sudo apt-get update
  sudo apt-get install -y \
    postgresql-16 \
    postgresql-contrib \
    postgresql-16-postgis-3 \
    postgresql-16-pgvector
fi

# CI uses its own cluster on port 5433. Stop the Debian default cluster so
# only that dev server is running after start.
if command -v service >/dev/null 2>&1; then
  sudo service postgresql stop || true
fi

if [[ -f ganesh-engine/package-lock.json ]]; then
  npm ci --prefix ganesh-engine
fi
