# Credential exposure note + rotation plan (no rotation executed)

## Finding

| Path | Category | In Git history? | Action this phase |
|---|---|---|---|
| `.env.example` (historical commits) | Publishable/anon-like key + **database password** category values that were not placeholders | **Yes** — tracked since early commits (`f10f90f`, updated `87fa46a`) | Replaced file contents with **placeholders** now. **History still contains old values.** |
| Root `.env` (local) | Same categories + pooler hosts | Gitignored (not for commit) | Left untouched for local tooling continuity; **removed from Flutter asset bundling** |
| `assets/config/client.env` | Public URL + publishable key only | Gitignored | Created locally for runtime; not for commit |

**Removing secrets from the current tree does not remove them from Git history.**

## Rotation / dependency plan (do not execute now)

Shared home Supabase credentials also serve **ERP**. Rotating without a dependency map risks portal/API outage.

1. Inventory every consumer of: anon/publishable JWT, service_role, DB password, JWT secret (Dokploy, portal, mobile ERP, backups, n8n if any).  
2. Schedule maintenance window.  
3. Rotate **publishable/anon** first (lowest blast radius for read clients); update AM `client.env` + ERP clients.  
4. Rotate DB password with coordinated update of pooler/Auth connection strings.  
5. Rotate service_role last; never ship to Flutter.  
6. Optionally purge Git history in a **separate**, explicitly authorized rewrite operation (not this phase).  
7. Re-issue Cloudflare Access / tunnel tokens only if exposed (process cmdline exposure noted in audit — value not recorded here).

**This phase:** no rotation, no Auth key changes, no remote secret edits.
