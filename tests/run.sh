#!/usr/bin/env bash
# Runs the pgTAP files under tests/behaviour with pg_prove and the isolation specs under
# tests/isolation with pg_isolation_regress, on each PostgreSQL major given (17 and 18 by default).
set -euo pipefail
shopt -s nullglob
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if (($# == 0)); then
  set -- 17 18
fi

container=
cleanup() {
  if [[ -n $container ]]; then
    docker rm -f "$container" > /dev/null
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

in_container() {
  timeout 600 docker exec -i -u postgres "$container" "$@"
}
psql() {
  in_container psql -X -v ON_ERROR_STOP=1 -q "$@"
}

for major in "$@"; do
  image="connetto-schema-test:$major"
  docker build -q --build-arg "PG_MAJOR=$major" -t "$image" "$root/tests" > /dev/null
  container=$(docker run -d --tmpfs /var/lib/postgresql -e POSTGRES_HOST_AUTH_METHOD=trust \
    -v "$root:/schema:ro" "$image")
  # The entrypoint restarts the server after initialisation, and only the final server listens on TCP.
  ready=
  for _ in $(seq 60); do
    if in_container pg_isready -q -h 127.0.0.1; then
      ready=1
      break
    fi
    sleep 1
  done
  if [[ -z $ready ]]; then
    echo "PostgreSQL $major did not start within 60 seconds" >&2
    docker logs "$container" >&2
    exit 1
  fi

  psql -d postgres -f /schema/cluster/roles.sql
  psql -d postgres -c 'CREATE DATABASE schema_template'
  psql -d schema_template -c 'CREATE SCHEMA test_tools' -c 'GRANT USAGE ON SCHEMA test_tools TO PUBLIC' \
    -c 'CREATE EXTENSION pgtap SCHEMA test_tools'
  slices=("$root"/sql/*/up.sql)
  for slice in "${slices[@]}"; do
    psql -d schema_template -f "/schema/${slice#"$root"/}"
  done
  echo "PostgreSQL $major applied ${#slices[@]} slices"

  psql -d postgres -c 'CREATE DATABASE schema_tests TEMPLATE schema_template'
  behaviour=()
  for file in "$root"/tests/behaviour/*.sql; do
    behaviour+=("/schema/${file#"$root"/}")
  done
  in_container pg_prove -d schema_tests --failures "${behaviour[@]}"

  specs=()
  for spec in "$root"/tests/isolation/specs/*.spec; do
    name=$(basename "$spec" .spec)
    specs+=("$name")
    psql -d postgres -c "CREATE DATABASE \"$name\" TEMPLATE schema_template"
  done
  isolation="/usr/lib/postgresql/$major/lib/pgxs/src/test/isolation"
  status=0
  in_container mkdir -p /tmp/isolation
  for name in "${specs[@]}"; do
    in_container "$isolation/pg_isolation_regress" --use-existing --dbname="$name" \
      --bindir="/usr/lib/postgresql/$major/bin" --inputdir=/schema/tests/isolation \
      --outputdir="/tmp/isolation/$name" "$name" || status=$?
    if ((status != 0)); then
      in_container cat "/tmp/isolation/$name/regression.diffs" >&2
      exit "$status"
    fi
  done

  cleanup
  container=
  echo "PASS PostgreSQL $major"
done
