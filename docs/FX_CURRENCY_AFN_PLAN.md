# AFN Currency Seed Plan

## Requirement

Add **AFN (Afghan Afghani)** as default active currency alongside PKR, USD, AED, CNY, SAR.

## Migration `202606190002_fx_seed_afn_currency.sql`

1. `INSERT INTO fx_currencies ... ON CONFLICT DO NOTHING`
2. Insert cash COA account under Assets `1000` — code slot after SAR (`1151` or next free in 1151–1159 range)
3. PKR remains `is_base = TRUE`

## UI

Settings → Currencies already supports Add; AFN will appear after migration without manual entry.

## Safety

- Does not remove SAR or any existing currency.
- Does not delete posted records.
