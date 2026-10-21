# ChatGPT SSH + Database Handoff (Sanitized)

**Purpose:** Pasteable context for another assistant.  
**Important:** Local SSH aliases/keys on the Cursor Mac are **not** automatically usable from ChatGPT or any external environment. Do **not** upload credentials or open public SSH merely to enable remote chat access.

**Audit date:** 2026-10-21  
**Remote mutations during audit:** **0**

Full technical audit: `docs/infrastructure/HOME_MINIPC_EXISTING_DB_AUDIT.md`

---

## A. Access verified from Cursor computer

| Field | Value |
|---|---|
| Working SSH aliases | `dinserver-local` (same as `dinserver-mini`), `dinserver-cf` |
| Failed alias (this session) | `dinserver-ts` (Tailscale `100.127.166.65` — timeout) |
| Mini PC hostname | `dinserver` |
| Reachable LAN IP | `192.168.86.235` |
| SSH port | `22` |
| SSH user | `ndm313` |
| Connection methods that worked | (1) Direct LAN to `192.168.86.235`; (2) Cloudflare Access SSH via `ssh.ndmcore.com` + `cloudflared access ssh` |
| Requires home LAN or VPN? | LAN path needs home network reachability to `192.168.86.235`. CF Access path works when Cloudflare Access + local `cloudflared` binary/auth are available. Tailscale path **unverified/failed** this session. |
| Authentication | Existing ed25519 key (`IdentitiesOnly`), non-interactive BatchMode **works** |
| Passwordless sudo | **Yes** (`sudo -n` succeeded) on working sessions |
| Host key fingerprint | `ED25519 SHA256:cb+Rn43Xqs1hg07XVcUjZpWrmoPaXZGybshF73hil/s` |
| Sanitized connect commands | `ssh dinserver-local` · `ssh dinserver-cf` |

### External access (ChatGPT / other machines)

| Field | Value |
|---|---|
| SSH_FROM_CURSOR | **VERIFIED** |
| EXTERNAL_SSH_ACCESS | **UNVERIFIED** (not transferable; no credentials provided here) |
| What remains unverified externally | Cloudflare Access policy membership, key presence, Tailscale ACL, router/VPN path from non-home networks |

**Do not claim** ChatGPT can SSH to this host using the aliases above.

---

## B. Repository

| Field | Value |
|---|---|
| Expected / verified remote | `NDM0313/Accounts-Manager` |
| Path on Cursor Mac | `/Users/ndm/Documents/Development/CursorDev/Accounts-Manager` |
| Branch | `ui/remittance-premium-polish` |
| HEAD | `4b6bb759e858a63b76231c29443727f211b68a6a` |
| Dirty at audit | Clean |
| Nature | Flutter money-exchange / FX cash ledger — **separate** from ERP app |

Former Cloud project ref in repo docs/env: `ygidlcqhupmxvsdjmvnf` — **unreachable** from audit Mac (treat as removed/unavailable).

---

## C. Routing map (behavior-verified)

| Public hostname | Role | Likely local origin | DB |
|---|---|---|---|
| `db.ndmcore.com` | Studio/admin | `:54323` supabase-studio | Production `supabase-db` / `postgres` |
| `db-stage.ndmcore.com` | Studio/admin | `:54324` erp-stage-studio | Staging stack |
| `api.ndmcore.com` | Supabase API gateway | `:8000` supabase-envoy | **Same production DB** |
| `api-stage.ndmcore.com` | Stage API gateway | `:3012` | **`erp-core-db` / `erp_core`** (separate) |
| `erp.ndmcore.com` | Production portal | `:3001` | Production Supabase |
| `erp-stage.ndmcore.com` | Staging web | `:3011` | Stage stack |

Exact Cloudflare tunnel hostname bindings: **UNVERIFIED** (dashboard/token-managed; local named config incomplete).

---

## D. Database facts ChatGPT needs

| Field | Value |
|---|---|
| ERP production database | `supabase-db` container → DB `postgres` (Postgres **17.6**); data dir `/home/ndm313/m70q/supabase/docker/volumes/db/data` |
| ERP staging database | `erp-core-db` → DB `erp_core` (Postgres **16**); host port 5433; separate volume |
| FX tables location | Production **`postgres.public`** on `supabase-db` |
| FX tables present | Foundation-ish: companies/branches/currencies/rates/accounts/parties/roles/profiles; plus ERP `fx_currency_purchases` + settlements |
| FX tables missing for AM app | transactions/journal/deals/remittances/messages/attachments/opening-balance batches, etc. |
| FX_DATA_CLASSIFICATION | **MIXED** (empty AM masters + 5 void / 3 inactive ERP purchase rows) |
| Migration compatibility | **FAIL** — AM `20260610*` lineage not applied; name/type collisions; ERP purchase module shares `fx_` prefix |
| VERIFIED_SUPABASE_API_URL | `https://api.ndmcore.com` (API gateway behavior; client key compatibility UNVERIFIED) |
| STUDIO_URL | `https://db.ndmcore.com` (Studio redirect observed) |
| Shared-DB blockers | Name collision; incomplete RLS + broad anon grants; missing AM RPCs/bucket; Flutter hard-coded `*.supabase.co`; Auth external URL still LAN-oriented |
| Backups | Daily combined `supabase-db` dump → Bunny `daily/`; restore testing **UNVERIFIED** |
| Recommended next step | Design **additive** reconciliation + RLS hardening on existing home DB; do **not** create new stack; do **not** blind-push AM migrations |

---

## E. Copy block

```
REPO: NDM0313/Accounts-Manager
BRANCH: ui/remittance-premium-polish
HEAD: 4b6bb759e858a63b76231c29443727f211b68a6a
SSH_ALIAS: dinserver-local (LAN) | dinserver-cf (Cloudflare Access)
SSH_HOST: 192.168.86.235 (LAN) | ssh.ndmcore.com (CF)
SSH_PORT: 22
SSH_USER: ndm313
CONNECTION_METHOD: LAN direct OR Cloudflare Access SSH (cloudflared)
REQUIRES_HOME_LAN_OR_VPN: LAN path yes; CF Access when enrolled; Tailscale FAILED this session
SSH_FROM_CURSOR: VERIFIED
EXTERNAL_SSH_ACCESS: UNVERIFIED (not transferable)
SERVER_HOSTNAME: dinserver
ERP_PRODUCTION_DATABASE: supabase-db / postgres (PG 17.6)
ERP_STAGING_DATABASE: erp-core-db / erp_core (PG 16, port 5433)
FX_TABLES_DATABASE_AND_SCHEMA: supabase-db / postgres / public
FX_DATA_CLASSIFICATION: MIXED
VERIFIED_SUPABASE_API_URL: https://api.ndmcore.com
STUDIO_URL: https://db.ndmcore.com
MIGRATION_COMPATIBILITY: FAIL
BACKUP_STATUS: daily combined supabase dump to Bunny; restore UNVERIFIED
SHARED_DATABASE_BLOCKERS: fx_ name collision + weak RLS/grants + missing AM objects/RPCs/bucket + Flutter Cloud URL guards
RECOMMENDED_NEXT_STEP: additive reconciliation plan on existing home Supabase; no new stack; no blind migration push
REMOTE_MUTATIONS: 0
REPORT_PATHS: docs/infrastructure/HOME_MINIPC_EXISTING_DB_AUDIT.md ; docs/infrastructure/CHATGPT_SSH_DB_HANDOFF.md
```
