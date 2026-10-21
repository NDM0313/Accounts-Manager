# Home Mini PC — Existing Supabase/DB Audit (Read-Only)

**Audit date (local):** 2026-10-21  
**Mode:** Read-only (SSH + catalog SELECT only)  
**Remote mutations:** **0** (no migrations, restarts, writes, DNS/tunnel changes, or restores)

> **Interpretation update (same day):** see  
> [`AUDIT_CLARIFICATION_2026-10-21.md`](./AUDIT_CLARIFICATION_2026-10-21.md)  
> for corrections on RLS vs grants, `fx_` ownership, Cloud unreachability ≠ deletion,  
> staging PG16 ≠ PG17 restore target, and the accounting gate.  
> Historical findings below are preserved as the evidence log.

---

## 0. Executive verdict

| Decision area | Result |
|---|---|
| Correct repo open? | **PASS** — `NDM0313/Accounts-Manager` |
| Mini PC reachable from this Cursor Mac? | **PASS** via LAN + Cloudflare Access SSH |
| FX tables exist on home DB? | **PASS** — partial `public.fx_*` set in production `supabase-db` / `postgres` |
| Compatible with current Accounts-Manager migrations? | **FAIL** — foundation name collision + missing ledger/remittance objects; ERP currency-purchase tables coexist |
| Former Supabase Cloud project usable? | **FAIL / unreachable** from this Mac (`ygidlcqhupmxvsdjmvnf.supabase.co` connection failed) |
| Prefer existing home stack? | **Conditionally viable** after reconciliation plan — **do not** blindly `db push` |

---

## 1. Repository identity

| Field | Value | Status |
|---|---|---|
| Workspace path | `/Users/ndm/Documents/Development/CursorDev/Accounts-Manager` | PASS |
| Git remote | `git@github.com:NDM0313/Accounts-Manager.git` | PASS |
| Branch | `ui/remittance-premium-polish` (tracks origin) | PASS |
| HEAD | `4b6bb759e858a63b76231c29443727f211b68a6a` | PASS |
| Dirty status | Clean working tree at audit start | PASS |
| App type | Flutter FX cash ledger / remittance (separate from ERP app) | PASS |
| Repo instructions | `CLAUDE.md` / `.cursor/rules/agent.mdc` are Jetro stubs (not ERP/FX ops guides) | PASS (noted) |

Local migration inventory: **45** SQL files under `supabase/migrations/` (prefix `20260610*` … `20260626*`), Accounts-Manager FX Cash Ledger lineage.

---

## 2. SSH / server identity (verified from this Cursor computer)

### 2.1 Working aliases (sanitized)

| Alias | HostName | Port | User | Method | Result |
|---|---|---|---|---|---|
| `dinserver-local` / `dinserver-mini` | `192.168.86.235` | 22 | `ndm313` | Direct LAN | **PASS** |
| `dinserver-cf` | `ssh.ndmcore.com` | 22 (via ProxyCommand) | `ndm313` | Cloudflare Access SSH (`cloudflared access ssh`) | **PASS** |
| `dinserver-ts` | `100.127.166.65` | 22 | `ndm313` | Tailscale | **FAIL** (connect timeout) |

Auth: existing private key `~/.ssh/id_ed25519`, `IdentitiesOnly yes`, BatchMode non-interactive **PASS**.  
Passwordless sudo (`sudo -n true`): **PASS** on both working aliases.  
Host key fingerprint (trusted `known_hosts`): `ED25519 SHA256:cb+Rn43Xqs1hg07XVcUjZpWrmoPaXZGybshF73hil/s` (same for `dinserver`, `192.168.86.235`, `ssh.ndmcore.com`).

### 2.2 Remote identity

| Field | Value | Status |
|---|---|---|
| Hostname | `dinserver` | PASS |
| OS | Ubuntu Linux `7.0.0-38-generic` x86_64 | PASS |
| CPU | 12 threads — Intel i5-11400T | PASS |
| RAM | 14 GiB total; ~8.2 GiB available; swap 4 GiB (~2.9 GiB used) | PASS |
| Root disk | 466G ext4; ~76G used / 366G avail (~18%) | PASS |
| Load | ~0.4–0.5 at audit time | PASS |

**Connection method note:** Cursor Mac is on home Wi‑Fi (user reports VPN). LAN IP `192.168.86.235` was reachable (ping + SSH). Cloudflare Access path also worked. Tailscale path did not.

**Transferability:** These aliases and keys exist only on this Mac. ChatGPT / other environments do **not** inherit them. See companion handoff doc.

---

## 3. Service / routing map

### 3.1 Relevant Docker projects

| Project | Role | Data volume / path | Status |
|---|---|---|---|
| `supabase` | Production Supabase stack (Postgres 17.6, Auth, REST, Storage, Studio, Envoy gateway, pooler) | DB bind: `/home/ndm313/m70q/supabase/docker/volumes/db/data`; Storage: `.../volumes/storage` | PASS |
| `erp-db` | Staging-oriented ERP DB + stage Auth/Studio/Web/Gateway | `erp-core-db` data: `/home/ndm313/m70q/stacks/erp-db/data` (Postgres 16) | PASS |
| `cloudflared` | Tunnel runner (`cloudflared-erp`, host network) | Token-based run (value not recorded) | PASS (presence) |
| `newposv3` / portal | `din-couture-portal` on `:3001` | App `.data` bind under NEWPOSV3 | PASS |
| Others | n8n, Chatwoot, Evolution, Portainer, Dokploy, AI studio DB | Separate volumes | Noted (out of FX scope) |

**Production Supabase Postgres:** container `supabase-db`, image `supabase/postgres:17.6.1.136`, database `postgres` (+ `_supabase`).  
**Staging ERP Postgres:** container `erp-core-db`, image `postgres:16-alpine`, database `erp_core`, role `erp_admin`, host port **5433**.  
**Do not infer separate DBs from subdomains alone** — verified below.

### 3.2 Public hostname → origin map

DNS for `*.ndmcore.com` resolves to Cloudflare anycast (same pair observed). Local Traefik Host probes returned 404; origins respond when hit directly. Tunnel ingress for `ndmcore.com` appears **Cloudflare-dashboard / token-managed** (not fully readable from local named config, which only showed `test-erp.dincouture.pk`).

| Public hostname | Probe | Likely origin (local) | Service | Database / volume | Status |
|---|---|---|---|---|---|
| `db.ndmcore.com` | HTTPS 307 → `/project/default` | `127.0.0.1:54323` (Studio) | Production Supabase Studio | `supabase-db` data volume | PASS (Studio, not API) |
| `db-stage.ndmcore.com` | HTTPS 307 → `/project/default` | `127.0.0.1:54324` | Staging Studio | Uses `erp-db` network / stage stack | PASS (Studio) |
| `api.ndmcore.com` | HTTPS 401 on `/`, `/auth/v1/health`, `/rest/v1/` | `127.0.0.1:8000` (Envoy) | Production Supabase API gateway | Same `supabase-db` | PASS (API shape; auth required) |
| `api-stage.ndmcore.com` | Mixed 200/502 | `127.0.0.1:3012` (stage gateway) | Staging API gateway | **`erp-core-db` / `erp_core`** (stage auth env) | PASS (separate DB) |
| `erp.ndmcore.com` | HTTPS 200 | `127.0.0.1:3001` | Production portal | Uses production Supabase | PASS |
| `erp-stage.ndmcore.com` | HTTPS 200 | `127.0.0.1:3011` | Staging web | Stage stack | PASS |

**Production vs staging DB separation**

| Check | Finding | Status |
|---|---|---|
| Same container? | No — `supabase-db` ≠ `erp-core-db` | PASS (separate) |
| Same volume? | No — different bind mounts | PASS (separate) |
| Staging refresh coupling | `sync_prod_data_to_erp_core.sh` dumps selected ERP tables from prod → restores into `erp_core` only; FX ledger tables **not** in sync table list | PASS for FX isolation from stage refresh; ERP tables still coupled |
| Shared auth? | Prod Auth → `supabase-db`/`postgres`; Stage Auth → `erp-core-db`/`erp_core` | PASS (separate) |

Mappings that remain **UNVERIFIED** without Cloudflare dashboard: exact tunnel UUID ↔ hostname bindings (behavior-matched only).

---

## 4. Database inventory — FX location

### 4.1 Where FX objects live

| Item | Value | Status |
|---|---|---|
| Host container | `supabase-db` | PASS |
| Database | `postgres` | PASS |
| Schema | `public` | PASS |
| Postgres version | 17.6 | PASS |
| Non-system schemas (sample) | `auth`, `public`, `storage`, `supabase_migrations`, backup COA schemas, etc. | PASS |
| `erp_core` FX tables | **None** | PASS |

### 4.2 Existing `fx_*` base tables (exact)

Present:

- `fx_accounts`, `fx_branches`, `fx_companies`, `fx_currencies`
- `fx_parties`, `fx_rates`, `fx_roles`, `fx_user_roles`, `fx_users_profiles`
- `fx_currency_purchases`, `fx_currency_purchase_settlements` (**ERP import-FX purchase module**)

**Missing vs Accounts-Manager repo (examples):**  
`fx_transactions`, `fx_journal_entries`, `fx_journal_lines`, `fx_deals`, `fx_deal_legs`, `fx_attachments`, `fx_remittances`, `fx_messages`, `fx_opening_balance_batches`, … → **absent**.

Also present (ERP, different product): many `import_fx_*` tables.

### 4.3 Row counts / classification

| Table | Exact count | Notes |
|---|---:|---|
| `fx_companies` … `fx_rates` / profiles / roles / accounts / parties | **0** | Empty foundation |
| `fx_currency_purchases` | **5** | All status `void`; currencies USD(4), CNY(1) |
| `fx_currency_purchase_settlements` | **3** | All `inactive` |

**FX_DATA_CLASSIFICATION: `MIXED`**

- Accounts-Manager ledger masters: **EMPTY**
- ERP currency-purchase leftovers: **POTENTIALLY REAL** (voided/inactive operational rows; no customer PII exported)
- Not DEMO seed for Accounts-Manager cash ledger
- No remittance/deal/journal FX ledger data present

### 4.4 Enums vs repo foundation

Server enums `fx_account_type`, `fx_party_type`, `fx_transaction_type`, `fx_transaction_status` labels **match** `202606100001_fx_foundation.sql`.  
Overlapping foundation columns for org/master tables are **largely name-compatible**, but that alone does **not** prove safe to re-apply CREATE migrations.

### 4.5 Functions / migrations / storage / RLS

| Check | Finding | Status |
|---|---|---|
| `fx_%` routines | Only `fx_set_updated_at` found in `public` | FAIL vs AM RPC surface |
| `supabase_migrations` | 75 applied; FX-named ones are ERP `fx_currency_purchase_*` / `import_fx_*` (Aug 2026), **not** AM `20260610*` files | FAIL (lineage mismatch) |
| Storage bucket `fx-attachments` | **Absent**; ERP buckets only | FAIL for AM attachments |
| RLS enabled on all `fx_*` | Yes | PASS (flag on) |
| RLS policies | Only on purchase/settlement tables (`company_id = get_user_company_id()`) | **FAIL** — foundation tables lack policies |
| Grants | `anon` + `authenticated` have broad DML on foundation `fx_*` | **FAIL** (shared-DB risk) |
| `auth.users` count | 17 (shared prod Auth) | PASS (count only) |

---

## 5. Shared-database integration assessment

Preferred approach: reuse existing home Supabase. Honest assessment:

| # | Topic | Finding | Status |
|---|---|---|---|
| 1 | Schema/object conflicts | Foundation `fx_*` names already taken; AM `CREATE TABLE`/`CREATE TYPE` would fail or no-op unsafely; ERP `fx_currency_purchases` is a different module sharing prefix | **BLOCKER** |
| 2 | Shared `auth.users` | Prod Auth is shared; AM expects `fx_users_profiles` keyed to `auth.users` — currently empty profiles | Risk — needs bootstrap isolation |
| 3 | Cross-app access | Prefix is **not** a security boundary. ERP users + weak RLS/grants on foundation tables → unintentional access risk | **BLOCKER** until RLS rewritten |
| 4 | Company/branch RLS | ERP purchase policies use `get_user_company_id()`; AM policies (repo) differ and are not applied | FAIL |
| 5 | SECURITY DEFINER | AM posting RPCs not present; ERP has other DEFINER RPCs in same DB (not fully audited) | UNVERIFIED (AM RPCs absent) |
| 6 | Privileged keys | Server holds Supabase service credentials in stack env (not printed); Flutter must never ship service_role | Risk noted |
| 7 | Storage separation | No `fx-attachments`; ERP buckets coexist | Needs dedicated bucket + policies |
| 8 | FX migrations altering globals | AM scripts currently target Cloud only; naive apply on home could collide types/tables and disturb ERP purchase module | **BLOCKER** |
| 9 | Staging refresh | Stage sync list omits `fx_*`; FX on **prod** still coupled to full `supabase.dump` backups | Partial PASS |
| 10 | Backup/restore coupling | Daily backup dumps **entire** `supabase-db` → FX + ERP restored together | Coupled — expected |

**Smallest safe remedy (describe only — not implemented):**

1. Freeze production writes for a planned window.  
2. Additive migration plan: **never** re-run foundation `CREATE` blindly; invent `IF NOT EXISTS` / alter-diff for missing ledger objects only.  
3. Harden RLS on all `fx_*` (deny-by-default; drop inappropriate `anon` grants).  
4. Decide fate of ERP `fx_currency_purchases*` (keep, rename, or isolate) before AM objects expand.  
5. Create `fx-attachments` bucket + policies.  
6. Retarget Flutter: allow `api.ndmcore.com` (remove hard `*.supabase.co` guard); never point at Studio `db.*`.  
7. Fix Auth `API_EXTERNAL_URL` / allow-list for public HTTPS callbacks (currently LAN-oriented).  
8. Validate with a staging clone / restore drill before prod apply.

**Do not insist on a separate stack without evidence** — evidence here is **name collision + RLS gaps + missing objects**, not “must have new VPS”. Separate DB/schema remains an option if reconciliation cost is too high.

---

## 6. Backups

| Item | Evidence | Status |
|---|---|---|
| Local inventory | `/home/ndm313/m70q/backups/` — pre-sync dumps (2026-10-09), pre-stockcount dump (2026-10-14), logs | PASS |
| Daily job | Cron `0 3 * * *` → `m70q/scripts/daily_backup.sh` | PASS |
| Contents | `pg_dump` of **entire** `supabase-db` + `evolution_postgres` + env/compose/n8n archive | Combined ERP (+ any FX) |
| Off-device | Upload to Bunny (`bunny-backups:daily/`); prior log also mentioned B2 path | PASS (configured) |
| Retention | Remote prune >7 days; local tar removed after upload | PASS (as coded) |
| Latest success | 2026-10-21 03:03 SUCCESS (~615M archive) | PASS |
| Restore testing | Not proven in this audit | **UNVERIFIED** |
| Storage object files | DB dump ≠ Storage disk files under `volumes/storage`; object-level backup coverage | **UNVERIFIED** |
| Accounts-Manager-only historical ledger | Not present on server; Git can rebuild schema/code only | N/A — **transaction records not recoverable from Git** |

---

## 7. Application configuration readiness (Accounts-Manager)

| Check | Finding | Status |
|---|---|---|
| Local `.env` | Present; points at Cloud project ref `ygidlcqhupmxvsdjmvnf` | FAIL for home target |
| Cloud reachability | `https://ygidlcqhupmxvsdjmvnf.supabase.co` unreachable from audit Mac | FAIL |
| `lib/core/config/env.dart` | **Hard-requires** host ending `.supabase.co`; blocks non-Cloud URLs | **BLOCKER** for `api.ndmcore.com` |
| `scripts/apply_migrations.sh` | Aborts unless Cloud ref `ygidlcqhupmxvsdjmvnf` | **BLOCKER** for home apply |
| API vs Studio | Intended client API = `api.ndmcore.com` (Envoy); `db.*` = Studio | PASS (understood) |
| Publishable key | Must match home anon/publishable JWT — not verified against home stack | UNVERIFIED |
| `.env` in Flutter assets | `pubspec.yaml` bundles `.env` as asset | Risk — ensure only publishable key; **no DB password / service_role** |
| `.env.example` | Contains **non-placeholder** credential-like values (password + publishable key present) | **FAIL** (exposure category; values not printed) |
| Auth bootstrap | Repo docs assume Cloud SQL editor + `fx_users_profiles`; home profiles empty | Missing prerequisite |
| CORS / callbacks | Prod GoTrue `API_EXTERNAL_URL` / site URL still LAN `http://192.168.86.235:8000`; allow-list includes dincouture hosts | FAIL / needs update for public app |
| Missing DB functions | AM posting/remittance RPCs absent on home DB | FAIL |

**Credential categories discovered (paths only, no values):**

- Local: `.env`, `.env.example` (publishable key + DB password category)  
- Server: `m70q/supabase/docker/.env`, portal/evolution env files (copied into backup archives)  
- Tunnel: cloudflared token on process command line (not recorded in this report)

---

## 8. Accounting work recorded for next phase (not fixed)

Re-verify against current code/docs; **no fixes in this audit**:

1. Purchased currency held by an agent needs **per-agent currency balances**.  
2. Payout from existing balance ≠ creating agent payable.  
3. Buy cost, sale value, FX profit, and commission need **distinct** treatment.  
4. Partial customer payments may repeatedly recognize commission.  
5. Partial agent settlements may incorrectly mark remittance complete.  
6. Partial delivery may post full deal totals.  
7. A receipt may complete unrelated pending agent-source legs (`202606210005_fx_currency_receipt_completes_agent_source.sql` still in tree).  
8. Refund amount/status/duplicate controls need review.

Business currencies: **PKR base**; **USD, AED, RMB/CNY**. Term **“TTP”** left undefined (UNVERIFIED).

---

## 9. Check matrix (compact)

| Check | Result |
|---|---|
| Repo identity | PASS |
| SSH LAN | PASS |
| SSH Cloudflare Access | PASS |
| SSH Tailscale | FAIL |
| Server hostname `dinserver` | PASS |
| Prod Supabase stack running | PASS |
| Stage DB separate volume | PASS |
| FX tables exist | PASS (partial) |
| FX = AM cash ledger complete | FAIL |
| Migration lineage match | FAIL |
| Cloud project usable | FAIL |
| Flutter home URL ready | FAIL |
| Backups exist (combined) | PASS |
| Restore proven | UNVERIFIED |
| Shared-DB safe to migrate now | BLOCKED |
| Remote mutations this audit | **0** |

---

## 10. Recommended target and phased plan

**Recommended target:** Continue on **existing home production Supabase** (`supabase-db` / `api.ndmcore.com`) **after** a reconciliation phase — aligned with user decision, with blockers cleared first.

**Do not:** create a new Supabase stack/VPS/container; do not `db push` AM migrations as-is.

### Phase 0 — Prerequisites (docs/config only)
- Decide publishable key source for home API.  
- Plan Auth URL/allow-list changes for HTTPS clients.  
- Replace Flutter Cloud hard-guards with explicit allow-list (`api.ndmcore.com`).  
- Sanitize `.env.example` placeholders.

### Phase 1 — Schema reconciliation design (still no prod apply)
- Diff every AM migration against live catalog.  
- Produce additive-only SQL for missing objects.  
- Explicit conflict policy for ERP `fx_currency_purchases*`.  
- RLS redesign for all `fx_*`.

### Phase 2 — Safe validation
- Restore latest `supabase.dump` to an isolated clone (or use stage carefully — note stage is PG16 `erp_core`, not a full Supabase clone).  
- Apply additive migrations on clone; run AM verify scripts.

### Phase 3 — Controlled production apply
- Backup + freeze window.  
- Apply additive migrations only.  
- Bootstrap FX profiles/roles.  
- Point app at `https://api.ndmcore.com`.

### Phase 4 — Accounting correctness pass
- Address the eight remittance/deal concerns listed in §8.

---

## 11. Confirmation

This audit performed **read-only** inspection only.  
**REMOTE_MUTATIONS: 0**

Companion handoff: `docs/infrastructure/CHATGPT_SSH_DB_HANDOFF.md`
