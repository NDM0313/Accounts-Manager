#!/usr/bin/env bash
# Disposable PG17 validation via docker exec. Never points at production.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
CONTAINER="${FX_VALIDATE_CONTAINER:-am-fx-validate-pg17}"
USER="${PGUSER:-postgres}"
PASS="${PGPASSWORD:-local_only_validate_not_prod}"
DB="${PGDATABASE:-postgres}"
EVIDENCE_DIR="${ROOT}/../../../tmp/fx_validate_evidence"
mkdir -p "$EVIDENCE_DIR"

psql_i() {
  docker exec -i -e PGPASSWORD="$PASS" "$CONTAINER" \
    psql -U "$USER" -d "$DB" -v ON_ERROR_STOP=1 "$@"
}

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

apply_file() {
  local label="$1"
  local file="$2"
  local prelude="${3:-}"
  log "APPLY $label <- $(basename "$file")"
  {
    # Session-level GUC (is_local=false) — psql auto-commits each statement
    [[ -n "$prelude" ]] && printf '%s\n' "$prelude"
    cat "$file"
  } | psql_i 2>&1 | tee "$EVIDENCE_DIR/${label}.log"
}

MODE="${1:-clean}"
log "mode=$MODE container=$CONTAINER"

# Always start from empty disposable schemas; reconcile differs by pre-seeding foundation shapes.
log "DROP/CREATE public+storage schemas (disposable only)"
psql_i -c "DROP SCHEMA IF EXISTS public CASCADE; DROP SCHEMA IF EXISTS storage CASCADE; DROP SCHEMA IF EXISTS auth CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT USAGE ON SCHEMA public TO public;"

apply_file "00_bootstrap" "$ROOT/bootstrap_disposable_pg.sql"
apply_file "00_erp_stubs" "$ROOT/erp_shape_stubs.sql"

if [[ "$MODE" == "reconcile" ]]; then
  log "APPLY 00b_foundation_partial (existing-home shape subset)"
  # Pre-create foundation tables+trigger that home already has, so G must be IF NOT EXISTS / DROP TRIGGER safe
  psql_i <<'SQL' 2>&1 | tee "$EVIDENCE_DIR/00b_foundation_partial.log"
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE OR REPLACE FUNCTION fx_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;
-- Match home foundation shape (UUID id PK on currencies — not code-only)
CREATE TABLE IF NOT EXISTS fx_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  base_currency_code TEXT NOT NULL DEFAULT 'PKR',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS trg_fx_companies_updated_at ON fx_companies;
CREATE TRIGGER trg_fx_companies_updated_at
  BEFORE UPDATE ON fx_companies FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();
CREATE TABLE IF NOT EXISTS fx_currencies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  symbol TEXT NOT NULL DEFAULT '',
  decimal_places INT NOT NULL DEFAULT 2,
  is_base BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO fx_currencies (code, name, symbol, is_base) VALUES
  ('PKR','Pakistani Rupee','Rs',true),
  ('USD','US Dollar','$',false)
ON CONFLICT (code) DO NOTHING;
SQL
  # Fail-fast shape guard (unexpected defs must not be silently accepted)
  apply_file "00c_shape_guard" "$ROOT/F_foundation_shape_guard.sql"
fi

apply_file "01_G" "$ROOT/G_bundled_am_modules.sql" \
  "SELECT set_config('fx_reconciliation.confirm','APPLY_BUNDLED_AM_MODULES',false); SELECT set_config('fx_reconciliation.allow_missing_erp_purchase','1',false); SELECT set_config('fx_reconciliation.allow_dev_seed','1',false);"
apply_file "02_H" "$ROOT/H_accounting_repairs.sql" \
  "SELECT set_config('fx_reconciliation.confirm','APPLY_ACCOUNTING_REPAIRS',false);"
apply_file "03_I" "$ROOT/I_remaining_fixes.sql" \
  "SELECT set_config('fx_reconciliation.confirm','APPLY_REMAINING_FIXES',false);"
apply_file "04_fixtures" "$ROOT/tests/synthetic_fixtures.sql"
apply_file "05_s01" "$ROOT/tests/scenario_01_agent_balances.sql"
apply_file "05_s02" "$ROOT/tests/scenario_02_partial_commission.sql"
apply_file "05_s03" "$ROOT/tests/scenario_03_partial_settlement_refund.sql"
apply_file "05_s04" "$ROOT/tests/scenario_04_deal_receipt_leg.sql"
apply_file "05_s05" "$ROOT/tests/scenario_05_authz_and_erp_untouched.sql"
apply_file "05_s06" "$ROOT/tests/scenario_06_partial_delivery_a6.sql"
apply_file "06_verify" "$ROOT/E_post_apply_verification.sql"

log "DONE mode=$MODE"
echo "PASS_DISPOSABLE_$MODE"
