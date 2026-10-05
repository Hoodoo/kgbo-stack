---
type: Guide
title: Container Image
description: How the stack's services run in one container image, what it contains and pins, how kgbo-services supervises and health-checks them, why the bundle variables are image ENV, and how stored paths are handled inside the container.
tags: [container, docker, deployment, bundle, operations]
verified:
  - by: owcli/v0.2.0-1-g3d84f34
    at: "2026-10-05T08:57:43.775Z"
sources:
  - id: openwiki-source-715dace563ef484b6e8bd1e2
    resource: repo://.dockerignore
  - id: openwiki-source-cea96ae8f357252ff94e036c
    resource: repo://deploy/container/Dockerfile
  - id: openwiki-source-aba0804f4b63f288f9daec3a
    resource: repo://deploy/container/kgbo-services
  - id: openwiki-source-012f2c78e3b1446dfc35803f
    resource: repo://Makefile
generated: { by: "owcli/v0.2.0-1-g3d84f34", at: "2026-10-05T08:58:07.074Z" }
---

# Container Image

`deploy/container/` builds one image that runs the stack's services: kata's
daemon and the owcli, bossman, and goatlassian web UIs. All state lives in a
`/kgbo` volume, the [Data Bundle](../concepts/data-bundle.md) in variables
mode. It is the unit the hosted setup runs on a VM; agents keep the tools
installed on their own machines. `docs/container.md` is the operator guide.

## Building

`make image` runs `$(CONTAINER) build -f deploy/container/Dockerfile` from
the repository root (`CONTAINER` defaults to `docker`; podman works too).
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
  each web UI's API.

The web UIs listen on loopback (bossman 7788, owcli 4321, goatlassian 7799,
adjustable with `BOSSMAN_ADDR`, `OWCLI_PORT`, `GOATLASSIAN_ADDR`). Their Host
guards reject other host names with 403; serving them through a load
balancer is the reverse-proxy work tracked per tool.

## Stored paths

A bundle seeded from a workstation (`bin/kgbo snapshot`) keeps that
machine's absolute repository paths. Either mount the repositories at the
same paths, read-only, or clone them anywhere and run `kgbo remap` in the
container (see [Moving Repositories or Machines](../workflows/moving-repositories.md)).
`remap` needs owcli and goatlassian releases that have `relocate`; with the
pinned v0.2.0 and v0.1.1 it skips both tools.

## Verified behaviour

Run against a snapshot of a workstation bundle with its repositories mounted
read-only, the container's tools reported the same issues, wikis, and
sessions as the host, `kgbo homes` placed every provider in `/kgbo`, and
goatlassian showed the same portfolio. Killing one service stopped the
container with a non-zero exit.
