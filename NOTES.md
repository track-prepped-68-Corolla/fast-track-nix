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
ft.services.podmanRootless.enable = true;
ft.services.komodo.enable = true;
```

`ft.services.podmanRootless.uid` defaults to `2000`. Change it if that UID is
already taken on your system — the Podman socket path derives from it.

## Enabling the Home Manager module

In your user profile (`users/<username>/default.nix`):

```nix
ft.security.sops.enable = true;
ft.home.komodo.enable = true;
```

The module reuses the same three sops secret keys above. For a standalone Home
Manager deployment, store them in `users/<username>/var/secrets.yaml` (the
default `sops.defaultSopsFile` set by `ft.security.sops`). Container data is
written to `~/.local/share/komodo` by default; override with:

```nix
ft.home.komodo.dataDir = "/path/to/custom/dir";
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
