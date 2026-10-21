#!/usr/bin/env bash
# Legacy migration runner — Supabase Cloud project only.
#
# HOME SHARED DATABASE (api.ndmcore.com / supabase-db):
#   Do NOT use this script. Historical supabase/migrations/*.sql must not be
#   replayed onto the shared ERP+FX database. Use reviewed, non-default
#   packages under supabase/reconciliation/home/ after disposable PG17 validation.
#
# Required for any run:
#   FX_MIGRATION_TARGET=legacy_cloud
#
# Explicitly blocked:
#   FX_MIGRATION_TARGET=home_shared_db  (and any unset/other value)
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${FX_MIGRATION_TARGET:-}"
FORBIDDEN_DOMAIN="supabase.dincouture.pk"
EXPECTED_REF="ygidlcqhupmxvsdjmvnf"

echo "FX_MIGRATION_TARGET=${TARGET:-<unset>}"

case "${TARGET}" in
  legacy_cloud)
    ;;
  home_shared_db|home|ndmcore|api.ndmcore.com)
    echo "ABORT: Home shared-database migration replay is blocked."
    echo "       Use supabase/reconciliation/home/ (manual, allowlisted SQL)."
    echo "       This script will not run supabase db push against production."
    exit 2
    ;;
  *)
    echo "ABORT: Set FX_MIGRATION_TARGET=legacy_cloud to apply Cloud migrations,"
    echo "       or use supabase/reconciliation/home/ for home shared-DB work."
    echo "       Refusing to run (fail closed)."
    exit 2
    ;;
esac

if grep -v '^\s*#' .env 2>/dev/null | grep -q "$FORBIDDEN_DOMAIN"; then
  echo "ABORT: .env contains forbidden old VPS domain ($FORBIDDEN_DOMAIN)."
  exit 1
fi

# Prefer migration secrets file; fall back to root .env for legacy Cloud only.
ENV_FILE=".env"
if [[ -f supabase/.env.migrations ]]; then
  ENV_FILE="supabase/.env.migrations"
fi

REF=$(grep '^SUPABASE_URL=' "$ENV_FILE" | sed 's|.*://||; s|\..*||' | tr -d '\r')
MIGRATION_COUNT=$(ls -1 supabase/migrations/*.sql 2>/dev/null | wc -l | tr -d ' ')

echo "Pre-push confirmation (LEGACY CLOUD ONLY):"
echo "  env_file=$ENV_FILE"
echo "  project_ref=$REF (expected: $EXPECTED_REF)"
echo "  migration_count=$MIGRATION_COUNT"

if [[ "$REF" != "$EXPECTED_REF" ]]; then
  echo "ABORT: project ref mismatch — will not push."
  exit 1
fi

URL_HOST=$(grep '^SUPABASE_URL=' "$ENV_FILE" | sed 's|.*://||; s|/.*||' | tr -d '\r')
if [[ "$URL_HOST" != "${EXPECTED_REF}.supabase.co" ]]; then
  echo "ABORT: SUPABASE_URL must be https://${EXPECTED_REF}.supabase.co (got host: $URL_HOST)"
  exit 1
fi

PASS=$(grep '^SUPABASE_DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r\n')
POOLER=$(grep '^SUPABASE_DB_POOLER_HOST=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r\n' || true)

if [[ -z "$POOLER" ]]; then
  POOLER="aws-1-ap-southeast-1.pooler.supabase.com"
  echo "  pooler_host=$POOLER (default for this project region)"
else
  echo "  pooler_host=$POOLER"
fi

ENC_PASS=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$PASS" 2>/dev/null \
  || python -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$PASS")
DB_URL="postgresql://postgres.${REF}:${ENC_PASS}@${POOLER}:5432/postgres?sslmode=require"

echo "Applying migrations via session pooler (IPv4) to LEGACY CLOUD only..."
supabase db push --db-url "$DB_URL" --include-all --yes
