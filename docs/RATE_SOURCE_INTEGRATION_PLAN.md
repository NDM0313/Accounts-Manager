# Rate Source Integration Plan (Future)

## Current state (honest)

- All rates are **manually entered** in Rate Board.
- DB column `fx_rates.rate_source` stores intent (`manual`, `import`, `market`, `api`) but **no live SBP/World Bank feed exists**.
- UI labels rates as **Manual Reference Rate** unless user selects another source at entry time.

## Phased roadmap

### Phase 1 — Manual (now)

- User enters buy/sell/mid on Rate Board.
- Source stored as `manual`; stale warning if >24h old.

### Phase 2 — CSV import

- Settings or Rate Board → Import CSV (currency, buy, sell, effective_at).
- Batch insert via `RateRepository.createRateVersion` with `source: import`.

### Phase 3 — Scheduled backend fetch

- Supabase Edge Function (cron) fetches external reference (e.g. open exchange API, SBP scrape if licensed).
- **Never call API from Flutter** if key required.
- Cache result in `fx_rates` with `rate_source = api` and `reference_rate_at`.
- User can override manually; override creates new version with `manual`.

### Phase 4 — Audit

- Rate history screen shows source + timestamp per version.
- Deal/transaction snapshots reference locked rate at booking.

## Fallback

If API fails → keep last manual rate, show stale badge, do not auto-update deal rates.

## Not in scope until Phase 3 approved

- Live SBP website integration
- World Bank API
- Auto-posting deal rates from external feed
