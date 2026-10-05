---
type: Workflow
title: Moving Repositories or Machines
description: Which absolute paths each tool stores, how bin/kgbo remap rewrites them after repositories move or the stack lands on a new machine, and why goatlassian must relocate before owcli.
tags: [workflow, relocate, remap, paths, migration]
verified:
  - by: owcli/v0.2.0-1-g3d84f34
    at: "2026-10-05T08:37:52.146Z"
sources:
  - id: openwiki-source-4295305d9bd805a055f92696
    resource: repo://bin/kgbo
  - id: openwiki-source-e1ed762e7e9cce9b41dec3b6
    resource: repo://docs/moving.md
  - id: openwiki-source-1a91849fbfee35c0f5eed2a6
    resource: repo://stack.toml
generated: { by: "owcli/v0.2.0-1-g3d84f34", at: "2026-10-05T08:38:10.671Z" }
---

# Moving Repositories or Machines

Several tools key their state on absolute repository paths, so moving
repositories (or restoring the bundle on a machine with a different home
directory) leaves that state pointing at paths that no longer exist.
`bin/kgbo remap OLD NEW [--dry-run]` rewrites every stored path at or under
`OLD` to the same path under `NEW`. `docs/moving.md` is the operator guide.

## What each tool stores

| tool | stored paths | how remap handles them |
| --- | --- | --- |
| goatlassian | `git` refs, `sessions` directories, `owcli-wiki` `attrs.root` | `goatlassian relocate`: rewrites git refs and wiki roots; keeps each sessions directory and attaches the new one next to it |
| owcli | `bindings.json` keys and custom wiki directories, `workspaces.json` roots | `owcli relocate`: rewrites them, keeping wiki and workspace IDs |
| kata | one `local://<path>` alias per bound project | `kata init --workspace NEW` adds the new alias, then `kata projects detach` removes the old one |
| bossman | each session's working directory | nothing: it records where the session ran |

Sessions keep their old directory in goatlassian for the same reason
bossman keeps it: a session that ran in `/old/shop` still ran there, and the
project should go on counting it.

## How remap runs

`stack.toml` declares each provider's `relocate` command, with `{old}` and
`{new}` placeholders, and `[bundle]` `relocate_order` lists the order.
`remap` runs each command in that order (skipping a tool that is missing or
has no `relocate` subcommand), inserting `--dry-run` when asked. It then
moves kata aliases, re-points any bundle symlink whose target moved (a home
directory move), and reports that bossman needs nothing.

For kata, `remap` reads every project's aliases and handles the `local://`
ones under `OLD`. It only rebinds when the new path has a `.kata.toml`, so
an alias whose repository has not been cloned yet is kept and reported;
running `remap` again after cloning picks it up. `kata init` at an existing
binding changes no files in the repository.

## Why goatlassian runs before owcli

goatlassian resolves an `owcli-wiki` component by its owcli wiki ID, then by
the repository root stored in `attrs.root`. Components attached before that
root was recorded have none, so `goatlassian relocate` looks their roots up
by their current owcli ID. A wiki outside any workspace is identified by a
hash of its repository path, which `owcli relocate` changes; after that the
old ID no longer resolves. Hence `relocate_order = ["goatlassian", "owcli"]`.

## Procedures

- **Repositories moved on this machine:** move them, run
  `bin/kgbo remap --dry-run OLD NEW` to review, then without `--dry-run`.
  Running it twice is harmless.
- **New machine:** snapshot the bundle on the old machine
  (`bin/kgbo snapshot`), install the tools on the new one, copy the snapshot
  to `~/kgbo`, run `bin/kgbo adopt` (it only creates symlinks there), clone
  the repositories, then `bin/kgbo remap /old/home /new/home`. Paths not yet
  cloned are reported as missing; run `remap` again once they are.

Agent logs stay as they are: Claude Code and Codex keep sessions under the
path they ran in, and bossman's archive keeps its copy unchanged.
