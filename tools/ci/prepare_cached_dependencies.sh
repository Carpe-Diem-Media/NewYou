#!/usr/bin/env bash
set -euo pipefail

# A failed extraction can leave a partial tree. Never use it.
if [[ "${CACHE_RESTORE_OUTCOME:-success}" != success ]] ||
   { [[ "${CACHE_HIT:-false}" == true ]] && ! python3 tools/ci/cache_manifest.py check; }; then
  rm -rf deps _build/test
fi

prepare() {
  mix deps.get --check-locked && mix deps.compile --warnings-as-errors
}

# A cache may be present but unusable. A clean retry still fails the job if
# fetching or compilation fails independently of the cache.
if ! prepare; then
  echo "Dependency preparation failed; retrying once without cached files."
  rm -rf deps _build/test
  prepare
fi
