---
type: Guide
title: Container Image
description: How the stack's services run in one container image, what it contains and pins, how kgbo-services supervises and health-checks them, why the bundle variables are image ENV, and how stored paths are handled inside the container.
tags: [container, docker, deployment, bundle, operations]
verified:
  - by: owcli/v0.4.0
    at: "2026-10-05T10:41:17.026Z"
sources:
  - id: openwiki-source-715dace563ef484b6e8bd1e2
    resource: repo://.dockerignore
  - id: openwiki-source-cea96ae8f357252ff94e036c
    resource: repo://deploy/container/Dockerfile
  - id: openwiki-source-fe4f45cdc237709501707dc6
    resource: repo://deploy/container/kgbo-repos
  - id: openwiki-source-aba0804f4b63f288f9daec3a
    resource: repo://deploy/container/kgbo-services
  - id: openwiki-source-012f2c78e3b1446dfc35803f
    resource: repo://Makefile
generated: { by: "owcli/v0.4.0", at: "2026-10-05T10:41:44.012Z" }
---

# Container Image

`deploy/container/` builds one image that runs the stack's services: kata's
daemon and the owcli, bossman, and goatlassian web UIs. All state lives in a
`/kgbo` volume, the [Data Bundle](../concepts/data-bundle.md) in variables
mode. It is the unit the hosted setup runs on a VM; agents keep the tools
installed on their own machines. `docs/container.md` is the operator guide.

## Building

`make image` runs `$(CONTAINER) build -f deploy/container/Dockerfile` from
the repository root (`CONTAINER` defaults to `docker`; podman works too) and
tags the image `kgbo-stack:<git describe>`. `make push PROJECT=<id>` pushes
it to that project's Artifact Registry for the
[GCP Deployment](gcp.md).
`.dockerignore` limits the build context to `stack.toml`, `bin/kgbo`, and
`deploy/container/`. Base images are fully qualified
(`docker.io/library/...`) because podman refuses short names without a
search registry.

The build has two stages:

1. A Go stage `go install`s owcli, bossman, and goatlassian at pinned tags
   (`OWCLI_VERSION`, `BOSSMAN_VERSION`, `GOATLASSIAN_VERSION`) and downloads
   kata's release tarball for `TARGETARCH`, checked against a SHA-256 kept in
   the Dockerfile because kata publishes no checksum file.
2. A `debian:bookworm-slim` stage with bash, curl, git, python3 (for
   `bin/kgbo`), and tini, a `kgbo` user with uid 1000, the binaries,
   `bin/kgbo` with `stack.toml` under `/opt/kgbo-stack`, and the supervisor.

## Bundle variables as ENV

`KGBO_HOME=/kgbo` and each provider's home variable (`KATA_HOME=/kgbo/kata`
and so on) are image `ENV`, so every process sees them: the services, the
health check, and anything run with `docker exec`. Loading them only in the
entrypoint was tried first and failed: an exec'd `kata list` used the
default `~/.kata` and started a second, empty daemon, and bossman created an
empty home. A build step runs `kgbo env --plain --root /kgbo` and fails if
any `ENV` value differs, so `stack.toml` stays the source of truth.

## kgbo-services

`kgbo-services` is the entrypoint, run under `tini`:

- `run` (the default) creates the bundle directories and starts `kata
  daemon start --foreground` (with `--listen $KATA_LISTEN` when set, for
  spokes), `bossman serve --no-sync` (the container has no agent logs),
  `owcli serve`, and `goatlassian serve`. It waits for the first to exit,
  stops the rest, and exits with that status, so the restart policy brings
  the set back together. SIGTERM stops all of them; a stop takes under a
  second.
- `check` is the image's `HEALTHCHECK`: `kata health` plus an HTTP request to
  each web UI's API, always on `127.0.0.1` at the UI's port (loopback names
  are accepted whatever address the UI listens on), sending the user header
  itself when one is configured. Probing the listen address failed in
  testing: `0.0.0.0:<port>` is not a name the UIs accept.

The web UIs listen on loopback (bossman 7788, owcli 4321, goatlassian 7799,
adjustable with `BOSSMAN_ADDR`, `OWCLI_ADDR`, `GOATLASSIAN_ADDR`).

## Kata start order

`kgbo-services` starts kata's daemon first and starts nothing else until
`kata health` answers (it gives up after a minute), and the image sets
`KATA_AUTOSTART=0`. Without that, the first `kata` call from another process
(goatlassian adopting a clone, for instance) found no daemon yet, started
one of its own, and the supervisor's `kata daemon start --foreground` then
exited with "already listening", restarting the container on the VM. With
autostart off, a kata command that finds no daemon fails instead.

## Server-side clones

`kgbo-repos` keeps clones of the repositories listed in
`/kgbo/server/repos.tsv` (`<name> <git url>` per line) in
`/kgbo/repos/<name>`: it clones a missing one, fast-forwards an existing
one, binds each in owcli, and runs `goatlassian adopt <dir> --slug <name>`,
which creates the project the first time and adds to it afterwards. Only
listed clones are adopted, never other directories goatlassian knows from
shipped sessions. It then creates or extends the owcli workspaces listed in
`/kgbo/server/workspaces.tsv` (`<workspace> <name>...`). It reads both files
on file descriptor 3, so commands inside the loops cannot swallow their
lines. Every step is idempotent.

When `repos.tsv` exists, `kgbo-services` runs it at start and every
`KGBO_REPOS_EVERY` (default 15m, `0` disables) in a background loop; a failed
sync is logged and retried and never stops the services. Locally, three
fresh starts that each cloned repositories ran without a restart.

## Proxy mode

Behind a load balancer with Google IAP, `kgbo-services` turns environment
variables into each UI's reverse-proxy flags (`proxy_flags`):
`BOSSMAN_HOST`, `OWCLI_HOST`, and `GOATLASSIAN_HOST` become `--allow-host`,
and `KGBO_USER_HEADER` (such as `X-Goog-Authenticated-User-Email`) becomes
`--user-header` for all three. The UIs then answer 401 to requests without
the header, so load balancer health checks should be TCP checks on the
ports. Tested with the ports published and requests sent as a load balancer
would: signed in 200, no header 401, unknown host 403, and goatlassian
reporting the signed-in user as the actor. Trusting the header assumes a
firewall that admits only the load balancer.

## Stored paths

A bundle seeded from a workstation (`bin/kgbo snapshot`) keeps that
machine's absolute repository paths. Either mount the repositories at the
same paths, read-only, or clone them anywhere and run `kgbo remap` in the
container (see [Moving Repositories or Machines](../workflows/moving-repositories.md)).
`remap` needs owcli v0.3.0 and goatlassian v0.2.0 or later (their
`relocate` commands); the image pins owcli v0.4.0, bossman v0.2.0, and
goatlassian v0.3.0.

## Verified behaviour

Run against a snapshot of a workstation bundle with its repositories mounted
read-only, the container's tools reported the same issues, wikis, and
sessions as the host, `kgbo homes` placed every provider in `/kgbo`, and
goatlassian showed the same portfolio. Killing one service stopped the
container with a non-zero exit. With the repositories mounted at `/repos`
instead, `kgbo remap /home/<user>/<dir> /repos` inside the container took
goatlassian from six projects with problems to none and owcli from no
readable wikis to all seven, with workspace search working.
