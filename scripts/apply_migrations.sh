#!/usr/bin/env bash
# Apply fx_* migrations to the NEW Supabase Cloud project only.
# Does NOT connect to old ERP VPS/database.
set -euo pipefail

cd "$(dirname "$0")/.."

EXPECTED_REF="ygidlcqhupmxvsdjmvnf"
FORBIDDEN_DOMAIN="supabase.dincouture.pk"

if grep -v '^\s*#' .env 2>/dev/null | grep -q "$FORBIDDEN_DOMAIN"; then
  echo "ABORT: .env contains forbidden old VPS domain ($FORBIDDEN_DOMAIN)."
  exit 1
fi

REF=$(grep '^SUPABASE_URL=' .env | sed 's|.*://||; s|\..*||')
MIGRATION_COUNT=$(ls -1 supabase/migrations/*.sql 2>/dev/null | wc -l | tr -d ' ')

echo "Pre-push confirmation:"
echo "  project_ref=$REF (expected: $EXPECTED_REF)"
echo "  migration_count=$MIGRATION_COUNT"
echo "  migration_files:"
ls -1 supabase/migrations/*.sql

if [[ "$REF" != "$EXPECTED_REF" ]]; then
  echo "ABORT: project ref mismatch — will not push."
  exit 1
fi

URL_HOST=$(grep '^SUPABASE_URL=' .env | sed 's|.*://||; s|/.*||')
if [[ "$URL_HOST" != "${EXPECTED_REF}.supabase.co" ]]; then
  echo "ABORT: SUPABASE_URL must be https://${EXPECTED_REF}.supabase.co (got host: $URL_HOST)"
  exit 1
fi

PASS=$(grep '^SUPABASE_DB_PASSWORD=' .env | cut -d= -f2- | tr -d '\r\n')
POOLER=$(grep '^SUPABASE_DB_POOLER_HOST=' .env | cut -d= -f2- | tr -d '\r\n' || true)

if [[ -z "$POOLER" ]]; then
  POOLER="aws-1-ap-southeast-1.pooler.supabase.com"
  echo "  pooler_host=$POOLER (default for this project region)"
else
  echo "  pooler_host=$POOLER"
fi

ENC_PASS=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$PASS" 2>/dev/null \
  || python -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$PASS")
DB_URL="postgresql://postgres.${REF}:${ENC_PASS}@${POOLER}:5432/postgres?sslmode=require"

echo "Applying migrations via session pooler (IPv4)..."
supabase db push --db-url "$DB_URL" --yes
