#!/usr/bin/env bash
# Runs every pgTAP file in supabase/tests/database. Each file wraps itself in
# a transaction and rolls back, so tests never change the local data.
# Fails if any assertion is "not ok", a plan is short, or SQL errors.
set -uo pipefail

failed=0
total=0
for file in /supabase/tests/database/*.sql; do
  [ -e "$file" ] || continue
  total=$((total + 1))
  out=$(psql -X -v ON_ERROR_STOP=1 -tA -f "$file" 2>&1)
  status=$?
  if [ $status -ne 0 ] || echo "$out" | grep -qE '^not ok|# Looks like you'; then
    echo "FAIL $(basename "$file")"
    echo "$out" | grep -E '^not ok|^#|ERROR|psql:' | head -40
    failed=$((failed + 1))
  else
    passed=$(echo "$out" | grep -c '^ok')
    echo "ok   $(basename "$file") ($passed assertions)"
  fi
done

echo "pgTAP: $((total - failed))/$total files passed"
[ $failed -eq 0 ]
