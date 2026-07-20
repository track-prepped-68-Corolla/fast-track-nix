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

```
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
