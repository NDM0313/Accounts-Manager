#!/usr/bin/env bash
# Apply reviewed G→H→I to home supabase-db. Requires explicit confirm env.
# NEVER runs synthetic fixtures/scenarios.
set -euo pipefail
: "${FX_PROD_CONFIRM:?set FX_PROD_CONFIRM=APPLY_HOME_SHARED_DB_RECONCILE}"
[[ "$FX_PROD_CONFIRM" == "APPLY_HOME_SHARED_DB_RECONCILE" ]] || {
  echo "BLOCKED bad confirm"; exit 1; }

ROOT="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${FX_BACKUP_DIR:-/home/ndm313/fx_reconcile_backups}"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

PW="$(docker exec supabase-db printenv POSTGRES_PASSWORD)"
psql_prod() {
  docker exec -i -e PGPASSWORD="$PW" supabase-db \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

echo "[$STAMP] ERP baseline before"
psql_prod -c "SELECT COUNT(*) purchases FROM fx_currency_purchases; SELECT COUNT(*) settlements FROM fx_currency_purchase_settlements;"
psql_prod -c "SELECT to_regclass('public.fx_deals') deals, to_regclass('public.fx_remittances') remit;"

echo "[$STAMP] Backup custom-format dump"
docker exec -e PGPASSWORD="$PW" supabase-db \
  pg_dump -U postgres -d postgres -Fc -Z 6 \
  -f "/tmp/fx_pre_reconcile_${STAMP}.dump"
docker cp "supabase-db:/tmp/fx_pre_reconcile_${STAMP}.dump" \
  "$BACKUP_DIR/fx_pre_reconcile_${STAMP}.dump"
docker exec supabase-db rm -f "/tmp/fx_pre_reconcile_${STAMP}.dump"
chmod 600 "$BACKUP_DIR/fx_pre_reconcile_${STAMP}.dump"
ls -lh "$BACKUP_DIR/fx_pre_reconcile_${STAMP}.dump"
echo "$BACKUP_DIR/fx_pre_reconcile_${STAMP}.dump" > "$BACKUP_DIR/LATEST_BACKUP.txt"

echo "[$STAMP] Checksums of apply package"
(
  cd "$ROOT"
  shasum -a 256 G_bundled_am_modules.sql H_accounting_repairs.sql I_remaining_fixes.sql J_prod_bootstrap_company.sql F_foundation_shape_guard.sql
) | tee "$BACKUP_DIR/package_sha256_${STAMP}.txt"

echo "[$STAMP] Shape guard"
psql_prod < "$ROOT/F_foundation_shape_guard.sql"

echo "[$STAMP] Apply G (no allow_dev_seed; ERP purchase tables present)"
{
  echo "SELECT set_config('fx_reconciliation.confirm','APPLY_BUNDLED_AM_MODULES',false);"
  echo "SELECT set_config('lock_timeout','5s',false);"
  echo "SELECT set_config('statement_timeout','120s',false);"
  cat "$ROOT/G_bundled_am_modules.sql"
} | psql_prod | tee "$BACKUP_DIR/apply_G_${STAMP}.log"

echo "[$STAMP] Apply H"
{
  echo "SELECT set_config('fx_reconciliation.confirm','APPLY_ACCOUNTING_REPAIRS',false);"
  cat "$ROOT/H_accounting_repairs.sql"
} | psql_prod | tee "$BACKUP_DIR/apply_H_${STAMP}.log"

echo "[$STAMP] Apply I"
{
  echo "SELECT set_config('fx_reconciliation.confirm','APPLY_REMAINING_FIXES',false);"
  cat "$ROOT/I_remaining_fixes.sql"
} | psql_prod | tee "$BACKUP_DIR/apply_I_${STAMP}.log"

echo "[$STAMP] Company bootstrap"
{
  echo "SELECT set_config('fx_reconciliation.confirm','APPLY_PROD_COMPANY_BOOTSTRAP',false);"
  cat "$ROOT/J_prod_bootstrap_company.sql"
} | psql_prod | tee "$BACKUP_DIR/apply_J_${STAMP}.log"

echo "[$STAMP] Post verify (no fixtures)"
psql_prod < "$ROOT/E_post_apply_verification.sql" | tee "$BACKUP_DIR/verify_${STAMP}.log"

echo "[$STAMP] ERP baseline after"
psql_prod -c "SELECT COUNT(*) purchases FROM fx_currency_purchases; SELECT COUNT(*) settlements FROM fx_currency_purchase_settlements;"
psql_prod -c "SELECT id, code, name FROM fx_companies; SELECT id, code FROM fx_branches;"

echo "PASS_PRODUCTION_RECONCILE stamp=$STAMP backup=$BACKUP_DIR/fx_pre_reconcile_${STAMP}.dump"
