#!/usr/bin/env bash
# Run the Jac tests without exhausting the shared local Postgres.
#
# Every served test (JacTestClient) gets its own database, and jac's connection pool keeps up to
# 16 idle connections per database for 5 minutes after the client closes. With several workers,
# and other sessions on the same machine, that fills the embedded cluster's 256 connections and
# every test and `jac run` hangs. JAC_DB_POOL=0 closes connections on release instead; the worker
# count comes from [dev] test_jobs in jac.toml.
#
#   bash scripts/test.sh                       # every test in the repo
#   bash scripts/test.sh main.jac market/x.jac # just these files (list must start with main.jac)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

export JAC_DB_POOL=0
if [ "$#" -eq 0 ]; then
  exec jac test -d .
fi
exec jac test "$@"
