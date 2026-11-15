#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if (($# == 0)); then
  set -- corsch-pg17 corsch-gate18
fi

database=
psql() {
  timeout 120 docker exec -i "$container" psql -X -U postgres -v ON_ERROR_STOP=1 "$@"
}
cleanup() {
  if [[ -n $database ]]; then
    psql -d postgres -q -c "DROP DATABASE \"$database\" WITH (FORCE);"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for container in "$@"; do
  role_count=$(psql -d postgres -At -c "SELECT count(*) FROM pg_roles WHERE rolname IN ('app', 'identity_writer', 'authz_owner', 'authz_writer')")
  if [[ $role_count == 0 ]]; then
    psql -d postgres -q < "$root/cluster/roles.sql"
  elif [[ $role_count != 4 ]]; then
    echo "$container has incomplete cluster role provisioning" >&2
    exit 1
  fi
  fresh_database="schema_tests_$(python3 -c 'import uuid; print(uuid.uuid4().hex)')"
  psql -d postgres -q -c "CREATE DATABASE \"$fresh_database\";"
  database=$fresh_database
  slices=("$root"/sql/*/up.sql)
  for slice in "${slices[@]}"; do
    psql -d "$database" -q < "$slice"
  done
  echo "$container applied ${#slices[@]} slices"
  psql -d "$database" -qAt < "$root/tests/behaviour.sql"
  python3 "$root/tests/concurrency.py" "$container" "$database"
  cleanup
  database=
  echo "PASS $container"
done
