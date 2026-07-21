# Komodo + Rootless Podman — Setup Notes

## Required sops secret keys

Before deploying, populate the following keys in `secrets/secrets.yaml` (the
file pointed to by `ft.repoPath`) and re-encrypt with `sops secrets/secrets.yaml`.
Do **not** commit plaintext values.

### `komodo/postgres_env`

Decrypted to `/run/secrets/komodo/postgres_env`. Must be a valid env-file
(one `KEY=VALUE` per line, no shell quoting needed):

```
POSTGRES_USER=komodo
POSTGRES_PASSWORD=<strong-random-password>
POSTGRES_DB=komodo
```

### `komodo/core_env`

Decrypted to `/run/secrets/komodo/core_env`. Set `KOMODO_DATABASE_URL` to match
the credentials above:

```
KOMODO_DATABASE_URL=postgres://komodo:<POSTGRES_PASSWORD>@komodo-postgres:5432/komodo
KOMODO_PASSKEY=<strong-random-passkey>
KOMODO_FIRST_SERVER_ADMIN=admin
KOMODO_FIRST_SERVER_PASSWORD=<initial-admin-password>
```

### `komodo/periphery_env`

Decrypted to `/run/secrets/komodo/periphery_env`. `PERIPHERY_PASSKEY` must match
`KOMODO_PASSKEY` above:

```
PERIPHERY_PASSKEY=<same-value-as-KOMODO_PASSKEY>
```

## YAML structure in secrets.yaml

sops-nix maps `/`-delimited secret names to nested YAML keys:

```yaml
komodo:
    postgres_env: |
        POSTGRES_USER=komodo
        POSTGRES_PASSWORD=<value>
        POSTGRES_DB=komodo
    core_env: |
        KOMODO_DATABASE_URL=postgres://komodo:<value>@komodo-postgres:5432/komodo
        KOMODO_PASSKEY=<value>
        KOMODO_FIRST_SERVER_ADMIN=admin
        KOMODO_FIRST_SERVER_PASSWORD=<value>
    periphery_env: |
        PERIPHERY_PASSKEY=<value>
```

Encrypt with your machine's age recipient (SSH host key or hardware token).
Verify your `.sops.yaml` `creation_rules` covers `secrets/secrets.yaml`.

## Enabling the NixOS module

In your machine's NixOS configuration:

```nix
ft.podmanRootless.enable = true;
ft.komodo.enable = true;
```

`ft.podmanRootless.uid` defaults to `2000`. Change it if that UID is
already taken on your system — the Podman socket path derives from it.

## Enabling the Home Manager module

In your user profile (`users/<username>/default.nix`):

```nix
ft.sops.enable = true;
ft.komodo.enable = true;
```

The module reuses the same three sops secret keys above. For a standalone Home
Manager deployment, store them in `users/<username>/var/secrets.yaml` (the
default `sops.defaultSopsFile` set by `ft.sops`). Container data is
written to `~/.local/share/komodo` by default; override with:

```nix
ft.komodo.dataDir = "/path/to/custom/dir";
```

After `home-manager switch`, reload the user daemon and start the stack:

```sh
systemctl --user daemon-reload
systemctl --user start podman-komodo-postgres podman-komodo-core podman-komodo-periphery
```

`podman-create-komodo-net` is pulled in automatically as a `Requires=`
dependency of the container services and does not need to be started manually.

## Post-deploy checklist

1. Komodo Core UI is available at `http://<host>:9120`.
2. Log in with the `KOMODO_FIRST_SERVER_ADMIN` / `KOMODO_FIRST_SERVER_PASSWORD` credentials.
3. In the Komodo UI add Periphery as a server: address `http://<host>:8120`,
   passkey matching `KOMODO_PASSKEY`.
4. On subsequent rebuilds the first-server credentials are ignored; change the
   admin password inside Komodo after first login.

## Container dependency note

`komodo-core` waits for the postgres container to report healthy before starting
(via an `ExecStartPre` polling loop using `podman healthcheck run`). PostgreSQL
has a health-check configured (`pg_isready`) so Core will not attempt to connect
until the database is actually ready. The same `After=`/`Requires=` pattern
ensures Periphery starts only after Core.

---

# Injecting secrets into the Stacks Komodo deploys

The `*_env` keys above are Komodo's **own** bootstrap secrets. To feed secrets to
the **app Stacks/Deployments Komodo runs**, use Komodo's `[[KEY]]` interpolation:
a `[secrets]` TOML file is loaded into Core and/or Periphery, and any reference
like `SOME_ENV = [[MY_KEY]]` in a Stack/Deployment environment is substituted at
deploy time. The values are hidden from the Komodo UI and scrubbed from logs.

A `[secrets]` section **can only be supplied via a config file** (`--config-path`)
— it cannot be set through environment variables. All modules below therefore
mount a sops-decrypted TOML into the container and start it with
`<bin> --config-path`. Every toggle is **opt-in / off by default**.

Two tiers:

- **Periphery secrets** — host-local to the server the Periphery runs on; never
  traverse the network. Best default. Key: `komodo/periphery_secrets`.
- **Core secrets** — global, available to every resource Core manages. Use only
  when a secret must reach multiple servers. Key: `komodo/core_secrets`.

## Secret format (single TOML blob per tier)

Each key is a Komodo config file containing a `[secrets]` table:

```toml
[secrets]
CLOUDFLARE_TOKEN = "..."
APP_DB_PASSWORD  = "..."
```

Stored in `secrets.yaml` (or `komodo.yaml` for the microVM, below) under the
usual nested layout:

```yaml
komodo:
    periphery_secrets: |
        [secrets]
        CLOUDFLARE_TOKEN = "..."
        APP_DB_PASSWORD  = "..."
    core_secrets: |
        [secrets]
        SHARED_TOKEN = "..."
```

Then, in a Komodo Stack/Deployment environment:

```env
CF_DNS_API_TOKEN=[[CLOUDFLARE_TOKEN]]
```

## Rootless Podman (`ft.komodo`, NixOS and Home Manager)

Sops already runs on the same host, so enabling a tier declares the key, mounts
its decrypted path into the container, and adds the `--config-path` command:

```nix
ft.komodo.enable = true;
ft.komodo.secrets.periphery.enable = true;   # komodo/periphery_secrets
ft.komodo.secrets.core.enable = true;        # komodo/core_secrets (optional)
```

Populate the keys in the same sops file the base module uses
(`var/secrets/secrets.yaml` for NixOS; `users/<username>/var/secrets.yaml` for
standalone Home Manager).

## Rootful Docker microVM (`ft.dockervm` / `ft.ociStack`)

Here Periphery runs inside the guest, so sops-nix runs **inside the guest** too —
decrypting on the guest's own persistent SSH host key. Enable a tier with:

```nix
ft.dockervm.enable = true;
ft.dockervm.komodo.peripherySecrets.enable = true;   # komodo/periphery_secrets
ft.dockervm.komodo.coreSecrets.enable = true;        # komodo/core_secrets (optional)
```

Enabling either tier:

- adds a small persistent volume for the guest's ed25519 host key (mounted at
  `/var/lib/ssh`, so the NixOS-managed `sshd_config` is not shadowed) and enables
  sshd in the guest so the recipient can be read;
- shares `<repo>/var/secrets` **read-only** into the guest at `/var/secrets`;
- decrypts `komodo/{periphery,core}_secrets` from **`var/secrets/komodo.yaml`** to
  `/run/secrets/...` in the guest and loads them into Core/Periphery.

`komodo.yaml` is a **separate** sops file, encrypted **only** to the guest
recipient — so the guest key cannot decrypt your host's main `secrets.yaml`, even
though the whole (encrypted) `var/secrets` directory is visible in the guest.

### One-time guest recipient bootstrap

The guest's host key does not exist until the guest first boots, so bring the
feature up in two phases (this mirrors how real machines onboard to sops):

1. Set `peripherySecrets.enable = true` (and/or `coreSecrets`) and deploy. The
   guest boots and generates its persistent ed25519 host key. The Komodo Stack
   may error until step 4 — expected.
2. Read the guest's host key and convert it to an age recipient:

   ```sh
   ssh-keyscan <guest-ip> 2>/dev/null | ssh-to-age
   ```

3. Add that recipient to a `creation_rule` for `komodo.yaml` in
   `var/secrets/.sops.yaml`, then create/encrypt the file:

   ```sh
   sops var/secrets/komodo.yaml   # add the komodo/{periphery,core}_secrets keys
   ```

4. Redeploy (or restart the guest). sops-nix decrypts on the persistent host key
   and Komodo loads the `[secrets]` file; `[[KEY]]` references now resolve.

`ft.dockervm.komodo.{peripherySecrets,coreSecrets}` require `ft.repoPath` to be
set (an assertion enforces this) so `var/secrets` can be located and shared in.

---

# Komodo GitOps — auto-deploy every compose file in `containers/`

The secret injection above handles the values a stack needs; this section is
about getting Komodo to **deploy the stacks themselves** from your consumer
repo's `containers/` directory, GitOps-style, so a `git push` redeploys them.

Komodo deploys sets of resources via a **Resource Sync**: TOML that declares one
git-backed **Stack** per compose file. `ft komodo-sync` generates that TOML for
you from `containers/*.yaml`, so you never hand-write it.

## Generate the sync file

From your consumer repo (anywhere `ft` runs):

```sh
ft komodo-sync                       # server="Local", account=<repo owner>
ft komodo-sync my-server my-account  # override the Komodo server / git account
```

This writes `containers/komodo-sync.toml`:

- one `[[stack]]` per top-level `containers/*.yaml` (subdirectories like
  `containers/config/` are ignored), git-backed at your repo + branch, with
  `deploy = true`;
- a self-managing `[[resource_sync]]` pointing back at the file;
- each stack's `environment` populated from a sibling `containers/<name>.env`
  if present (see below).

`server` must match the Komodo Server resource name Periphery connects as — the
`serverName` option of `ft.ociStack` / `ft.dockervm` (default `Local`).
`account` is the **git account alias configured in Komodo** for private-repo
access (Settings → Git Accounts), not a GitHub username; it defaults to the repo
owner. Pass `account=""` for a public repo.

Re-run `ft komodo-sync` whenever you add or remove a compose file, and commit the
regenerated `containers/komodo-sync.toml`.

## Supplying compose variables

Compose files interpolate `${VAR}` at deploy time. For each `containers/<name>.yaml`,
add an optional `containers/<name>.env` whose lines become the stack's
`environment`:

```env
PUID=1000
TZ=Europe/London
WIREGUARD_PRIVATE_KEY=[[WIREGUARD_PRIVATE_KEY]]
```

Non-secret defaults sit inline; secret values use Komodo's `[[KEY]]`
interpolation, resolved from the Periphery `[secrets]` wired above (or Komodo
Variables/Secrets). Never commit real secret values here — only `[[KEY]]` refs.

## Applying the sync — no UI (`ft komodo-apply`)

Komodo Core is API-first (the UI is just a client), so the ResourceSync can be
created and executed over the API — nothing needs clicking. `ft komodo-apply`
does exactly that: it derives the repo/branch from `git remote`, **creates the
git-backed ResourceSync if it does not exist** (idempotent), then executes it so
Komodo pulls `containers/komodo-sync.toml` and applies the diff.

```sh
export KOMODO_URL=http://localhost:9120
export KOMODO_API_KEY=$(cat /run/secrets/komodo/api_key)
export KOMODO_API_SECRET=$(cat /run/secrets/komodo/api_secret)

ft komodo-sync            # regenerate the TOML, then commit + push it
ft komodo-apply           # create/update the sync + execute it
```

The only genuine one-time step is creating an **API key** in Komodo (Settings →
API Keys) and storing the key/secret in sops (e.g. `komodo/api_key`,
`komodo/api_secret`) — a normal credential, not a per-deploy click. Run
`ft komodo-apply` from your workstation, from CI on push, or from a deploy hook.

### Forcing deploys (`ft komodo-deploy`)

`deploy = true` on a synced Stack does not always redeploy a changed stack
(Komodo [#1120](https://github.com/moghtech/komodo/issues/1120)). When a push
updated a compose file but the container did not restart, force it over the API:

```sh
ft komodo-deploy media    # one stack
ft komodo-deploy          # every containers/*.yaml stack
```

## Alternative: auto-deploy on push via webhook

Instead of (or alongside) `ft komodo-apply`, enable the sync's **git webhook**
(copy the webhook URL from the ResourceSync into the repo's GitHub webhooks) so
pushes re-execute it automatically. Pair it with a batch-deploy **Procedure** on
the same webhook to work around #1120.

## Fully hands-off on deploy (`ft.dockervm.komodo.autoApply`)

For the microVM deployment, an opt-in host-side systemd oneshot runs
`ft komodo-apply` automatically after each rebuild, so every `ft switch`
reconciles Komodo with `containers/` — zero commands.

```nix
ft.dockervm.enable = true;
ft.cli.enable = true;                          # provides the `ft` runner
ft.sops.enable = true;                          # decrypts the API key
ft.dockervm.komodo.autoApply.enable = true;
```

It runs on the **host** (which has the repo checkout, sops, and network access to
the guest's Core), waits for Core to answer at `ft.dockervm.komodo.host`, then
drives the same `komodo-apply` recipe over the API. Credentials come from a
`komodo/api_env` sops secret in your host `secrets.yaml`:

```yaml
komodo:
    api_env: |
        KOMODO_API_KEY=K-xxxxxxxx
        KOMODO_API_SECRET=S-xxxxxxxx
```

Create the API key once in Komodo → Settings → API Keys. On the very first deploy
(before the key exists) the service just logs a failure and the next `ft switch`
picks it up — nothing blocks. The service is a `RemainAfterExit` oneshot, so it
re-runs on each rebuild; the sync itself is idempotent.

## Managed mode

The generated sync sets `managed = false`, so it never deletes resources it does
not define. Once you are confident the generated file is the single source of
truth for these stacks, flip it to `true` so removing a compose file also removes
its Stack from Komodo.
