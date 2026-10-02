#!/usr/bin/env bash
# Local Clothsy backend in Docker. Usage:
#   scripts/backend.sh up       start everything and apply migrations + seed
#   scripts/backend.sh down     stop (data kept)
#   scripts/backend.sh reset    stop, wipe data, start fresh
#   scripts/backend.sh test     pgTAP database tests + Deno function tests
#   scripts/backend.sh logs [service]
#   scripts/backend.sh psql     SQL shell on the local database
#   scripts/backend.sh config   write apps/customer/config/dev.json
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [ ! -f supabase/.env ]; then
  cp supabase/.env.example supabase/.env
  echo "created supabase/.env from supabase/.env.example"
fi

compose() { docker compose --env-file supabase/.env "$@"; }

need_space() {
  # Pulling the images needs room; stop early instead of filling the disk.
  local free_gb
  free_gb=$(df -g / | awk 'NR==2 {print $4}')
  if [ "${free_gb:-0}" -lt "${CLOTHSY_MIN_FREE_GB:-10}" ]; then
    echo "Only ${free_gb} GB free; at least ${CLOTHSY_MIN_FREE_GB:-10} GB is needed to pull the" >&2
    echo "backend images. Free some space (or set CLOTHSY_MIN_FREE_GB) and retry." >&2
    exit 1
  fi
}

check_keys() {
  # The anon / service_role keys must be signed with JWT_SECRET, or every
  # request carrying them is refused.
  local secret name jwt want got
  secret=$(grep '^JWT_SECRET=' supabase/.env | cut -d= -f2-)
  for name in ANON_KEY SERVICE_ROLE_KEY; do
    jwt=$(grep "^$name=" supabase/.env | cut -d= -f2-)
    want=${jwt##*.}
    got=$(printf '%s' "${jwt%.*}" | openssl dgst -sha256 -hmac "$secret" -binary \
      | openssl base64 -A | tr '+/' '-_' | tr -d '=')
    if [ "$got" != "$want" ]; then
      echo "$name in supabase/.env is not signed with its JWT_SECRET." >&2
      echo "Copy both from supabase/.env.example, or sign new keys with your secret." >&2
      exit 1
    fi
  done
}

write_config() {
  local anon
  anon=$(grep '^ANON_KEY=' supabase/.env | cut -d= -f2-)
  mkdir -p apps/customer/config
  cat > apps/customer/config/dev.json <<JSON
{
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_ANON_KEY": "$anon",
  "RAZORPAY_KEY_ID": ""
}
JSON
  echo "wrote apps/customer/config/dev.json (git-ignored)"
}

case "${1:-}" in
  up)
    check_keys
    if ! docker image inspect supabase/postgres:17.6.1.136 >/dev/null 2>&1; then
      need_space
    fi
    compose up -d --wait db auth rest storage functions gateway
    compose run --rm migrate
    write_config
    echo "backend ready on http://127.0.0.1:54321"
    ;;
  down) compose down ;;
  reset)
    compose down -v
    "$0" up
    ;;
  test)
    compose up -d --wait db
    compose run --rm migrate
    compose --profile test run --rm db-test
    compose --profile test run --rm deno
    ;;
  logs) shift; compose logs -f "$@" ;;
  psql) compose exec db psql -U postgres ;;
  config) write_config ;;
  *)
    sed -n '2,10p' "$0"
    exit 1
    ;;
esac
