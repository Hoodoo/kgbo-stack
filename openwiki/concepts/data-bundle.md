---
type: Concept
title: Data Bundle
description: How the stack's machine-local state is gathered into one directory, the two ways tools are pointed at it and why they must not be mixed, and how bin/kgbo snapshots state consistently.
tags: [bundle, backup, state, kgbo, sqlite]
verified:
  - by: owcli/v0.2.0-1-g3d84f34
    at: "2026-10-05T08:57:12.701Z"
sources:
  - id: openwiki-source-4295305d9bd805a055f92696
    resource: repo://bin/kgbo
  - id: openwiki-source-cea96ae8f357252ff94e036c
    resource: repo://deploy/container/Dockerfile
  - id: openwiki-source-6215ef1e20210625bdbea089
    resource: repo://docs/data-bundle.md
  - id: openwiki-source-1a91849fbfee35c0f5eed2a6
    resource: repo://stack.toml
generated: { by: "owcli/v0.2.0-1-g3d84f34", at: "2026-10-05T08:58:07.074Z" }
---

# Data Bundle

Every provider that keeps state outside repositories (kata, owcli, bossman,
goatlassian) can keep it in one directory, `~/kgbo` by default. The bundle
makes the stack's data one thing to back up, inspect, or mount into a
container. `docs/data-bundle.md` is the operator guide; `bin/kgbo` is the
tool; `stack.toml` declares the layout.

## Layout

`[bundle]` in `stack.toml` gives the root (`~/kgbo`, overridden by
`KGBO_HOME`) and file patterns no snapshot copies (`*-wal`, `*-shm`,
`*-journal`, `*.lock`, `*.sock`). Each bundled provider declares:

| key | kata | owcli | bossman | goatlassian |
| --- | --- | --- | --- | --- |
| `home_env` | `KATA_HOME` | `OWCLI_HOME` | `BOSSMAN_HOME` | `GOATLASSIAN_HOME` |
| `home_default` | `~/.kata` | `~/.config/owcli` and `~/.local/share/owcli` | `~/.local/share/bossman` | `~/.local/share/goatlassian` |
| `bundle_dir` | `kata` | `owcli` | `bossman` | `goatlassian` |
| `snapshot_skip` | `runtime` (daemon pid files) | | | `logs` |

owcli has two default directories (XDG config and data); in the bundle they
merge into one, which owcli supports from v0.2.0 through `OWCLI_HOME`.

Outside the bundle by design: the repositories (in-repo wikis,
`.kata.toml`, `.beads/`), the agents' own logs in `~/.claude` and
`~/.codex` (bossman's archive copy of them is inside), and services such as
the Ollama endpoint kata search uses for embeddings.

## bin/kgbo

A Python 3.11+ standard-library script that locates `stack.toml` relative to
itself and treats every provider with a `home_env` as bundled.

- `kgbo homes` shows where each provider's state is now and marks
  directories that resolve into the bundle.
- `kgbo env [--root DIR] [--plain]` prints the home variables for the bundle,
  as shell `export`s or, with `--plain`, `KEY=VALUE` lines for
  `environment.d` and crontab.
- `kgbo snapshot DEST [--provider P]` copies each provider's current state
  into `DEST/<bundle_dir>`.
- `kgbo adopt [--dry-run]` moves state into the bundle and symlinks the
  default locations to it.

Paths are resolved the way the tools resolve them: the home variable if set,
else the defaults, with `~/.config` and `~/.local/share` replaced by
`XDG_CONFIG_HOME` and `XDG_DATA_HOME` when those are set.

## Symlinks or variables, never both

A machine reaches the bundle either through symlinks at the default
locations (`kgbo adopt`) or through the home variables (`kgbo env`). Mixing
them breaks kata: it names its daemon socket after the literal `KATA_HOME`
path without resolving symlinks, so a process using the symlinked default
and one using the real path start two daemons on one database. With
variables, every process that runs a tool must see them (shell profile,
`environment.d` for GUI-launched agent apps, crontab), or it silently falls
back to the defaults.

Symlinks are the workstation default: nothing needs configuring per process,
and kata keeps the same socket and hook history because its path string does
not change. Variables suit containers and non-default locations: the
stack's container image sets them with `ENV` so that every process, including
`docker exec`, sees them (see [Container Image](../operations/container.md)).

## How adopt works

`adopt` refuses while any provider's home variable is set, and refuses
while any process has a file open under the directories it would move (it
scans `/proc/*/fd`, or uses `lsof` where there is no `/proc`). For each
default directory that is not yet a symlink it snapshots the contents into
the bundle, renames the original to `<name>.pre-kgbo` as a rollback copy,
and creates the symlink; a missing default (such as owcli's data directory)
just gets the symlink. Running it again reports that everything already
points into the bundle.

## Consistent snapshots

The tools use SQLite in WAL mode, often with a daemon holding the database
open, so a plain file copy can miss committed changes still in the `-wal`
file or catch a page mid-write. `snapshot` therefore recognizes databases by
their `SQLite format 3` header and copies them through SQLite's online
backup API from a read-only connection, then runs `PRAGMA integrity_check`
on the copy; other files are copied as they are. It refuses a destination
that already holds provider data, and refuses to snapshot into a provider's
live directory. Restoring is copying a snapshot's directories back with the
tools stopped.
