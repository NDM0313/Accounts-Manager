# Remote access handoff — Mac + Windows office

**Date:** 2026-10-23  
**Repo:** NDM0313/Accounts-Manager  
**Server:** `dinserver` (`ndm313`)  
**Do not change:** Dokploy panel hostname `ssh.ndmcore.com`, ERP containers, database, or SQL migrations for access setup.

## What each hostname is for

| Hostname / alias | Purpose |
|------------------|---------|
| `192.168.86.235` / `dinserver-local` | Home LAN OpenSSH (fastest when on same Wi‑Fi) |
| `terminal.ndmcore.com` / `dinserver-cf` | Cloudflare Access → SSH (`ssh://127.0.0.1:22` on the Mini PC). **Use this for remote SSH.** |
| `ssh.ndmcore.com` | **Dokploy web panel only** — not an SSH endpoint for this handoff. Do not repoint it. |
| `100.127.166.65` / `dinserver-ts` | Tailscale OpenSSH (normal SSH over the tailnet) |

Verified server Tailscale IPv4 (2026-10-23): **`100.127.166.65`** (`dinserver-1`, online).

Access policy on `terminal.ndmcore.com`: allow **`ndmcodex@gmail.com`** only (existing Cloudflare Access app).

## Requirements

### Cloudflare (SSH / SFTP / SCP)

- Install [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) for your OS.
- Browser available once for `cloudflared access login`.
- Your **public** SSH key must already be in `~ndm313/.ssh/authorized_keys` on the server (ask an admin if a new machine needs authorization). **Never email or commit private keys.**

### Tailscale

- Install the official Tailscale client for your OS (Mac App Store / Windows MSI / iOS).
- Sign in to the **same tailnet** as `ndmcodex@` devices.
- Use normal OpenSSH to the Tailscale IP. Do **not** enable Tailscale `--ssh`, exit nodes, subnet routes, or broad ACL edits unless an admin explicitly plans that change.

## Portable SSH config (Windows + Mac)

Put the following in the user SSH config file:

- **Windows:** `%USERPROFILE%\.ssh\config`
- **macOS / Linux:** `~/.ssh/config`

Adjust only the `IdentityFile` path to your **local** private key file. Do not copy another machine’s private key.

```sshconfig
Host dinserver-local dinserver-mini
    HostName 192.168.86.235
    User ndm313
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3

Host dinserver-cf
    HostName terminal.ndmcore.com
    User ndm313
    ProxyCommand cloudflared access ssh --hostname %h
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3

Host dinserver-ts
    HostName 100.127.166.65
    User ndm313
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

### Windows notes

- Install OpenSSH Client (optional feature) or use Windows Terminal + OpenSSH.
- If `cloudflared` is not on `PATH`, set `ProxyCommand` to the full path of `cloudflared.exe` (for example under `C:\Program Files\cloudflared\`).
- On Windows, `~` in `IdentityFile` is fine for OpenSSH; you may also write `%USERPROFILE%\.ssh\id_ed25519`.
- Do **not** paste Mac paths such as `/Users/ndm/...` into Windows configs.

### First-time Cloudflare Access login

```bash
cloudflared access login https://terminal.ndmcore.com
```

Complete the browser prompt as **ndmcodex@gmail.com**. Tokens stay in the local cloudflared store; do not paste JWTs into chat or docs.

### Host keys

Prefer verifying the host key fingerprint against a known trusted path (home LAN) before accepting a new hostname:

- ED25519: `SHA256:cb+Rn43Xqs1hg07XVcUjZpWrmoPaXZGybshF73hil/s`

Do **not** use `StrictHostKeyChecking=no` or blank `UserKnownHostsFile` for convenience.

## Connection tests

### 1) Cloudflare SSH

```bash
ssh dinserver-cf "hostname; whoami"
```

Expect: `dinserver` / `ndm313`.

### 2) Cloudflare SFTP / SCP (labelled temp file)

```bash
echo "AM_OFFICE_PROBE labelled temp — delete me" > am_office_probe.txt
scp am_office_probe.txt dinserver-cf:~/am_office_probe.txt
ssh dinserver-cf "head -1 ~/am_office_probe.txt && rm -f ~/am_office_probe.txt"
rm am_office_probe.txt
```

### 3) Tailscale SSH

With Tailscale connected on the client:

```bash
tailscale status
ssh dinserver-ts "hostname; whoami"
```

Expect server row online at `100.127.166.65` and the same `dinserver` / `ndm313` response.

### 4) Outside-home smoke (phone hotspot)

1. Disconnect from home Wi‑Fi; join a phone hotspot (or any non-home network).
2. Cloudflare: `cloudflared access login https://terminal.ndmcore.com` if prompted, then `ssh dinserver-cf "hostname"`.
3. Tailscale: confirm the client is Connected, then `ssh dinserver-ts "hostname"`.
4. Rejoin home Wi‑Fi when finished.

Until both steps succeed off the home LAN, do **not** claim office-ready remote access.

## Public FX app (unchanged by this handoff)

- URL: https://fx.ndmcore.com  
- Approved redesign commit (deployed): `787de8b0b68c8e84a99aa9a730b709fe174a3bca`  
- Docs tip may be ahead of the deployed web SHA (handoff-only commits do not require redeploy).  
- Financial UI testing: **AM_DEMO only**

## Verification log (2026-10-23 Mac)

| Check | Result |
|-------|--------|
| Mac OS | macOS 26.7.1 (`x86_64`) |
| Tailscale install | Official standalone `Tailscale-1.104.2-macos.pkg` → `/Applications/Tailscale.app` |
| Mac CLI | `/Applications/Tailscale.app/Contents/MacOS/Tailscale` |
| Mac Tailscale login | Connected as `ndmcodex@` (`nadeems-macbook-pro`, `100.105.208.20`) |
| Same tailnet as server | Yes — `dinserver-1` at `100.127.166.65` active |
| `dinserver-cf` SSH | PASS → hostname `dinserver` |
| `dinserver-cf` SFTP/SCP | PASS (labelled probe file uploaded and deleted) |
| `dinserver-ts` SSH (on home LAN) | PASS → hostname `dinserver` / `ndm313` |
| Outside-home CF (phone hotspot) | Pending — requires leaving home LAN |
| Outside-home TS (phone hotspot) | Pending — requires leaving home LAN |
| SSH keys / aliases | Preserved (`~/.ssh/config` unchanged by Tailscale install) |

Host-key note: `terminal.ndmcore.com` and `100.127.166.65` were pinned to the same ED25519 fingerprint already trusted for `192.168.86.235` (`SHA256:cb+Rn43Xqs1hg07XVcUjZpWrmoPaXZGybshF73hil/s`). Do not use `StrictHostKeyChecking=no`.

## Security reminders

- Never commit `client_config.json` private env files, cloudflared tokens, or private keys.
- Never change the Dokploy route on `ssh.ndmcore.com` to “fix” SSH.
- Prefer least privilege: Access email allow-list and SSH public keys only.
