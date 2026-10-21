# AM_DEMO — FX sample workspace

Isolated demo company on the **existing** home Supabase DB (`code = AM_DEMO`).

| Field | Value |
|-------|--------|
| Company code | `AM_DEMO` |
| Display name | FX DEMO — SAMPLE DATA |
| Branch code | `DEMO` |
| Seed version | `AM_DEMO_SEED_V1` |
| Company id | `a1111111-1111-4111-8111-111111111101` |
| Branch id | `a1111111-1111-4111-8111-111111111102` |

## Access

Public mobile web: **https://fx.ndmcore.com** (origin `http://127.0.0.1:3099` on dinserver).

1. Sign in as your real FX admin (`ndm313@yahoo.com`) — password unchanged.
2. Open **Settings → Switch company / demo**, or the company chip in the top bar.
3. Select **FX DEMO — SAMPLE DATA** (`AM_DEMO`).
4. Banner **DEMO — SAMPLE DATA, NOT REAL ACCOUNTS** stays visible.
5. Open **Demo walkthrough** for scenario links.

Real `NDMFX` membership is preserved; switching updates server-side active workspace only.

After each web deploy, `deploy/bust_web_cache.sh` stamps `flutter_bootstrap.js?v=<commit>` so Safari/Cloudflare do not keep a week-old `main.dart.js`.

## Seed

```sql
SELECT fx_seed_am_demo_v1('ndm313@yahoo.com');
```

Idempotent while seed batch is untouched. Refuses auto-reset if demo rows were edited.

Illustrative rates only: CNY 40/41, AED 75/77, USD 280/283 (not market quotes).
