#!/usr/bin/env bash
# Applies supabase/migrations/*.sql in name order, once each, recording them
# in supabase_migrations.schema_migrations (the table the Supabase CLI uses,
# so a hosted project can take over the same history). Seeds an empty
# catalogue afterwards. Runs inside the `migrate` compose service.
set -euo pipefail

psql_q() { psql -v ON_ERROR_STOP=1 -X -q "$@"; }

psql_q <<'SQL'
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text primary key,
  statements text[],
  name text
);
SQL

applied=0
for file in /supabase/migrations/*.sql; do
  [ -e "$file" ] || continue
  base=$(basename "$file" .sql)
  version=${base%%_*}
  name=${base#*_}
  done_already=$(psql -X -tA -c \
    "select 1 from supabase_migrations.schema_migrations where version = '$version'")
  if [ "$done_already" = "1" ]; then
    continue
  fi
  echo "applying $base"
  # One transaction per migration: it applies completely or not at all.
  psql_q --single-transaction -f "$file"
  psql_q -c "insert into supabase_migrations.schema_migrations (version, name)
             values ('$version', '$name')"
  applied=$((applied + 1))
done
echo "migrations applied: $applied"

# Where pg_cron reaches the Edge Functions in this environment.
if [ -n "${FUNCTIONS_URL:-}" ] && [ -n "${SERVICE_ROLE_KEY:-}" ]; then
  psql_q -v url="$FUNCTIONS_URL" -v key="$SERVICE_ROLE_KEY" <<'SQL'
insert into private.settings (key, value) values
  ('functions_url', :'url'), ('service_role_key', :'key')
on conflict (key) do update set value = excluded.value;
SQL
fi

sellers=$(psql -X -tA -c "select count(*) from public.sellers")
if [ "$sellers" = "0" ]; then
  for file in /supabase/seed/*.sql; do
    [ -e "$file" ] || continue
    echo "seeding $(basename "$file")"
    psql_q --single-transaction -f "$file"
  done
else
  echo "catalogue already seeded"
fi
